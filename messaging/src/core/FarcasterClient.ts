import { HubRpcClient } from '@farcaster/hub-web';
import { ethers } from 'ethers';

export class FarcasterClient {
    private client: HubRpcClient;
    private messageRewardsContract: ethers.Contract;
    
    constructor(
        hubUrl: string,
        rewardsContractAddress: string,
        provider: ethers.providers.Provider
    ) {
        this.client = new HubRpcClient(hubUrl);
        
        // Initialize rewards contract
        const abi = require('../../contracts/artifacts/MessageRewards.json').abi;
        this.messageRewardsContract = new ethers.Contract(
            rewardsContractAddress,
            abi,
            provider
        );
    }
    
    /**
     * Posts a message to Farcaster and processes rewards
     */
    async postMessage(
        content: string,
        signer: ethers.Signer,
        options: {
            replyTo?: string;
            mentions?: string[];
            attachments?: string[];
        } = {}
    ) {
        try {
            // Post message to Farcaster
            const message = await this.client.submitMessage({
                text: content,
                replyTo: options.replyTo,
                mentions: options.mentions,
                attachments: options.attachments
            });
            
            // Calculate quality score (placeholder implementation)
            const qualityScore = await this.calculateQualityScore(content);
            
            // Process rewards
            const activityType = options.replyTo ? 'reply' : 'message';
            await this.processRewards(signer, activityType, qualityScore);
            
            return message;
        } catch (error) {
            console.error('Error posting message:', error);
            throw error;
        }
    }
    
    /**
     * Processes reactions and rewards
     */
    async addReaction(
        messageId: string,
        reactionType: string,
        signer: ethers.Signer
    ) {
        try {
            // Add reaction to Farcaster
            const reaction = await this.client.submitReaction({
                messageId,
                type: reactionType
            });
            
            // Process reaction rewards
            await this.processRewards(signer, 'reaction', 100);
            
            return reaction;
        } catch (error) {
            console.error('Error adding reaction:', error);
            throw error;
        }
    }
    
    /**
     * Processes rewards for user activity
     */
    private async processRewards(
        signer: ethers.Signer,
        activityType: string,
        qualityScore: number
    ) {
        try {
            const address = await signer.getAddress();
            
            // Record activity and distribute rewards
            const tx = await this.messageRewardsContract.connect(signer).recordActivity(
                address,
                activityType,
                qualityScore
            );
            
            await tx.wait();
            
            // Update daily streak
            await this.messageRewardsContract.connect(signer).updateDailyStreak(address);
        } catch (error) {
            console.error('Error processing rewards:', error);
            throw error;
        }
    }
    
    /**
     * Calculates quality score for content
     * TODO: Implement more sophisticated quality scoring
     */
    private async calculateQualityScore(content: string): Promise<number> {
        // Placeholder implementation
        // Should be replaced with actual quality metrics
        const baseScore = 70; // Base score
        const lengthBonus = Math.min(content.length / 100 * 10, 20); // Up to 20 points for length
        const hasLinks = content.includes('http') ? 5 : 0; // 5 points for including links
        const hasMentions = content.includes('@') ? 5 : 0; // 5 points for mentions
        
        return Math.min(baseScore + lengthBonus + hasLinks + hasMentions, 100);
    }
    
    /**
     * Subscribes to user activity for reward tracking
     */
    async subscribeToUserActivity(address: string) {
        try {
            // Subscribe to user's messages
            const messageStream = await this.client.subscribeToUserMessages(address);
            
            messageStream.on('message', async (message) => {
                // Process new messages for rewards
                const qualityScore = await this.calculateQualityScore(message.text);
                await this.processRewards(
                    this.messageRewardsContract.signer,
                    'message',
                    qualityScore
                );
            });
            
            return messageStream;
        } catch (error) {
            console.error('Error subscribing to user activity:', error);
            throw error;
        }
    }
}
