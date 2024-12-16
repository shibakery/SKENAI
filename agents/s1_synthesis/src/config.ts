export const CONFIG = {
    api: {
        everstrike: {
            baseUrl: 'https://api.everstrike.io/v1',
            timeout: 30000, // 30 seconds
            retryAttempts: 3,
        }
    },
    analysis: {
        timeframes: ['1h', '4h', '24h', '7d'],
        minLiquidityThreshold: '100000', // in USD
        minVolumeThreshold: '10000',     // in USD/24h
        volatilityWindow: 24,            // hours
        backtestPeriod: 30,             // days
    },
    strategy: {
        defaultRiskLevel: 'medium' as const,
        maxStrategiesPerPool: 3,
        updateInterval: 3600000,         // 1 hour in milliseconds
        metrics: {
            expectedReturnWeight: 0.4,
            riskWeight: 0.3,
            liquidityWeight: 0.3,
        }
    },
    storage: {
        retentionPeriod: 90,            // days
        batchSize: 1000,
    }
};
