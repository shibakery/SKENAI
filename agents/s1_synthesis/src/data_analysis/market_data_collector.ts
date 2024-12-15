import axios from 'axios';
import { EventEmitter } from 'events';

export class MarketDataCollector extends EventEmitter {
    private apiKey: string;
    private baseUrl: string;

    constructor(apiKey: string, baseUrl: string = 'https://api.everstrike.io/v1') {
        super();
        this.apiKey = apiKey;
        this.baseUrl = baseUrl;
    }

    async fetchLiquidityPoolData(poolAddress: string): Promise<any> {
        try {
            const response = await axios.get(`${this.baseUrl}/pools/${poolAddress}`, {
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`
                }
            });
            this.emit('data_collected', response.data);
            return response.data;
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }

    async analyzeTradingVolume(poolAddress: string, timeframe: string): Promise<any> {
        try {
            const response = await axios.get(`${this.baseUrl}/analytics/volume`, {
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`
                },
                params: {
                    pool: poolAddress,
                    timeframe
                }
            });
            return response.data;
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }

    async getMarketMetrics(): Promise<any> {
        try {
            const response = await axios.get(`${this.baseUrl}/metrics/market`, {
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`
                }
            });
            return response.data;
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }
}
