export interface TwitterConfig {
    apiKey: string;
    apiKeySecret: string;
    accessToken: string;
    accessTokenSecret: string;
    bearerToken: string;
}

// These values should be loaded from environment variables
export const twitterConfig: TwitterConfig = {
    apiKey: process.env.TWITTER_API_KEY || '',
    apiKeySecret: process.env.TWITTER_API_KEY_SECRET || '',
    accessToken: process.env.TWITTER_ACCESS_TOKEN || '',
    accessTokenSecret: process.env.TWITTER_ACCESS_TOKEN_SECRET || '',
    bearerToken: process.env.TWITTER_BEARER_TOKEN || ''
};
