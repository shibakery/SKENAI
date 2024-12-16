import { TwitterApi } from 'twitter-api-v2';
import { EventEmitter } from 'events';
import { MessageBroker } from '../../../shared/communication/message_broker';

interface TwitterConfig {
    apiKey: string;
    apiKeySecret: string;
    accessToken: string;
    accessTokenSecret: string;
    bearerToken: string;
}

export class TwitterManager extends EventEmitter {
    private client: TwitterApi;
    private messageBroker: MessageBroker;
    private readonly CATEGORIES = {
        DEFI: ['defi', 'decentralizedfinance', 'yield', 'liquidity'],
        DAO: ['dao', 'governance', 'voting', 'proposal'],
        CRYPTO: ['crypto', 'bitcoin', 'ethereum', 'web3'],
        INVESTING: ['investing', 'trading', 'finance', 'markets'],
        DEPIN: ['depin', 'decentralizedinfra', 'iot', 'infrastructure'],
        RWA: ['rwa', 'realworldassets', 'tokenization'],
        TRADE_FINANCE: ['tradefinance', 'supplychain', 'commerce']
    };

    constructor(config: TwitterConfig) {
        super();
        this.client = new TwitterApi({
            appKey: config.apiKey,
            appSecret: config.apiKeySecret,
            accessToken: config.accessToken,
            accessSecret: config.accessTokenSecret
        });
        this.messageBroker = MessageBroker.getInstance();

        // Subscribe to social media related requests
        this.messageBroker.subscribe('follow_request', this.handleFollowRequest.bind(this));
        this.messageBroker.subscribe('post_request', this.handlePostRequest.bind(this));
    }

    async findRelevantAccounts(): Promise<Map<string, string[]>> {
        const relevantAccounts = new Map<string, string[]>();

        for (const [category, keywords] of Object.entries(this.CATEGORIES)) {
            const accounts: string[] = [];

            for (const keyword of keywords) {
                try {
                    const searchResults = await this.client.v2.search(
                        `${keyword} -is:retweet -is:reply lang:en`,
                        {
                            'tweet.fields': ['author_id', 'public_metrics'],
                            max_results: 100
                        }
                    );

                    const userIds = new Set<string>();
                    for (const tweet of searchResults.data || []) {
                        if (tweet.public_metrics?.retweet_count! > 50 || 
                            tweet.public_metrics?.like_count! > 100) {
                            userIds.add(tweet.author_id!);
                        }
                    }

                    const users = await this.client.v2.users(Array.from(userIds), {
                        'user.fields': ['public_metrics', 'description']
                    });

                    for (const user of users.data || []) {
                        if (user.public_metrics?.followers_count! > 1000 &&
                            this.isRelevantProfile(user.description!, category)) {
                            accounts.push(user.username);
                        }
                    }
                } catch (error) {
                    console.error(`Error searching for ${keyword}:`, error);
                    this.emit('error', error);
                }
            }

            relevantAccounts.set(category, Array.from(new Set(accounts)));
        }

        return relevantAccounts;
    }

    private isRelevantProfile(description: string, category: string): boolean {
        const keywords = this.CATEGORIES[category as keyof typeof this.CATEGORIES];
        const descriptionLower = description.toLowerCase();
        return keywords.some(keyword => descriptionLower.includes(keyword));
    }

    async followAccounts(usernames: string[]): Promise<void> {
        const currentUser = await this.client.v2.me();

        for (const username of usernames) {
            try {
                const user = await this.client.v2.userByUsername(username);
                await this.client.v2.follow(currentUser.data.id, user.data.id);
                
                this.messageBroker.publish({
                    type: 'follow_success',
                    source: 'twitter_manager',
                    target: 'all',
                    payload: {
                        username,
                        timestamp: new Date().toISOString()
                    }
                });

                // Rate limiting - wait 1 second between follows
                await new Promise(resolve => setTimeout(resolve, 1000));
            } catch (error) {
                console.error(`Error following ${username}:`, error);
                this.emit('error', error);
            }
        }
    }

    async createPost(content: string, replyToId?: string): Promise<void> {
        try {
            const tweet = await this.client.v2.tweet({
                text: content,
                reply: replyToId ? { in_reply_to_tweet_id: replyToId } : undefined
            });

            this.messageBroker.publish({
                type: 'post_success',
                source: 'twitter_manager',
                target: 'all',
                payload: {
                    tweetId: tweet.data.id,
                    content,
                    timestamp: new Date().toISOString()
                }
            });
        } catch (error) {
            console.error('Error creating post:', error);
            this.emit('error', error);
        }
    }

    private async handleFollowRequest(message: any): Promise<void> {
        const { usernames } = message.payload;

        try {
            await this.followAccounts(usernames);
            
            this.messageBroker.publish({
                type: 'follow_batch_complete',
                source: 'twitter_manager',
                target: message.source,
                payload: {
                    usernames,
                    timestamp: new Date().toISOString()
                }
            });
        } catch (error) {
            this.messageBroker.publish({
                type: 'follow_batch_failed',
                source: 'twitter_manager',
                target: message.source,
                payload: {
                    error: error.message,
                    usernames
                }
            });
        }
    }

    private async handlePostRequest(message: any): Promise<void> {
        const { content, replyToId } = message.payload;

        try {
            await this.createPost(content, replyToId);
        } catch (error) {
            this.messageBroker.publish({
                type: 'post_failed',
                source: 'twitter_manager',
                target: message.source,
                payload: {
                    error: error.message,
                    content
                }
            });
        }
    }
}
