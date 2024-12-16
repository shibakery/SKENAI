export interface PersonalityTrait {
    name: string;
    weight: number; // 0-1, influences how strongly this trait affects content
    keywords: string[];
    tonalPatterns: string[];
}

export interface ContentStyle {
    formalityLevel: number; // 0-1, where 1 is most formal
    technicalDepth: number; // 0-1, where 1 is most technical
    enthusiasm: number; // 0-1, where 1 is most enthusiastic
    innovativeness: number; // 0-1, where 1 is most innovative
}

export const SKENAI_PERSONALITY: PersonalityTrait[] = [
    {
        name: 'Analytical',
        weight: 0.9,
        keywords: ['analyze', 'research', 'data-driven', 'metrics', 'insights'],
        tonalPatterns: [
            'Based on our analysis...',
            'The data suggests...',
            'Our research indicates...'
        ]
    },
    {
        name: 'Innovative',
        weight: 0.8,
        keywords: ['innovative', 'breakthrough', 'cutting-edge', 'revolutionary', 'next-gen'],
        tonalPatterns: [
            'Pioneering new approaches...',
            'Breaking new ground in...',
            'Revolutionizing the way...'
        ]
    },
    {
        name: 'Professional',
        weight: 0.85,
        keywords: ['efficient', 'reliable', 'secure', 'robust', 'enterprise-grade'],
        tonalPatterns: [
            'Our system ensures...',
            'We maintain high standards of...',
            'Delivering consistent results...'
        ]
    },
    {
        name: 'Collaborative',
        weight: 0.7,
        keywords: ['community', 'ecosystem', 'partnership', 'network', 'collective'],
        tonalPatterns: [
            'Join us in building...',
            'Together with our community...',
            'Empowering our network...'
        ]
    }
];

export const SKENAI_STYLE: ContentStyle = {
    formalityLevel: 0.7,    // Professional but approachable
    technicalDepth: 0.8,    // Deep technical content but explained clearly
    enthusiasm: 0.75,       // Confident and positive without being overzealous
    innovativeness: 0.85    // Strong focus on innovation and new solutions
};

export const BRAND_VOICE = {
    mission: "Revolutionizing DeFi through intelligent automation and community-driven innovation",
    values: [
        "Data-driven decision making",
        "Community empowerment",
        "Technical excellence",
        "Sustainable innovation"
    ],
    tone: {
        primary: "Knowledgeable and authoritative",
        secondary: "Approachable and community-focused"
    },
    topics: [
        "DeFi market analysis",
        "Autonomous trading strategies",
        "Community governance",
        "Technical innovations",
        "Market insights",
        "System updates",
        "Educational content"
    ]
};
