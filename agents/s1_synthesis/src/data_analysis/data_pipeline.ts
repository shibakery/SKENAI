import { EventEmitter } from 'events';
import { MarketMetrics, PoolData } from '../types';
import { CONFIG } from '../config';
import { MarketDataCollector } from './market_data_collector';

interface DataPoint {
    timestamp: number;
    metrics: MarketMetrics;
    poolData: PoolData;
}

export class DataPipeline extends EventEmitter {
    private dataCollector: MarketDataCollector;
    private dataBuffer: Map<string, DataPoint[]>;
    private updateIntervals: Map<string, NodeJS.Timer>;

    constructor(dataCollector: MarketDataCollector) {
        super();
        this.dataCollector = dataCollector;
        this.dataBuffer = new Map();
        this.updateIntervals = new Map();

        // Listen for data collection events
        this.dataCollector.on('data_collected', this.processNewData.bind(this));
        this.dataCollector.on('error', this.handleError.bind(this));
    }

    async startMonitoring(poolAddress: string): Promise<void> {
        if (this.updateIntervals.has(poolAddress)) {
            return; // Already monitoring this pool
        }

        try {
            // Initialize buffer with historical data
            await this.initializeBuffer(poolAddress);

            // Set up real-time monitoring
            const interval = setInterval(
                () => this.updatePoolData(poolAddress),
                CONFIG.strategy.updateInterval
            );

            this.updateIntervals.set(poolAddress, interval);
            this.emit('monitoring_started', poolAddress);
        } catch (error) {
            this.handleError(error);
        }
    }

    stopMonitoring(poolAddress: string): void {
        const interval = this.updateIntervals.get(poolAddress);
        if (interval) {
            clearInterval(interval);
            this.updateIntervals.delete(poolAddress);
            this.emit('monitoring_stopped', poolAddress);
        }
    }

    getLatestData(poolAddress: string): DataPoint | undefined {
        const buffer = this.dataBuffer.get(poolAddress);
        return buffer?.[buffer.length - 1];
    }

    getHistoricalData(poolAddress: string, timeframe: number): DataPoint[] {
        const buffer = this.dataBuffer.get(poolAddress);
        if (!buffer) return [];

        const cutoffTime = Date.now() - timeframe;
        return buffer.filter(point => point.timestamp >= cutoffTime);
    }

    private async initializeBuffer(poolAddress: string): Promise<void> {
        const endTime = Math.floor(Date.now() / 1000);
        const startTime = endTime - (CONFIG.storage.retentionPeriod * 24 * 60 * 60);

        const historicalData = await this.dataCollector.fetchHistoricalData(poolAddress, startTime, endTime);
        const poolData = await this.dataCollector.fetchLiquidityPoolData(poolAddress);

        const dataPoints: DataPoint[] = historicalData.map(metrics => ({
            timestamp: metrics.timestamp,
            metrics,
            poolData
        }));

        this.dataBuffer.set(poolAddress, dataPoints);
    }

    private async updatePoolData(poolAddress: string): Promise<void> {
        try {
            const [metrics, poolData] = await Promise.all([
                this.dataCollector.getMarketMetrics(),
                this.dataCollector.fetchLiquidityPoolData(poolAddress)
            ]);

            const newDataPoint: DataPoint = {
                timestamp: Math.floor(Date.now() / 1000),
                metrics,
                poolData
            };

            this.processNewData(poolAddress, newDataPoint);
        } catch (error) {
            this.handleError(error);
        }
    }

    private processNewData(poolAddress: string, dataPoint: DataPoint): void {
        let buffer = this.dataBuffer.get(poolAddress);
        if (!buffer) {
            buffer = [];
            this.dataBuffer.set(poolAddress, buffer);
        }

        // Add new data point
        buffer.push(dataPoint);

        // Trim old data
        const cutoffTime = Date.now() - (CONFIG.storage.retentionPeriod * 24 * 60 * 60 * 1000);
        while (buffer.length > 0 && buffer[0].timestamp < cutoffTime) {
            buffer.shift();
        }

        // Emit update event
        this.emit('data_updated', poolAddress, dataPoint);

        // Check for anomalies
        this.detectAnomalies(poolAddress, dataPoint);
    }

    private detectAnomalies(poolAddress: string, dataPoint: DataPoint): void {
        const buffer = this.dataBuffer.get(poolAddress)!;
        if (buffer.length < 2) return;

        const previous = buffer[buffer.length - 2];
        
        // Check for significant price changes
        const priceChange = Math.abs(dataPoint.metrics.price - previous.metrics.price) / previous.metrics.price;
        if (priceChange > 0.1) { // 10% price change
            this.emit('anomaly_detected', {
                type: 'price_change',
                poolAddress,
                severity: priceChange > 0.2 ? 'high' : 'medium',
                details: { priceChange, timestamp: dataPoint.timestamp }
            });
        }

        // Check for liquidity changes
        const liquidityChange = Math.abs(
            parseFloat(dataPoint.poolData.totalSupply) - parseFloat(previous.poolData.totalSupply)
        ) / parseFloat(previous.poolData.totalSupply);

        if (liquidityChange > 0.15) { // 15% liquidity change
            this.emit('anomaly_detected', {
                type: 'liquidity_change',
                poolAddress,
                severity: liquidityChange > 0.25 ? 'high' : 'medium',
                details: { liquidityChange, timestamp: dataPoint.timestamp }
            });
        }
    }

    private handleError(error: any): void {
        this.emit('error', error);
        console.error('Data pipeline error:', error);
    }
}
