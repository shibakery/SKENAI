import { EventEmitter } from 'events';
import { Strategy, PoolData, MarketMetrics } from '../../types';
import { CONFIG } from '../../config';
import { MarketDataCollector } from '../../data_analysis/market_data_collector';

interface BacktestResult {
    returns: number[];
    trades: number;
    winRate: number;
    sharpeRatio: number;
    maxDrawdown: number;
    volatility: number;
    profitFactor: number;
}

interface TradeResult {
    timestamp: number;
    entryPrice: number;
    exitPrice: number;
    profit: number;
    holdingPeriod: number;
}

export class Backtester extends EventEmitter {
    private dataCollector: MarketDataCollector;
    private historicalData: Map<string, MarketMetrics[]>;

    constructor(dataCollector: MarketDataCollector) {
        super();
        this.dataCollector = dataCollector;
        this.historicalData = new Map();
    }

    async backtest(strategy: Strategy, poolAddress: string): Promise<BacktestResult> {
        await this.loadHistoricalData(poolAddress);
        const trades = await this.simulateStrategy(strategy, poolAddress);
        return this.calculateMetrics(trades);
    }

    private async loadHistoricalData(poolAddress: string): Promise<void> {
        if (!this.historicalData.has(poolAddress)) {
            const endTime = Math.floor(Date.now() / 1000);
            const startTime = endTime - (CONFIG.analysis.backtestPeriod * 24 * 60 * 60);
            
            const data = await this.dataCollector.fetchHistoricalData(poolAddress, startTime, endTime);
            this.historicalData.set(poolAddress, data);
        }
    }

    private async simulateStrategy(strategy: Strategy, poolAddress: string): Promise<TradeResult[]> {
        const data = this.historicalData.get(poolAddress)!;
        const trades: TradeResult[] = [];
        let inPosition = false;
        let entryPrice = 0;
        let entryTime = 0;

        for (let i = 1; i < data.length; i++) {
            const signal = this.generateSignal(strategy, data.slice(0, i + 1));
            
            if (!inPosition && signal === 'buy') {
                inPosition = true;
                entryPrice = data[i].price;
                entryTime = data[i].timestamp;
            }
            else if (inPosition && (signal === 'sell' || this.checkStopLoss(strategy, entryPrice, data[i].price))) {
                trades.push({
                    timestamp: data[i].timestamp,
                    entryPrice,
                    exitPrice: data[i].price,
                    profit: (data[i].price - entryPrice) / entryPrice,
                    holdingPeriod: data[i].timestamp - entryTime
                });
                inPosition = false;
            }
        }

        return trades;
    }

    private generateSignal(strategy: Strategy, data: MarketMetrics[]): 'buy' | 'sell' | 'hold' {
        // Implement strategy-specific signal generation
        const current = data[data.length - 1];
        const previous = data[data.length - 2];

        // Example simple strategy logic
        if (strategy.parameters.indicator === 'momentum') {
            const momentum = (current.price - previous.price) / previous.price;
            if (momentum > strategy.parameters.buyThreshold) return 'buy';
            if (momentum < strategy.parameters.sellThreshold) return 'sell';
        }

        return 'hold';
    }

    private checkStopLoss(strategy: Strategy, entryPrice: number, currentPrice: number): boolean {
        const drawdown = (entryPrice - currentPrice) / entryPrice;
        return drawdown > strategy.maxDrawdown;
    }

    private calculateMetrics(trades: TradeResult[]): BacktestResult {
        const returns = trades.map(t => t.profit);
        const winningTrades = trades.filter(t => t.profit > 0);
        
        const totalProfit = returns.reduce((sum, r) => sum + r, 0);
        const totalLoss = returns.filter(r => r < 0).reduce((sum, r) => sum + Math.abs(r), 0);
        
        const volatility = this.calculateVolatility(returns);
        const sharpeRatio = this.calculateSharpeRatio(returns, volatility);
        const maxDrawdown = this.calculateMaxDrawdown(returns);

        return {
            returns,
            trades: trades.length,
            winRate: winningTrades.length / trades.length,
            sharpeRatio,
            maxDrawdown,
            volatility,
            profitFactor: totalLoss === 0 ? Infinity : totalProfit / totalLoss
        };
    }

    private calculateVolatility(returns: number[]): number {
        const mean = returns.reduce((sum, r) => sum + r, 0) / returns.length;
        const squaredDiffs = returns.map(r => Math.pow(r - mean, 2));
        return Math.sqrt(squaredDiffs.reduce((sum, sq) => sum + sq, 0) / returns.length);
    }

    private calculateSharpeRatio(returns: number[], volatility: number): number {
        const riskFreeRate = 0.02; // Assuming 2% annual risk-free rate
        const meanReturn = returns.reduce((sum, r) => sum + r, 0) / returns.length;
        return (meanReturn - riskFreeRate) / volatility;
    }

    private calculateMaxDrawdown(returns: number[]): number {
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
}
