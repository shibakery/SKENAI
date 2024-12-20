import { ethers } from 'ethers';
import { EventEmitter } from 'events';
import { BoronOracle__factory, BoronStable__factory, MarketOperations__factory } from '../typechain';

export interface MarketConfig {
    minOperationSize: ethers.BigNumber;
    maxOperationSize: ethers.BigNumber;
    cooldownPeriod: number;
    priceImpactLimit: ethers.BigNumber;
    operationFee: ethers.BigNumber;
}

export interface MarketMetrics {
    totalMinted: ethers.BigNumber;
    totalBurned: ethers.BigNumber;
    averagePrice: ethers.BigNumber;
    volatilityIndex: ethers.BigNumber;
}

export interface OperationResult {
    success: boolean;
    transactionHash: string;
    operationId: number;
    metrics: MarketMetrics;
}

/**
 * Market Operator for BRST
 */
export class MarketOperator extends EventEmitter {
    private readonly operations: ethers.Contract;
    private readonly oracle: ethers.Contract;
    private readonly stable: ethers.Contract;
    private readonly signer: ethers.Signer;
    
    constructor(
        operationsAddress: string,
        oracleAddress: string,
        stableAddress: string,
        signer: ethers.Signer
    ) {
        super();
        this.signer = signer;
        
        // Initialize contracts
        this.operations = MarketOperations__factory.connect(
            operationsAddress,
            signer
        );
        this.oracle = BoronOracle__factory.connect(
            oracleAddress,
            signer
        );
        this.stable = BoronStable__factory.connect(
            stableAddress,
            signer
        );
        
        // Setup event listeners
        this.setupEventListeners();
    }
    
    /**
     * Execute market operation
     */
    public async executeOperation(
        type: 'MINT' | 'BURN' | 'REBALANCE',
        amount: ethers.BigNumber
    ): Promise<OperationResult> {
        try {
            // Validate market conditions
            await this.validateMarketConditions(amount);
            
            // Execute operation
            const tx = await this.operations.executeOperation(
                this.getOperationType(type),
                amount
            );
            const receipt = await tx.wait();
            
            // Get operation details
            const event = receipt.events?.find(
                e => e.event === 'OperationExecuted'
            );
            const operationId = event?.args?.id.toNumber();
            
            // Get updated metrics
            const metrics = await this.getMetrics();
            
            return {
                success: true,
                transactionHash: receipt.transactionHash,
                operationId,
                metrics
            };
        } catch (error) {
            console.error('Operation failed:', error);
            throw error;
        }
    }
    
    /**
     * Get market metrics
     */
    public async getMetrics(): Promise<MarketMetrics> {
        const [
            minted,
            burned,
            avgPrice,
            volatility
        ] = await this.operations.getMetrics();
        
        return {
            totalMinted: minted,
            totalBurned: burned,
            averagePrice: avgPrice,
            volatilityIndex: volatility
        };
    }
    
    /**
     * Get market parameters
     */
    public async getParameters(): Promise<MarketConfig> {
        const params = await this.operations.params();
        return {
            minOperationSize: params.minOperationSize,
            maxOperationSize: params.maxOperationSize,
            cooldownPeriod: params.cooldownPeriod.toNumber(),
            priceImpactLimit: params.priceImpactLimit,
            operationFee: params.operationFee
        };
    }
    
    /**
     * Update market parameters
     */
    public async updateParameters(
        config: Partial<MarketConfig>
    ): Promise<boolean> {
        try {
            const currentParams = await this.getParameters();
            const newParams = { ...currentParams, ...config };
            
            const tx = await this.operations.updateParams(
                newParams.minOperationSize,
                newParams.maxOperationSize,
                newParams.cooldownPeriod,
                newParams.priceImpactLimit,
                newParams.operationFee
            );
            await tx.wait();
            
            return true;
        } catch (error) {
            console.error('Failed to update parameters:', error);
            return false;
        }
    }
    
    /**
     * Get market analysis
     */
    public async analyzeMarket(): Promise<{
        supplyDemandRatio: number;
        priceStability: number;
        operationalHealth: number;
    }> {
        // Get market data
        const [supply, demand, price] = await this.oracle.getLatestMarketData();
        const metrics = await this.getMetrics();
        
        // Calculate ratios
        const supplyDemandRatio = supply.mul(1e18).div(demand).toNumber() / 1e18;
        const priceStability = 1 - (metrics.volatilityIndex.toNumber() / 1e18);
        const operationalHealth = this.calculateHealth(metrics);
        
        return {
            supplyDemandRatio,
            priceStability,
            operationalHealth
        };
    }
    
    /**
     * Monitor market conditions
     */
    public async startMonitoring(
        interval: number = 60000
    ): Promise<NodeJS.Timer> {
        return setInterval(async () => {
            try {
                const analysis = await this.analyzeMarket();
                this.emit('marketUpdate', analysis);
                
                // Check for required operations
                if (analysis.supplyDemandRatio < 0.95) {
                    this.emit('operationNeeded', {
                        type: 'MINT',
                        reason: 'Supply shortage'
                    });
                } else if (analysis.supplyDemandRatio > 1.05) {
                    this.emit('operationNeeded', {
                        type: 'BURN',
                        reason: 'Excess supply'
                    });
                }
            } catch (error) {
                this.emit('error', error);
            }
        }, interval);
    }
    
    private setupEventListeners(): void {
        this.operations.on('OperationExecuted', (id, type, amount) => {
            this.emit('operation', { id, type, amount });
        });
        
        this.oracle.on('MarketDataUpdated', (supply, demand, price) => {
            this.emit('marketData', { supply, demand, price });
        });
    }
    
    private async validateMarketConditions(
        amount: ethers.BigNumber
    ): Promise<void> {
        const params = await this.getParameters();
        
        // Check operation size
        if (amount.lt(params.minOperationSize)) {
            throw new Error('Operation size too small');
        }
        if (amount.gt(params.maxOperationSize)) {
            throw new Error('Operation size too large');
        }
        
        // Check cooldown
        const metrics = await this.getMetrics();
        const lastOp = await this.operations.metrics();
        if (Date.now() / 1000 - lastOp.lastOperationTime.toNumber() < params.cooldownPeriod) {
            throw new Error('Cooldown period active');
        }
    }
    
    private getOperationType(type: string): number {
        switch (type) {
            case 'MINT': return 0;
            case 'BURN': return 1;
            case 'REBALANCE': return 2;
            default: throw new Error('Invalid operation type');
        }
    }
    
    private calculateHealth(metrics: MarketMetrics): number {
        const mintBurnRatio = metrics.totalMinted
            .mul(1e18)
            .div(metrics.totalBurned.add(1))
            .toNumber() / 1e18;
        
        const volatility = metrics.volatilityIndex.toNumber() / 1e18;
        
        // Health score between 0 and 1
        return Math.min(
            1,
            (1 / Math.abs(mintBurnRatio - 1) + (1 - volatility)) / 2
        );
    }
}
