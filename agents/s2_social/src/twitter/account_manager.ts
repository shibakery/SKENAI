import { TwitterManager } from './twitter_manager';
import { MessageBroker } from '../../../shared/communication/message_broker';

export class AccountManager {
    private twitterManager: TwitterManager;
    private messageBroker: MessageBroker;
    private followedAccounts: Set<string>;
    private categoryFollowLimits: Map<string, number>;

    constructor(twitterManager: TwitterManager) {
        this.twitterManager = twitterManager;
        this.messageBroker = MessageBroker.getInstance();
        this.followedAccounts = new Set();
        
        // Set follow limits per category
        this.categoryFollowLimits = new Map([
            ['DEFI', 50],
            ['DAO', 30],
            ['CRYPTO', 40],
            ['INVESTING', 40],
            ['DEPIN', 20],
            ['RWA', 20],
            ['TRADE_FINANCE', 20]
        ]);

        // Subscribe to account management requests
        this.messageBroker.subscribe('discover_accounts', this.handleDiscoverRequest.bind(this));
        this.messageBroker.subscribe('manage_follows', this.handleFollowManagement.bind(this));
    }

    async discoverAndFollowAccounts(): Promise<void> {
        try {
            // Find relevant accounts per category
            const relevantAccounts = await this.twitterManager.findRelevantAccounts();
            
            // Process each category
            for (const [category, accounts] of relevantAccounts.entries()) {
                const limit = this.categoryFollowLimits.get(category) || 20;
                const accountsToFollow = this.filterAccountsToFollow(accounts, limit);
                
                if (accountsToFollow.length > 0) {
                    await this.twitterManager.followAccounts(accountsToFollow);
                    accountsToFollow.forEach(account => this.followedAccounts.add(account));

                    this.messageBroker.publish({
                        type: 'category_follow_complete',
                        source: 'account_manager',
                        target: 'all',
                        payload: {
                            category,
                            accountsFollowed: accountsToFollow,
                            timestamp: new Date().toISOString()
                        }
                    });
                }
            }
        } catch (error) {
            console.error('Error in discover and follow process:', error);
            this.messageBroker.publish({
                type: 'discover_follow_error',
                source: 'account_manager',
                target: 'all',
                payload: {
                    error: error.message,
                    timestamp: new Date().toISOString()
                }
            });
        }
    }

    private filterAccountsToFollow(accounts: string[], limit: number): string[] {
        return accounts
            .filter(account => !this.followedAccounts.has(account))
            .slice(0, limit);
    }

    getFollowedAccounts(): string[] {
        return Array.from(this.followedAccounts);
    }

    getCategoryFollowLimits(): Map<string, number> {
        return new Map(this.categoryFollowLimits);
    }

    private async handleDiscoverRequest(message: any): Promise<void> {
        try {
            await this.discoverAndFollowAccounts();
            
            this.messageBroker.publish({
                type: 'discover_complete',
                source: 'account_manager',
                target: message.source,
                payload: {
                    followedAccounts: Array.from(this.followedAccounts),
                    timestamp: new Date().toISOString()
                }
            });
        } catch (error) {
            this.messageBroker.publish({
                type: 'discover_failed',
                source: 'account_manager',
                target: message.source,
                payload: {
                    error: error.message
                }
            });
        }
    }

    private async handleFollowManagement(message: any): Promise<void> {
        const { action, category, limit } = message.payload;

        try {
            switch (action) {
                case 'update_limit':
                    this.categoryFollowLimits.set(category, limit);
                    break;
                case 'clear_category':
                    // Implementation for unfollowing accounts in a category
                    break;
                default:
                    throw new Error(`Unknown action: ${action}`);
            }

            this.messageBroker.publish({
                type: 'follow_management_complete',
                source: 'account_manager',
                target: message.source,
                payload: {
                    action,
                    category,
                    timestamp: new Date().toISOString()
                }
            });
        } catch (error) {
            this.messageBroker.publish({
                type: 'follow_management_failed',
                source: 'account_manager',
                target: message.source,
                payload: {
                    error: error.message,
                    action,
                    category
                }
            });
        }
    }
}
