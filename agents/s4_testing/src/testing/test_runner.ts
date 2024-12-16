import { EventEmitter } from 'events';
import { ethers } from 'ethers';
import { MessageBroker } from '../../../shared/communication/message_broker';

interface TestCase {
    name: string;
    type: 'unit' | 'integration' | 'strategy';
    setup: () => Promise<void>;
    execute: () => Promise<void>;
    verify: () => Promise<void>;
    cleanup: () => Promise<void>;
}

interface TestResult {
    name: string;
    type: string;
    status: 'passed' | 'failed' | 'skipped';
    duration: number;
    error?: Error;
    gasUsed?: number;
}

export class TestRunner extends EventEmitter {
    private messageBroker: MessageBroker;
    private provider: ethers.providers.Provider;
    private testCases: Map<string, TestCase>;
    private results: TestResult[];

    constructor(providerUrl: string) {
        super();
        this.messageBroker = MessageBroker.getInstance();
        this.provider = new ethers.providers.JsonRpcProvider(providerUrl);
        this.testCases = new Map();
        this.results = [];

        // Subscribe to test requests
        this.messageBroker.subscribe('test_request', this.handleTestRequest.bind(this));
    }

    registerTest(testCase: TestCase): void {
        this.testCases.set(testCase.name, testCase);
    }

    async runTest(testName: string): Promise<TestResult> {
        const testCase = this.testCases.get(testName);
        if (!testCase) {
            throw new Error(`Test case not found: ${testName}`);
        }

        const startTime = Date.now();
        let result: TestResult = {
            name: testName,
            type: testCase.type,
            status: 'failed',
            duration: 0
        };

        try {
            // Setup test environment
            await testCase.setup();

            // Execute test
            await testCase.execute();

            // Verify results
            await testCase.verify();

            result.status = 'passed';
        } catch (error) {
            result.error = error as Error;
        } finally {
            // Cleanup
            try {
                await testCase.cleanup();
            } catch (cleanupError) {
                console.error('Cleanup error:', cleanupError);
            }
        }

        result.duration = Date.now() - startTime;
        this.results.push(result);

        this.emitTestResult(result);
        return result;
    }

    async runAllTests(): Promise<TestResult[]> {
        this.results = [];
        
        for (const [testName] of this.testCases) {
            await this.runTest(testName);
        }

        this.emitTestSummary();
        return this.results;
    }

    async runTestSuite(type: TestCase['type']): Promise<TestResult[]> {
        const suiteResults: TestResult[] = [];
        
        for (const [testName, testCase] of this.testCases) {
            if (testCase.type === type) {
                const result = await this.runTest(testName);
                suiteResults.push(result);
            }
        }

        return suiteResults;
    }

    private async handleTestRequest(message: any): Promise<void> {
        const { testName, type } = message.payload;

        try {
            let results: TestResult[];

            if (testName) {
                results = [await this.runTest(testName)];
            } else if (type) {
                results = await this.runTestSuite(type);
            } else {
                results = await this.runAllTests();
            }

            this.messageBroker.publish({
                type: 'test_complete',
                source: 'test_runner',
                target: message.source,
                payload: {
                    results,
                    summary: this.generateTestSummary(results)
                }
            });
        } catch (error) {
            this.messageBroker.publish({
                type: 'test_failed',
                source: 'test_runner',
                target: message.source,
                payload: {
                    error: error.message
                }
            });
        }
    }

    private emitTestResult(result: TestResult): void {
        this.messageBroker.publish({
            type: 'test_result',
            source: 'test_runner',
            target: 'all',
            payload: result
        });
    }

    private emitTestSummary(): void {
        const summary = this.generateTestSummary(this.results);
        
        this.messageBroker.publish({
            type: 'test_summary',
            source: 'test_runner',
            target: 'all',
            payload: summary
        });
    }

    private generateTestSummary(results: TestResult[]): any {
        const total = results.length;
        const passed = results.filter(r => r.status === 'passed').length;
        const failed = results.filter(r => r.status === 'failed').length;
        const skipped = results.filter(r => r.status === 'skipped').length;
        const totalDuration = results.reduce((sum, r) => sum + r.duration, 0);

        return {
            total,
            passed,
            failed,
            skipped,
            duration: totalDuration,
            failedTests: results
                .filter(r => r.status === 'failed')
                .map(r => ({
                    name: r.name,
                    error: r.error?.message
                }))
        };
    }

    getTestResults(): TestResult[] {
        return [...this.results];
    }

    clearResults(): void {
        this.results = [];
    }
}
