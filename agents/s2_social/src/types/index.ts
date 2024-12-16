export interface SocialPost {
    platform: 'twitter' | 'discord' | 'telegram';
    content: string;
    author: string;
    timestamp: number;
    engagement: {
        likes: number;
        replies: number;
        shares: number;
    };
    sentiment?: {
        score: number;  // -1 to 1
        confidence: number;
        aspects: {
            [key: string]: number;
        };
    };
    topics?: string[];
    mentions?: string[];
    hashtags?: string[];
}

export interface EngagementMetrics {
    totalPosts: number;
    totalEngagement: number;
    averageEngagement: number;
    topPosts: SocialPost[];
    sentimentOverTime: {
        timestamp: number;
        sentiment: number;
    }[];
}

export interface CommunityInsight {
    type: 'trend' | 'concern' | 'opportunity';
    description: string;
    confidence: number;
    relatedPosts: SocialPost[];
    timestamp: number;
    action?: string;
}

export interface ContentStrategy {
    type: 'thread' | 'post' | 'reply';
    topic: string;
    targetAudience: string[];
    keyPoints: string[];
    tone: 'educational' | 'casual' | 'professional';
    timing: {
        bestTime: number;
        frequency: 'once' | 'daily' | 'weekly';
    };
    hashtags: string[];
    expectedEngagement: number;
}
