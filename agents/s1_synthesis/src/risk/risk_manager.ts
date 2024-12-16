import { EventEmitter } from 'events';
import { Strategy, MarketMetrics, PoolData } from '../types';
import { CONFIG } from '../config';
import { DataPipeline } from '../data_analysis/data_pipeline';

interface RiskAlert {
    type: 'market' | 'strategy' | 'liquidity' | 'volatility';
    severity: 'low' | 'medium' | 'high';
    message: string;
    timestamp: number;
    details: any;
}

interface RiskThresholds {
    maxVolatility: number;
    maxDrawdown: number;
    minLiquidity: number;
    maxExposure: number;
}

export class RiskManager extends EventEmitter {
    private dataPipeline: DataPipeline;
    private activeStrategies: Map<string, Strategy>;
    private riskThresholds: Map<string, RiskThresholds>;
    private alerts: RiskAlert[];

    constructor(dataPipeline: DataPipeline) {
        super();
        this.dataPipeline = dataPipeline;
        this.activeStrategies = new Map();
        this.riskThresholds = new Map();
        this.alerts = [];

        // Set up event listeners
        this.dataPipeline.on('data_updated', this.assessRisk.bind(this));
        this.dataPipeline.on('anomaly_detected', this.handleAnomaly.bind(this));
    }

    registerStrategy(poolAddress: string, strategy: Strategy): void {
        this.activeStrategies.set(poolAddress, strategy);
        this.riskThresholds.set(poolAddress, this.calculateRiskThresholds(strategy));
    }

    getActiveRiskAlerts(): RiskAlert[] {
        const cutoffTime = Date.now() - (24 * 60 * 60 * 1000); // Last 24 hours
        return this.alerts.filter(alert => alert.timestamp > cutoffTime);
    }

    private calculateRiskThresholds(strategy: Strategy): RiskThresholds {
        const baseThresholds = {
            low: {
                maxVolatility: 0.1,
                maxDrawdown: 0.05,
                minLiquidity: 500000,
                maxExposure: 0.1
            },
            medium: {
                maxVolatility: 0.2,
                maxDrawdown: 0.1,
                minLiquidity: 250000,
                maxExposure: 0.2
            },
            high: {
                maxVolatility: 0.3,
                maxDrawdown: 0.15,
                minLiquidity: 100000,
                maxExposure: 0.3
            }
        };

        return baseThresholds[strategy.riskLevel];
    }

    private async assessRisk(poolAddress: string): Promise<void> {
        const strategy = this.activeStrategies.get(poolAddress);
        if (!strategy) return;

        const thresholds = this.riskThresholds.get(poolAddress)!;
        const latestData = this.dataPipeline.getLatestData(poolAddress);
        if (!latestData) return;

        // Check market conditions
        await this.checkMarketRisk(poolAddress, latestData.metrics, thresholds);

        // Check strategy performance
        await this.checkStrategyRisk(poolAddress, strategy, latestData);

        // Check liquidity conditions
        await this.checkLiquidityRisk(poolAddress, latestData.poolData, thresholds);
    }

    private async checkMarketRisk(
        poolAddress: string,
        metrics: MarketMetrics,
        thresholds: RiskThresholds
    ): Promise<void> {
        if (metrics.volatility > thresholds.maxVolatility) {
            this.createAlert({
                type: 'market',
                severity: this.calculateSeverity(metrics.volatility, thresholds.maxVolatility),
                message: `High market volatility detected for pool ${poolAddress}`,
                timestamp: Date.now(),
                details: { volatility: metrics.volatility, threshold: thresholds.maxVolatility }
            });
        }
    }

    private async checkStrategyRisk(
        poolAddress: string,
        strategy: Strategy,
        latestData: { metrics: MarketMetrics, poolData: PoolData }
    ): Promise<void> {
        const historicalData = this.dataPipeline.getHistoricalData(poolAddress, 24 * 60 * 60 * 1000);
        const returns = this.calculateReturns(historicalData);
        const drawdown = this.calculateDrawdown(returns);

        const thresholds = this.riskThresholds.get(poolAddress)!;
        if (drawdown > thresholds.maxDrawdown) {
            this.createAlert({
                type: 'strategy',
                severity: this.calculateSeverity(drawdown, thresholds.maxDrawdown),
                message: `Strategy drawdown exceeded threshold for pool ${poolAddress}`,
                timestamp: Date.now(),
                details: { drawdown, threshold: thresholds.maxDrawdown, strategy: strategy.name }
            });
        }
    }

    private async checkLiquidityRisk(
        poolAddress: string,
        poolData: PoolData,
        thresholds: RiskThresholds
    ): Promise<void> {
        const liquidity = parseFloat(poolData.totalSupply);
        if (liquidity < thresholds.minLiquidity) {
            this.createAlert({
                type: 'liquidity',
                severity: this.calculateSeverity(thresholds.minLiquidity - liquidity, thresholds.minLiquidity),
                message: `Low liquidity detected for pool ${poolAddress}`,
                timestamp: Date.now(),
                details: { liquidity, threshold: thresholds.minLiquidity }
            });
        }
    }

    private handleAnomaly(anomaly: any): void {
        this.createAlert({
            type: anomaly.type === 'price_change' ? 'market' : 'liquidity',
            severity: anomaly.severity,
            message: `Anomaly detected: ${anomaly.type} in pool ${anomaly.poolAddress}`,
            timestamp: Date.now(),
            details: anomaly.details
        });
    }

    private calculateReturns(historicalData: any[]): number[] {
        const returns: number[] = [];
        for (let i = 1; i < historicalData.length; i++) {
            const return_ = (historicalData[i].metrics.price - historicalData[i-1].metrics.price) 
                          / historicalData[i-1].metrics.price;
            returns.push(return_);
        }
        return returns;
    }

    private calculateDrawdown(returns: number[]): number {
        let peak = -Infinity;
        let maxDrawdown = 0;
        let cumReturn = 1;

        for (const ret of returns) {
            cumReturn *= (1 + ret);
            if (cumReturn > peak) peak = cumReturn;
            const drawdown = (peak - cumReturn) / peak;
            if (drawdown > maxDrawdown) maxDrawdown = drawdown;
        }

        return maxDrawdown;
    }

    private calculateSeverity(value: number, threshold: number): 'low' | 'medium' | 'high' {
        const ratio = value / threshold;
        if (ratio > 1.5) return 'high';
        if (ratio > 1.2) return 'medium';
        return 'low';
    }

    private createAlert(alert: RiskAlert): void {
        this.alerts.push(alert);
        this.emit('risk_alert', alert);

        // Trim old alerts
        const cutoffTime = Date.now() - (7 * 24 * 60 * 60 * 1000); // Keep 7 days of alerts
        this.alerts = this.alerts.filter(a => a.timestamp > cutoffTime);
    }
}
