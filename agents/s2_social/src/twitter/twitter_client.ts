import { TwitterApi } from 'twitter-api-v2';
import { EventEmitter } from 'events';

export interface TweetAnalysis {
    sentiment: 'positive' | 'negative' | 'neutral';
    confidence: number;
    topics: string[];
    relevance: number;
}

export class TwitterClient extends EventEmitter {
    private client: TwitterApi;
    private accountUsername: string;

    constructor(bearerToken: string, accountUsername: string) {
        super();
        this.client = new TwitterApi(bearerToken);
        this.accountUsername = accountUsername;
    }

    async postTweet(content: string, replyToId?: string): Promise<any> {
        try {
            const tweet = await this.client.v2.tweet({
                text: content,
                reply: replyToId ? { in_reply_to_tweet_id: replyToId } : undefined
            });
            this.emit('tweet_posted', tweet);
            return tweet;
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }

    async monitorMentions(callback: (tweet: any) => void): Promise<void> {
        try {
            const rules = await this.client.v2.streamRules();
            if (rules.data?.length) {
                await this.client.v2.updateStreamRules({
                    delete: { ids: rules.data.map(rule => rule.id) }
                });
            }

            await this.client.v2.updateStreamRules({
                add: [{ value: `@${this.accountUsername}` }]
            });

            const stream = await this.client.v2.searchStream({
                'tweet.fields': ['author_id', 'conversation_id', 'created_at', 'referenced_tweets'],
                'user.fields': ['username', 'name', 'profile_image_url']
            });

            stream.on('data', async tweet => {
                this.emit('mention_received', tweet);
                callback(tweet);
            });

        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }

    async analyzeTweetSentiment(tweetId: string): Promise<TweetAnalysis> {
        try {
            const tweet = await this.client.v2.singleTweet(tweetId, {
                'tweet.fields': ['text', 'context_annotations']
            });

            // Implement sentiment analysis here
            // This is a placeholder implementation
            const analysis: TweetAnalysis = {
                sentiment: 'neutral',
                confidence: 0.5,
                topics: [],
                relevance: 0.5
            };

            this.emit('sentiment_analyzed', {
                tweetId,
                analysis
            });

            return analysis;
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }

    async searchRelevantTweets(query: string): Promise<any[]> {
        try {
            const tweets = await this.client.v2.search(query, {
                'tweet.fields': ['author_id', 'created_at', 'public_metrics'],
                'user.fields': ['username', 'name'],
                max_results: 100
            });

            this.emit('search_completed', {
                query,
                results: tweets
            });

            return tweets.data;
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }

    async engageWithTweet(tweetId: string, type: 'like' | 'retweet' | 'quote' | 'reply', content?: string): Promise<void> {
        try {
            switch (type) {
                case 'like':
                    await this.client.v2.like(this.accountUsername, tweetId);
                    break;
                case 'retweet':
                    await this.client.v2.retweet(this.accountUsername, tweetId);
                    break;
                case 'quote':
                    if (content) {
                        await this.client.v2.tweet({
                            text: content,
                            quote_tweet_id: tweetId
                        });
                    }
                    break;
                case 'reply':
                    if (content) {
                        await this.postTweet(content, tweetId);
                    }
                    break;
            }
            this.emit('engagement_completed', {
                tweetId,
                type
            });
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }
}
