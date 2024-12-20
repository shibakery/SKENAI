import { ethers } from 'ethers';
import { FarcasterClient } from '../core/FarcasterClient';

export class DAOIntegration {
    private tokenGateContract: ethers.Contract;
    private proposalManagerContract: ethers.Contract;
    private farcasterClient: FarcasterClient;
    
    constructor(
        tokenGateAddress: string,
        proposalManagerAddress: string,
        provider: ethers.providers.Provider,
        farcasterClient: FarcasterClient
    ) {
        // Initialize contracts
        const tokenGateAbi = require('../../contracts/artifacts/TokenGate.json').abi;
        const proposalManagerAbi = require('../../contracts/artifacts/ProposalManager.json').abi;
        
        this.tokenGateContract = new ethers.Contract(
            tokenGateAddress,
            tokenGateAbi,
            provider
        );
        
        this.proposalManagerContract = new ethers.Contract(
            proposalManagerAddress,
            proposalManagerAbi,
            provider
        );
        
        this.farcasterClient = farcasterClient;
    }
    
    /**
     * Creates a new proposal with Farcaster integration
     */
    async createProposal(
        title: string,
        description: string,
        signer: ethers.Signer
    ) {
        try {
            // Create proposal on-chain
            const tx = await this.proposalManagerContract
                .connect(signer)
                .createProposal(title, description);
            const receipt = await tx.wait();
            
            // Get proposal ID from event
            const event = receipt.events?.find(
                (e: any) => e.event === 'ProposalCreated'
            );
            const proposalId = event?.args?.proposalId;
            
            // Post proposal to Farcaster
            const content = `🏛 New Proposal #${proposalId}\n\n${title}\n\n${description}\n\n#DAOProposal`;
            await this.farcasterClient.postMessage(content, signer);
            
            return proposalId;
        } catch (error) {
            console.error('Error creating proposal:', error);
            throw error;
        }
    }
    
    /**
     * Adds a discussion to a proposal with Farcaster integration
     */
    async addDiscussion(
        proposalId: number,
        content: string,
        signer: ethers.Signer
    ) {
        try {
            // Add discussion on-chain
            const tx = await this.proposalManagerContract
                .connect(signer)
                .addDiscussion(proposalId, content);
            const receipt = await tx.wait();
            
            // Get discussion ID from event
            const event = receipt.events?.find(
                (e: any) => e.event === 'DiscussionAdded'
            );
            const discussionId = event?.args?.discussionId;
            
            // Post discussion to Farcaster
            const farcasterContent = `💬 Discussion on Proposal #${proposalId}\n\n${content}\n\n#DAODiscussion`;
            await this.farcasterClient.postMessage(farcasterContent, signer, {
                replyTo: `proposal-${proposalId}`
            });
            
            return discussionId;
        } catch (error) {
            console.error('Error adding discussion:', error);
            throw error;
        }
    }
    
    /**
     * Casts a vote on a proposal with Farcaster integration
     */
    async castVote(
        proposalId: number,
        support: boolean,
        signer: ethers.Signer
    ) {
        try {
            // Cast vote on-chain
            const tx = await this.proposalManagerContract
                .connect(signer)
                .castVote(proposalId, support);
            await tx.wait();
            
            // Post vote to Farcaster
            const voteType = support ? '✅ Voted FOR' : '❌ Voted AGAINST';
            const content = `${voteType} Proposal #${proposalId}\n\n#DAOVote`;
            await this.farcasterClient.postMessage(content, signer, {
                replyTo: `proposal-${proposalId}`
            });
        } catch (error) {
            console.error('Error casting vote:', error);
            throw error;
        }
    }
    
    /**
     * Checks access level for a user
     */
    async checkAccess(
        user: string,
        feature: string
    ): Promise<boolean> {
        try {
            return await this.tokenGateContract.hasAccess(user, feature);
        } catch (error) {
            console.error('Error checking access:', error);
            throw error;
        }
    }
    
    /**
     * Gets proposal details with discussion threads
     */
    async getProposalDetails(proposalId: number) {
        try {
            const proposal = await this.proposalManagerContract.getProposal(proposalId);
            
            // Get Farcaster discussions
            const discussions = await this.farcasterClient.client.getMessagesByParent(
                `proposal-${proposalId}`
            );
            
            return {
                ...proposal,
                discussions
            };
        } catch (error) {
            console.error('Error getting proposal details:', error);
            throw error;
        }
    }
    
    /**
     * Subscribes to proposal events
     */
    subscribeToProposalEvents(callback: (event: any) => void) {
        // Subscribe to on-chain events
        this.proposalManagerContract.on('ProposalCreated', callback);
        this.proposalManagerContract.on('DiscussionAdded', callback);
        this.proposalManagerContract.on('VoteCast', callback);
        this.proposalManagerContract.on('ProposalStateChanged', callback);
        
        // Subscribe to Farcaster events
        this.farcasterClient.subscribeToUserActivity('*');
    }
}
