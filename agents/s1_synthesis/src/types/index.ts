export interface MarketMetrics {
    price: number;
    volume24h: number;
    liquidity: number;
    volatility: number;
    timestamp: number;
}

export interface PoolData {
    address: string;
    token0: string;
    token1: string;
    reserve0: string;
    reserve1: string;
    fee: number;
    totalSupply: string;
}

export interface VolumeData {
    timeframe: string;
    volume: number;
    trades: number;
    averageTradeSize: number;
}

export interface StrategyMetrics {
    expectedReturn: number;
    riskMetrics: {
        volatilityScore: number;
        impermanentLossRisk: number;
        marketRisk: number;
    };
    liquidityScore: number;
    recommendation: string;
}

export type RiskLevel = 'low' | 'medium' | 'high';

export interface Strategy {
    name: string;
    parameters: Record<string, any>;
    riskLevel: RiskLevel;
    targetReturn: number;
    maxDrawdown: number;
}
