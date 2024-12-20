import { ethers } from 'ethers';
import { MarketOperator } from '../MarketOperator';

interface MarketState {
    price: number;
    supply: number;
    demand: number;
    stability: number;
    operations: OperationSummary[];
}

interface OperationSummary {
    id: number;
    type: string;
    amount: number;
    timestamp: number;
    impact: number;
}

interface AlertConfig {
    priceDeviation: number;
    supplyThreshold: number;
    volatilityThreshold: number;
}

/**
 * Market Analytics Dashboard
 */
export class MarketDashboard {
    private operator: MarketOperator;
    private state: MarketState;
    private alerts: AlertConfig;
    private subscribers: Set<(alert: string) => void>;
    
    constructor(
        operator: MarketOperator,
        alertConfig?: Partial<AlertConfig>
    ) {
        this.operator = operator;
        this.subscribers = new Set();
        
        // Initialize state
        this.state = {
            price: 0,
            supply: 0,
            demand: 0,
            stability: 0,
            operations: []
        };
        
        // Set alert thresholds
        this.alerts = {
            priceDeviation: alertConfig?.priceDeviation || 0.05,
            supplyThreshold: alertConfig?.supplyThreshold || 0.1,
            volatilityThreshold: alertConfig?.volatilityThreshold || 0.03
        };
        
        // Setup event listeners
        this.setupListeners();
    }
    
    /**
     * Start dashboard monitoring
     */
    public async start(): Promise<void> {
        // Initial state update
        await this.updateState();
        
        // Start market monitoring
        this.operator.startMonitoring(30000); // 30 second intervals
    }
    
    /**
     * Get current market state
     */
    public getState(): MarketState {
        return { ...this.state };
    }
    
    /**
     * Subscribe to alerts
     */
    public subscribe(callback: (alert: string) => void): void {
        this.subscribers.add(callback);
    }
    
    /**
     * Unsubscribe from alerts
     */
    public unsubscribe(callback: (alert: string) => void): void {
        this.subscribers.delete(callback);
    }
    
    /**
     * Get market analysis
     */
    public async getAnalysis(): Promise<{
        marketHealth: number;
        recommendations: string[];
        risks: string[];
    }> {
        const analysis = await this.operator.analyzeMarket();
        const metrics = await this.operator.getMetrics();
        
        const recommendations: string[] = [];
        const risks: string[] = [];
        
        // Analyze supply-demand ratio
        if (analysis.supplyDemandRatio < 0.95) {
            recommendations.push('Consider minting tokens to meet demand');
            risks.push('Supply shortage risk');
        } else if (analysis.supplyDemandRatio > 1.05) {
            recommendations.push('Consider burning tokens to reduce supply');
            risks.push('Oversupply risk');
        }
        
        // Analyze price stability
        if (analysis.priceStability < 0.95) {
            recommendations.push('Implement stricter operation limits');
            risks.push('Price volatility risk');
        }
        
        // Calculate market health
        const marketHealth = (
            analysis.priceStability * 0.4 +
            (1 - Math.abs(1 - analysis.supplyDemandRatio)) * 0.4 +
            analysis.operationalHealth * 0.2
        );
        
        return {
            marketHealth,
            recommendations,
            risks
        };
    }
    
    /**
     * Get operation history
     */
    public async getOperationHistory(
        days: number = 7
    ): Promise<OperationSummary[]> {
        const startTime = Math.floor(Date.now() / 1000) - (days * 86400);
        return this.state.operations.filter(op => op.timestamp >= startTime);
    }
    
    /**
     * Get price chart data
     */
    public async getPriceChart(
        interval: '1h' | '1d' | '1w'
    ): Promise<{
        timestamps: number[];
        prices: number[];
        volumes: number[];
    }> {
        // Implementation would depend on data storage solution
        // This is a placeholder returning mock data
        const now = Math.floor(Date.now() / 1000);
        const timestamps: number[] = [];
        const prices: number[] = [];
        const volumes: number[] = [];
        
        let timeStep: number;
        switch (interval) {
            case '1h': timeStep = 60; break;
            case '1d': timeStep = 3600; break;
            case '1w': timeStep = 86400; break;
        }
        
        for (let i = 0; i < 100; i++) {
            timestamps.push(now - (i * timeStep));
            prices.push(1 + (Math.random() - 0.5) * 0.01);
            volumes.push(Math.random() * 1000000);
        }
        
        return { timestamps, prices, volumes };
    }
    
    private async updateState(): Promise<void> {
        try {
            // Get market data
            const marketData = await this.operator.oracle.getLatestMarketData();
            const metrics = await this.operator.getMetrics();
            const analysis = await this.operator.analyzeMarket();
            
            // Update state
            this.state = {
                price: marketData.price.toNumber() / 1e18,
                supply: marketData.supply.toNumber(),
                demand: marketData.demand.toNumber(),
                stability: analysis.priceStability,
                operations: [...this.state.operations]
            };
            
            // Check alerts
            this.checkAlerts();
        } catch (error) {
            console.error('Failed to update state:', error);
        }
    }
    
    private checkAlerts(): void {
        // Check price deviation
        if (Math.abs(this.state.price - 1) > this.alerts.priceDeviation) {
            this.notify(`Price deviation alert: ${this.state.price}`);
        }
        
        // Check supply-demand imbalance
        const supplyDemandRatio = this.state.supply / this.state.demand;
        if (Math.abs(1 - supplyDemandRatio) > this.alerts.supplyThreshold) {
            this.notify(`Supply-demand imbalance: ${supplyDemandRatio}`);
        }
        
        // Check stability
        if (1 - this.state.stability > this.alerts.volatilityThreshold) {
            this.notify(`High volatility alert: ${1 - this.state.stability}`);
        }
    }
    
    private notify(alert: string): void {
        this.subscribers.forEach(callback => callback(alert));
    }
    
    private setupListeners(): void {
        this.operator.on('marketData', async () => {
            await this.updateState();
        });
        
        this.operator.on('operation', (op) => {
            this.state.operations.unshift({
                id: op.id,
                type: ['MINT', 'BURN', 'REBALANCE'][op.type],
                amount: op.amount.toNumber() / 1e18,
                timestamp: Math.floor(Date.now() / 1000),
                impact: 0 // Calculate actual impact
            });
            
            // Keep only last 1000 operations
            if (this.state.operations.length > 1000) {
                this.state.operations.pop();
            }
        });
        
        this.operator.on('error', (error) => {
            this.notify(`Market operation error: ${error.message}`);
        });
    }
}
