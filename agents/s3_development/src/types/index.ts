export interface DAOProposal {
    id: string;
    title: string;
    description: string;
    type: 'strategy' | 'governance' | 'treasury' | 'development';
    status: 'draft' | 'active' | 'executed' | 'failed' | 'cancelled';
    creator: string;
    createdAt: number;
    votingEnds: number;
    votes: {
        for: number;
        against: number;
        abstain: number;
    };
    quorum: number;
    actions: ProposalAction[];
}

export interface ProposalAction {
    type: 'contract_call' | 'treasury_transfer' | 'parameter_update';
    target: string;
    value?: string;
    data?: string;
    description: string;
}

export interface LiquidityPool {
    address: string;
    token0: string;
    token1: string;
    reserve0: string;
    reserve1: string;
    totalSupply: string;
    fee: number;
    strategy?: {
        name: string;
        parameters: Record<string, any>;
        performance: PoolPerformance;
    };
}

export interface PoolPerformance {
    volume24h: string;
    fees24h: string;
    apy: number;
    tvl: string;
    impermanentLoss: number;
    utilizationRate: number;
}

export interface Strategy {
    name: string;
    description: string;
    parameters: Record<string, any>;
    riskLevel: 'low' | 'medium' | 'high';
    expectedReturn: number;
    requirements: {
        minLiquidity: string;
        minVolume: string;
        maxSlippage: number;
    };
}

export interface CrowdfundingCampaign {
    id: string;
    title: string;
    description: string;
    target: string;
    raised: string;
    token: string;
    start: number;
    end: number;
    creator: string;
    status: 'active' | 'completed' | 'failed';
    contributors: {
        address: string;
        amount: string;
    }[];
}
