import { MessageBroker } from '../../../shared/communication/message_broker';
import { TwitterManager } from '../twitter/twitter_manager';
import { PostGenerator } from './post_generator';

interface ScheduledPost {
    id: string;
    content: string;
    scheduledTime: Date;
    type: string;
    context: any;
    status: 'pending' | 'published' | 'failed';
}

export class PostScheduler {
    private messageBroker: MessageBroker;
    private twitterManager: TwitterManager;
    private postGenerator: PostGenerator;
    private scheduledPosts: Map<string, ScheduledPost>;
    private readonly postingSchedule: {
        announcements: number[];    // Hours of the day (0-23)
        insights: number[];
        education: number[];
        engagement: number[];
    };

    constructor(
        twitterManager: TwitterManager,
        postGenerator: PostGenerator
    ) {
        this.messageBroker = MessageBroker.getInstance();
        this.twitterManager = twitterManager;
        this.postGenerator = postGenerator;
        this.scheduledPosts = new Map();

        // Define optimal posting times (UTC)
        this.postingSchedule = {
            announcements: [13, 16, 20],        // Peak engagement times
            insights: [8, 12, 15, 19],          // Market analysis times
            education: [9, 14, 18],             // Learning-focused times
            engagement: [10, 15, 17, 21]        // Community interaction times
        };

        // Subscribe to scheduling events
        this.messageBroker.subscribe('schedule_post', this.handleScheduleRequest.bind(this));
        this.messageBroker.subscribe('check_schedule', this.checkSchedule.bind(this));

        // Start the scheduler
        this.initializeScheduler();
    }

    private initializeScheduler(): void {
        // Check schedule every minute
        setInterval(() => this.checkSchedule(), 60000);
    }

    async schedulePost(
        type: string,
        context: any,
        specificTime?: Date
    ): Promise<string> {
        const scheduledTime = specificTime || this.getNextOptimalTime(type);
        const id = `post_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        const post: ScheduledPost = {
            id,
            content: '',  // Will be generated closer to posting time
            scheduledTime,
            type,
            context,
            status: 'pending'
        };

        this.scheduledPosts.set(id, post);

        this.messageBroker.publish({
            type: 'post_scheduled',
            source: 'post_scheduler',
            target: 'all',
            payload: {
                id,
                type,
                scheduledTime: scheduledTime.toISOString()
            }
        });

        return id;
    }

    private getNextOptimalTime(type: string): Date {
        const now = new Date();
        const hours = this.postingSchedule[type as keyof typeof this.postingSchedule];
        
        // Find the next available time slot
        const currentHour = now.getUTCHours();
        const nextHour = hours.find(h => h > currentHour) || hours[0];
        
        const scheduledTime = new Date(now);
        scheduledTime.setUTCHours(nextHour, 0, 0, 0);
        
        // If we wrapped to tomorrow, add a day
        if (nextHour <= currentHour) {
            scheduledTime.setDate(scheduledTime.getDate() + 1);
        }

        return scheduledTime;
    }

    private async checkSchedule(): Promise<void> {
        const now = new Date();

        for (const [id, post] of this.scheduledPosts.entries()) {
            if (post.status === 'pending' && post.scheduledTime <= now) {
                await this.publishPost(id);
            }
        }
    }

    private async publishPost(id: string): Promise<void> {
        const post = this.scheduledPosts.get(id);
        if (!post) return;

        try {
            // Generate content just before posting
            const content = await this.postGenerator.generatePost(post.type, post.context);
            
            // Publish to Twitter
            await this.twitterManager.createPost(content);

            // Update status
            post.status = 'published';
            post.content = content;
            this.scheduledPosts.set(id, post);

            this.messageBroker.publish({
                type: 'post_published',
                source: 'post_scheduler',
                target: 'all',
                payload: {
                    id,
                    content,
                    publishedAt: new Date().toISOString()
                }
            });
        } catch (error) {
            post.status = 'failed';
            this.scheduledPosts.set(id, post);

            this.messageBroker.publish({
                type: 'post_publish_failed',
                source: 'post_scheduler',
                target: 'all',
                payload: {
                    id,
                    error: error.message
                }
            });
        }
    }

    private async handleScheduleRequest(message: any): Promise<void> {
        const { type, context, scheduledTime } = message.payload;

        try {
            const id = await this.schedulePost(
                type,
                context,
                scheduledTime ? new Date(scheduledTime) : undefined
            );

            this.messageBroker.publish({
                type: 'schedule_complete',
                source: 'post_scheduler',
                target: message.source,
                payload: { id }
            });
        } catch (error) {
            this.messageBroker.publish({
                type: 'schedule_failed',
                source: 'post_scheduler',
                target: message.source,
                payload: {
                    error: error.message,
                    type,
                    context
                }
            });
        }
    }

    getScheduledPosts(): ScheduledPost[] {
        return Array.from(this.scheduledPosts.values());
    }

    cancelScheduledPost(id: string): boolean {
        return this.scheduledPosts.delete(id);
    }
}
