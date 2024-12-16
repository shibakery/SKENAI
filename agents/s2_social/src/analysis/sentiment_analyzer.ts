import { SocialPost } from '../types';
import { MessageBroker } from '../../../shared/communication/message_broker';
import natural from 'natural';
import { Configuration, OpenAIApi } from 'openai';

export class SentimentAnalyzer {
    private tokenizer: natural.WordTokenizer;
    private messageBroker: MessageBroker;
    private openai: OpenAIApi;
    private aspectLexicon: Map<string, number>;

    constructor(openaiConfig?: Configuration) {
        this.tokenizer = new natural.WordTokenizer();
        this.messageBroker = MessageBroker.getInstance();
        if (openaiConfig) {
            this.openai = new OpenAIApi(openaiConfig);
        }
        this.aspectLexicon = this.initializeAspectLexicon();

        // Subscribe to social posts
        this.messageBroker.subscribe('social_data', this.analyzeSentiment.bind(this));
    }

    private initializeAspectLexicon(): Map<string, number> {
        return new Map([
            ['defi', 1],
            ['investment', 1],
            ['risk', -0.5],
            ['opportunity', 1],
            ['profit', 1],
            ['loss', -1],
            ['scam', -1],
            ['security', 0.5],
            ['innovation', 1],
            ['community', 0.8]
        ]);
    }

    async analyzeSentiment(message: { payload: SocialPost }): Promise<void> {
        const post = message.payload;
        try {
            const sentiment = await this.performSentimentAnalysis(post.content);
            
            // Update post with sentiment analysis
            post.sentiment = sentiment;

            // Publish sentiment analysis results
            this.messageBroker.publish({
                type: 'sentiment_analysis',
                source: 'sentiment_analyzer',
                target: 'all',
                payload: {
                    postId: post.timestamp + '-' + post.author,
                    sentiment,
                    platform: post.platform
                }
            });
        } catch (error) {
            console.error('Sentiment analysis error:', error);
        }
    }

    private async performSentimentAnalysis(content: string): Promise<SocialPost['sentiment']> {
        try {
            if (this.openai) {
                return await this.performAISentimentAnalysis(content);
            } else {
                return this.performLocalSentimentAnalysis(content);
            }
        } catch (error) {
            console.error('Error in sentiment analysis:', error);
            return this.performLocalSentimentAnalysis(content);
        }
    }

    private async performAISentimentAnalysis(content: string): Promise<SocialPost['sentiment']> {
        const response = await this.openai.createCompletion({
            model: "text-davinci-003",
            prompt: `Analyze the sentiment and key aspects of the following text. Consider DeFi and investment-specific context:\n\n${content}`,
            max_tokens: 150,
            temperature: 0.3,
        });

        // Process AI response
        const analysis = response.data.choices[0].text || '';
        
        // Parse AI response and extract sentiment scores
        // This is a simplified implementation
        const sentiment = {
            score: Math.random() * 2 - 1, // Replace with actual AI-derived score
            confidence: 0.85,
            aspects: this.extractAspects(content)
        };

        return sentiment;
    }

    private performLocalSentimentAnalysis(content: string): SocialPost['sentiment'] {
        const tokens = this.tokenizer.tokenize(content.toLowerCase());
        let score = 0;
        let aspectScores: { [key: string]: number } = {};
        let wordCount = 0;

        // Analyze each token
        for (const token of tokens) {
            if (this.aspectLexicon.has(token)) {
                score += this.aspectLexicon.get(token)!;
                wordCount++;
            }
        }

        // Extract aspect-specific sentiment
        for (const [aspect, baseScore] of this.aspectLexicon.entries()) {
            if (content.toLowerCase().includes(aspect)) {
                aspectScores[aspect] = this.calculateAspectScore(content, aspect, baseScore);
            }
        }

        // Normalize score
        const normalizedScore = wordCount > 0 ? score / wordCount : 0;
        const confidence = Math.min(wordCount / 10, 1); // Confidence based on word coverage

        return {
            score: Math.max(-1, Math.min(1, normalizedScore)), // Clamp between -1 and 1
            confidence,
            aspects: aspectScores
        };
    }

    private calculateAspectScore(content: string, aspect: string, baseScore: number): number {
        const context = this.getAspectContext(content, aspect);
        let modifier = 1;

        // Apply context modifiers
        if (context.includes('not') || context.includes("n't")) modifier *= -1;
        if (context.includes('very') || context.includes('highly')) modifier *= 1.5;
        if (context.includes('slightly') || context.includes('somewhat')) modifier *= 0.5;

        return Math.max(-1, Math.min(1, baseScore * modifier));
    }

    private getAspectContext(content: string, aspect: string): string {
        const words = content.toLowerCase().split(' ');
        const aspectIndex = words.indexOf(aspect);
        if (aspectIndex === -1) return '';

        // Get 3 words before and after the aspect
        const start = Math.max(0, aspectIndex - 3);
        const end = Math.min(words.length, aspectIndex + 4);
        return words.slice(start, end).join(' ');
    }

    private extractAspects(content: string): { [key: string]: number } {
        const aspects: { [key: string]: number } = {};
        
        for (const [aspect, baseScore] of this.aspectLexicon.entries()) {
            if (content.toLowerCase().includes(aspect)) {
                aspects[aspect] = this.calculateAspectScore(content, aspect, baseScore);
            }
        }

        return aspects;
    }
}
