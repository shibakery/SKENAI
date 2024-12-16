import { ContentStrategy, SocialPost } from '../types';
import { MessageBroker } from '../../../shared/communication/message_broker';
import { Configuration, OpenAIApi } from 'openai';

export class ContentGenerator {
    private openai: OpenAIApi;
    private messageBroker: MessageBroker;
    private contentTemplates: Map<string, string>;
    private contentHistory: Map<string, ContentStrategy[]>;

    constructor(openaiConfig?: Configuration) {
        if (openaiConfig) {
            this.openai = new OpenAIApi(openaiConfig);
        }
        this.messageBroker = MessageBroker.getInstance();
        this.contentTemplates = this.initializeTemplates();
        this.contentHistory = new Map();

        // Subscribe to relevant events
        this.messageBroker.subscribe('market_insight', this.handleMarketInsight.bind(this));
        this.messageBroker.subscribe('strategy_update', this.handleStrategyUpdate.bind(this));
        this.messageBroker.subscribe('community_insight', this.handleCommunityInsight.bind(this));
    }

    private initializeTemplates(): Map<string, string> {
        return new Map([
            ['market_update', `
                🔍 Market Update
                
                📊 Key Metrics:
                {{metrics}}
                
                💡 What This Means:
                {{analysis}}
                
                🎯 Strategy Implications:
                {{strategy}}
                
                #DeFi #Investing {{hashtags}}
            `],
            ['strategy_insight', `
                📈 Strategy Spotlight
                
                🎯 Focus: {{strategy_name}}
                
                💫 Key Features:
                {{features}}
                
                📊 Performance:
                {{performance}}
                
                🤔 Why This Matters:
                {{importance}}
                
                #DeFiStrategy #Investment {{hashtags}}
            `],
            ['community_update', `
                🌟 Community Update
                
                👥 What's Happening:
                {{update}}
                
                🎯 Next Steps:
                {{next_steps}}
                
                💡 Get Involved:
                {{cta}}
                
                #DeFiCommunity #DAO {{hashtags}}
            `]
        ]);
    }

    async generateContent(strategy: ContentStrategy): Promise<string[]> {
        try {
            if (this.openai) {
                return await this.generateAIContent(strategy);
            } else {
                return this.generateTemplateContent(strategy);
            }
        } catch (error) {
            console.error('Content generation error:', error);
            return this.generateTemplateContent(strategy);
        }
    }

    private async generateAIContent(strategy: ContentStrategy): Promise<string[]> {
        const prompt = this.createPrompt(strategy);
        
        const response = await this.openai.createCompletion({
            model: "text-davinci-003",
            prompt,
            max_tokens: 500,
            temperature: 0.7,
            n: strategy.type === 'thread' ? strategy.keyPoints.length : 1
        });

        return response.data.choices.map(choice => choice.text?.trim() || '');
    }

    private createPrompt(strategy: ContentStrategy): string {
        const basePrompt = `Create a ${strategy.tone} ${strategy.type} about ${strategy.topic} for ${strategy.targetAudience.join(', ')}.\n\n`;
        
        const contextPrompt = `Key points to cover:\n${strategy.keyPoints.join('\n')}\n\n`;
        
        const stylePrompt = `Style guidelines:
        - Be engaging and informative
        - Use relevant emojis
        - Include hashtags: ${strategy.hashtags.join(' ')}
        - Maintain a ${strategy.tone} tone
        - Focus on providing value to the audience\n\n`;

        return basePrompt + contextPrompt + stylePrompt;
    }

    private generateTemplateContent(strategy: ContentStrategy): string[] {
        const template = this.contentTemplates.get(strategy.topic) || this.contentTemplates.get('market_update')!;
        
        if (strategy.type === 'thread') {
            return strategy.keyPoints.map(point => {
                return template
                    .replace('{{metrics}}', point)
                    .replace('{{analysis}}', this.generateAnalysis(strategy))
                    .replace('{{strategy}}', this.generateStrategyImplications(strategy))
                    .replace('{{hashtags}}', strategy.hashtags.join(' '));
            });
        }

        return [template
            .replace('{{metrics}}', strategy.keyPoints.join('\n'))
            .replace('{{analysis}}', this.generateAnalysis(strategy))
            .replace('{{strategy}}', this.generateStrategyImplications(strategy))
            .replace('{{hashtags}}', strategy.hashtags.join(' '))];
    }

