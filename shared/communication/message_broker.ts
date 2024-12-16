import { EventEmitter } from 'events';

export interface Message {
    type: string;
    source: string;
    target: string;
    payload: any;
    timestamp: number;
    id: string;
}

export class MessageBroker extends EventEmitter {
    private static instance: MessageBroker;
    private subscribers: Map<string, Set<(message: Message) => void>>;
    private messageLog: Message[];

    private constructor() {
        super();
        this.subscribers = new Map();
        this.messageLog = [];
    }

    static getInstance(): MessageBroker {
        if (!MessageBroker.instance) {
            MessageBroker.instance = new MessageBroker();
        }
        return MessageBroker.instance;
    }

    publish(message: Omit<Message, 'id' | 'timestamp'>): void {
        const fullMessage: Message = {
            ...message,
            id: this.generateMessageId(),
            timestamp: Date.now()
        };

        this.messageLog.push(fullMessage);
        this.emit('message', fullMessage);

        const subscribers = this.subscribers.get(message.type) || new Set();
        subscribers.forEach(callback => callback(fullMessage));

        // Cleanup old messages
        this.cleanupOldMessages();
    }

    subscribe(type: string, callback: (message: Message) => void): () => void {
        if (!this.subscribers.has(type)) {
            this.subscribers.set(type, new Set());
        }

        this.subscribers.get(type)!.add(callback);

        // Return unsubscribe function
        return () => {
            this.subscribers.get(type)?.delete(callback);
            if (this.subscribers.get(type)?.size === 0) {
                this.subscribers.delete(type);
            }
        };
    }

    getMessageHistory(type?: string, since?: number): Message[] {
        let messages = this.messageLog;
        
        if (type) {
            messages = messages.filter(m => m.type === type);
        }
        
        if (since) {
            messages = messages.filter(m => m.timestamp >= since);
        }

        return messages;
    }

    private generateMessageId(): string {
        return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    }

    private cleanupOldMessages(): void {
        const cutoff = Date.now() - (24 * 60 * 60 * 1000); // Keep 24 hours of messages
        this.messageLog = this.messageLog.filter(m => m.timestamp >= cutoff);
    }
}
