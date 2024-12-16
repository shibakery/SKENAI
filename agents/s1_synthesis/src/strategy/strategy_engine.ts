import { EventEmitter } from 'events';
import { Strategy, StrategyMetrics, PoolData, MarketMetrics } from '../types';
import { CONFIG } from '../config';
import { MarketDataCollector } from '../data_analysis/market_data_collector';

export class StrategyEngine extends EventEmitter {
    private dataCollector: MarketDataCollector;
    private activeStrategies: Map<string, Strategy>;

    constructor(dataCollector: MarketDataCollector) {
        super();
        this.dataCollector = dataCollector;
        this.activeStrategies = new Map();
    }

    async evaluateStrategy(strategy: Strategy, poolAddress: string): Promise<StrategyMetrics> {
        const poolData = await this.dataCollector.fetchLiquidityPoolData(poolAddress);
        const marketMetrics = await this.dataCollector.getMarketMetrics();
        
        // Validate pool meets minimum requirements
        if (!this.validatePoolRequirements(poolData, marketMetrics)) {
            throw new Error('Pool does not meet minimum requirements');
        }

        const metrics = await this.calculateStrategyMetrics(strategy, poolData, marketMetrics);
        this.emit('strategy_evaluated', { strategy, metrics, poolAddress });
        
        return metrics;
    }

    private validatePoolRequirements(poolData: PoolData, marketMetrics: MarketMetrics): boolean {
        const liquidityUSD = parseFloat(poolData.reserve0) * marketMetrics.price;
        return liquidityUSD >= parseFloat(CONFIG.analysis.minLiquidityThreshold) &&
               marketMetrics.volume24h >= parseFloat(CONFIG.analysis.minVolumeThreshold);
    }

    private async calculateStrategyMetrics(
        strategy: Strategy,
        poolData: PoolData,
        marketMetrics: MarketMetrics
    ): Promise<StrategyMetrics> {
        const expectedReturn = this.calculateExpectedReturn(strategy, poolData, marketMetrics);
        const riskMetrics = this.calculateRiskMetrics(strategy, marketMetrics);
        const liquidityScore = this.calculateLiquidityScore(poolData, marketMetrics);
        
        return {
            expectedReturn,
            riskMetrics,
            liquidityScore,
            recommendation: this.generateRecommendation(expectedReturn, riskMetrics, liquidityScore)
        };
    }

    private calculateExpectedReturn(
        strategy: Strategy,
        poolData: PoolData,
        marketMetrics: MarketMetrics
    ): number {
        // Implement sophisticated return calculation based on:
        // - Historical performance
        // - Market conditions
        // - Strategy parameters
        // - Pool characteristics
        return strategy.targetReturn * (1 - marketMetrics.volatility);
    }

    private calculateRiskMetrics(strategy: Strategy, marketMetrics: MarketMetrics) {
        return {
            volatilityScore: marketMetrics.volatility,
            impermanentLossRisk: this.calculateImpermanentLossRisk(marketMetrics),
            marketRisk: this.calculateMarketRisk(strategy, marketMetrics)
        };
    }

    private calculateImpermanentLossRisk(marketMetrics: MarketMetrics): number {
        return marketMetrics.volatility * 2; // Simplified IL calculation
    }

    private calculateMarketRisk(strategy: Strategy, marketMetrics: MarketMetrics): number {
        const baseRisk = strategy.riskLevel === 'high' ? 0.8 :
                        strategy.riskLevel === 'medium' ? 0.5 : 0.2;
        return baseRisk * marketMetrics.volatility;
    }

    private calculateLiquidityScore(poolData: PoolData, marketMetrics: MarketMetrics): number {
        const liquidityUSD = parseFloat(poolData.reserve0) * marketMetrics.price;
        const minLiquidity = parseFloat(CONFIG.analysis.minLiquidityThreshold);
        return Math.min(1, liquidityUSD / (minLiquidity * 10));
    }

    private generateRecommendation(
        expectedReturn: number,
        riskMetrics: StrategyMetrics['riskMetrics'],
        liquidityScore: number
    ): string {
        const { metrics } = CONFIG.strategy;
        const score = (expectedReturn * metrics.expectedReturnWeight) -
                     ((riskMetrics.volatilityScore + riskMetrics.impermanentLossRisk + riskMetrics.marketRisk) / 3 * metrics.riskWeight) +
                     (liquidityScore * metrics.liquidityWeight);

        if (score >= 0.7) return 'Highly Recommended';
        if (score >= 0.5) return 'Recommended';
        if (score >= 0.3) return 'Neutral';
        return 'Not Recommended';
    }
}