    private generateAnalysis(strategy: ContentStrategy): string {
        // Generate analysis based on strategy type and target audience
        return `Key implications for ${strategy.targetAudience.join(', ')} investors.`;
    }

    private generateStrategyImplications(strategy: ContentStrategy): string {
        // Generate strategy implications
        return `Consider adjusting your strategy based on these market conditions.`;
    }

    private async handleMarketInsight(message: any): Promise<void> {
        const strategy: ContentStrategy = {
            type: 'thread',
            topic: 'market_update',
            targetAudience: ['defi_investors', 'crypto_enthusiasts'],
            keyPoints: this.formatMarketInsights(message.payload),
            tone: 'professional',
            timing: {
                bestTime: this.calculateOptimalPostingTime(),
                frequency: 'once'
            },
            hashtags: ['#DeFi', '#MarketUpdate', '#Investment'],
            expectedEngagement: 100
        };

        const content = await this.generateContent(strategy);
        this.publishContent(content, strategy);
    }

    private async handleStrategyUpdate(message: any): Promise<void> {
        const strategy: ContentStrategy = {
            type: 'thread',
            topic: 'strategy_insight',
            targetAudience: ['defi_investors'],
            keyPoints: this.formatStrategyUpdate(message.payload),
            tone: 'educational',
            timing: {
                bestTime: this.calculateOptimalPostingTime(),
                frequency: 'once'
            },
            hashtags: ['#DeFiStrategy', '#Investment'],
            expectedEngagement: 150
        };

        const content = await this.generateContent(strategy);
        this.publishContent(content, strategy);
    }

    private async handleCommunityInsight(message: any): Promise<void> {
        const strategy: ContentStrategy = {
            type: 'post',
            topic: 'community_update',
            targetAudience: ['community_members', 'potential_investors'],
            keyPoints: this.formatCommunityUpdate(message.payload),
            tone: 'casual',
            timing: {
                bestTime: this.calculateOptimalPostingTime(),
                frequency: 'once'
            },
            hashtags: ['#DeFiCommunity', '#DAO'],
            expectedEngagement: 80
        };

        const content = await this.generateContent(strategy);
        this.publishContent(content, strategy);
    }

    private formatMarketInsights(insight: any): string[] {
        return [
            `Market Update: ${insight.summary}`,
            `Trend Analysis: ${insight.trend}`,
            `Impact Assessment: ${insight.impact}`,
            `Strategic Recommendations: ${insight.recommendations}`
        ];
    }

    private formatStrategyUpdate(update: any): string[] {
        return [
            `Strategy Performance: ${update.performance}`,
            `Key Metrics: ${update.metrics}`,
            `Risk Assessment: ${update.risk}`,
            `Future Outlook: ${update.outlook}`
        ];
    }

    private formatCommunityUpdate(update: any): string[] {
        return [
            `Community Highlight: ${update.highlight}`,
            `Recent Developments: ${update.developments}`,
            `Upcoming Events: ${update.events}`,
            `Call to Action: ${update.cta}`
        ];
    }

    private calculateOptimalPostingTime(): number {
        // Implement optimal posting time calculation based on audience analytics
        return Date.now() + (2 * 60 * 60 * 1000); // Default: 2 hours from now
    }

    private publishContent(content: string[], strategy: ContentStrategy): void {
        this.messageBroker.publish({
            type: 'content_generated',
            source: 'content_generator',
            target: 'twitter_manager',
            payload: {
                content,
                strategy
            }
        });

        // Store in content history
        const historyKey = `${strategy.topic}-${strategy.type}`;
        const history = this.contentHistory.get(historyKey) || [];
        history.push(strategy);
        this.contentHistory.set(historyKey, history);
    }
}
