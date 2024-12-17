import { TwitterClient, TweetAnalysis } from '../twitter/twitter_client';
import { EventEmitter } from 'events';

interface EngagementRule {
    type: 'keyword' | 'sentiment' | 'topic';
    condition: string | RegExp;
    response: string | ((tweet: any) => string);
    priority: number;
}

export class EngagementManager extends EventEmitter {
    private twitterClient: TwitterClient;
    private rules: EngagementRule[];
    private engagementDelay: number;
    private isProcessing: boolean;

    constructor(twitterClient: TwitterClient, engagementDelay: number = 2000) {
        super();
        this.twitterClient = twitterClient;
        this.rules = [];
        this.engagementDelay = engagementDelay;
        this.isProcessing = false;

        // Start monitoring mentions
        this.initializeMentionsMonitoring();
    }

    private async initializeMentionsMonitoring(): Promise<void> {
        await this.twitterClient.monitorMentions(async (tweet) => {
            await this.processTweet(tweet);
        });
    }

    addEngagementRule(rule: EngagementRule): void {
        this.rules.push(rule);
        this.rules.sort((a, b) => b.priority - a.priority);
        this.emit('rule_added', rule);
    }

    private async processTweet(tweet: any): Promise<void> {
        if (this.isProcessing) {
            return;
        }

        this.isProcessing = true;
        try {
            const analysis = await this.twitterClient.analyzeTweetSentiment(tweet.id);
            const response = await this.generateResponse(tweet, analysis);

            if (response) {
                await new Promise(resolve => setTimeout(resolve, this.engagementDelay));
                await this.twitterClient.postTweet(response, tweet.id);
                this.emit('response_sent', {
                    originalTweet: tweet,
                    response
                });
            }
        } catch (error) {
            this.emit('error', error);
        } finally {
            this.isProcessing = false;
        }
    }

    private async generateResponse(tweet: any, analysis: TweetAnalysis): Promise<string | null> {
        for (const rule of this.rules) {
            if (this.ruleMatches(rule, tweet, analysis)) {
                const response = typeof rule.response === 'function' 
                    ? rule.response(tweet)
                    : rule.response;
                return response;
            }
        }
        return null;
    }

    private ruleMatches(rule: EngagementRule, tweet: any, analysis: TweetAnalysis): boolean {
        switch (rule.type) {
            case 'keyword':
                return typeof rule.condition === 'string' 
                    ? tweet.text.toLowerCase().includes(rule.condition.toLowerCase())
                    : rule.condition.test(tweet.text);
            
            case 'sentiment':
                return analysis.sentiment === rule.condition;
            
            case 'topic':
                return analysis.topics.includes(rule.condition);
            
            default:
                return false;
        }
    }

    async generateDailyReport(): Promise<any> {
        // Implement daily engagement metrics reporting
        return {
            totalEngagements: 0,
            responseRate: 0,
            averageSentiment: 'neutral',
            topTopics: [],
            // Add more metrics as needed
        };
    }

    setEngagementDelay(delay: number): void {
        this.engagementDelay = delay;
        this.emit('delay_updated', delay);
    }

    clearRules(): void {
        this.rules = [];
        this.emit('rules_cleared');
    }
}
