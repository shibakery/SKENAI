import { Configuration, OpenAIApi } from 'openai';
import { MessageBroker } from '../../../shared/communication/message_broker';
import { SKENAI_PERSONALITY, SKENAI_STYLE, BRAND_VOICE } from './personality_profile';

interface PostTemplate {
    type: 'announcement' | 'insight' | 'education' | 'engagement';
    structure: string;
    maxLength: number;
}

export class PostGenerator {
    private openai: OpenAIApi;
    private messageBroker: MessageBroker;
    private readonly templates: Map<string, PostTemplate>;

    constructor(apiKey: string) {
        const configuration = new Configuration({ apiKey });
        this.openai = new OpenAIApi(configuration);
        this.messageBroker = MessageBroker.getInstance();
        this.templates = this.initializeTemplates();

        this.messageBroker.subscribe('generate_post', this.handlePostGeneration.bind(this));
    }

    private initializeTemplates(): Map<string, PostTemplate> {
        return new Map([
            ['announcement', {
                type: 'announcement',
                structure: '🚀 [Headline]\n\n[Key Details]\n\n[Call to Action]\n\n#SKENAI #DeFi',
                maxLength: 280
            }],
            ['insight', {
                type: 'insight',
                structure: '📊 [Market Observation]\n\n[Analysis]\n\n[Implication]\n\n#DeFi #Analysis',
                maxLength: 280
            }],
            ['education', {
                type: 'education',
                structure: '💡 [Concept]\n\n[Explanation]\n\n[Example/Use Case]\n\n#DeFi #Learn',
                maxLength: 280
            }],
            ['engagement', {
                type: 'engagement',
                structure: '🤔 [Question/Poll]\n\n[Context]\n\n[Options/Discussion Point]\n\n#DeFi #Community',
                maxLength: 280
            }]
        ]);
    }

    async generatePost(type: string, context: any): Promise<string> {
        const template = this.templates.get(type);
        if (!template) {
            throw new Error(`Unknown post type: ${type}`);
        }

        const prompt = this.createPrompt(template, context);
        
        try {
            const completion = await this.openai.createChatCompletion({
                model: "gpt-4",
                messages: [{
                    role: "system",
                    content: this.createSystemPrompt()
                }, {
                    role: "user",
                    content: prompt
                }],
                temperature: 0.7,
                max_tokens: 150
            });

            const content = completion.data.choices[0].message?.content || '';
            return this.formatPost(content, template);
        } catch (error) {
            console.error('Error generating post:', error);
            throw error;
        }
    }

    private createSystemPrompt(): string {
        const personality = SKENAI_PERSONALITY.map(trait => 
            `${trait.name}: ${trait.tonalPatterns.join(', ')}`
        ).join('\n');

        return `You are SKENAI, ${BRAND_VOICE.mission}. 
Your personality traits:
${personality}

Communication style:
- Formality: ${SKENAI_STYLE.formalityLevel * 100}%
- Technical depth: ${SKENAI_STYLE.technicalDepth * 100}%
- Enthusiasm: ${SKENAI_STYLE.enthusiasm * 100}%
- Innovation focus: ${SKENAI_STYLE.innovativeness * 100}%

Core values:
${BRAND_VOICE.values.join(', ')}

Maintain this personality and style in all communications.`;
    }

    private createPrompt(template: PostTemplate, context: any): string {
        return `Generate a ${template.type} post following this structure:
${template.structure}

Context:
${JSON.stringify(context, null, 2)}

Requirements:
1. Stay within ${template.maxLength} characters
2. Include relevant hashtags
3. Maintain SKENAI's professional but approachable tone
4. Focus on providing value to the DeFi community`;
    }

    private formatPost(content: string, template: PostTemplate): string {
        // Ensure the post fits Twitter's character limit
        if (content.length > template.maxLength) {
            content = content.substring(0, template.maxLength - 3) + '...';
        }

        // Add default hashtags if not present
        if (!content.includes('#SKENAI')) {
            content += '\n#SKENAI';
        }

        return content;
    }

    async schedulePost(content: string, scheduledTime?: Date): Promise<void> {
        this.messageBroker.publish({
            type: 'post_scheduled',
            source: 'post_generator',
            target: 'twitter_manager',
            payload: {
                content,
                scheduledTime: scheduledTime?.toISOString() || new Date().toISOString(),
                type: 'tweet'
            }
        });
    }

    private async handlePostGeneration(message: any): Promise<void> {
        const { type, context, scheduledTime } = message.payload;

        try {
            const content = await this.generatePost(type, context);
            await this.schedulePost(content, scheduledTime ? new Date(scheduledTime) : undefined);

            this.messageBroker.publish({
                type: 'post_generation_complete',
                source: 'post_generator',
                target: message.source,
                payload: {
                    content,
                    type,
                    scheduledTime
                }
            });
        } catch (error) {
            this.messageBroker.publish({
                type: 'post_generation_failed',
                source: 'post_generator',
                target: message.source,
                payload: {
                    error: error.message,
                    type,
                    context
                }
            });
        }
    }
}
