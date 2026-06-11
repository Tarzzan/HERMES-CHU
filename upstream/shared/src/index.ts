export type ConnectionState = 'connecting' | 'connected' | 'disconnected' | 'error'
export interface GatewayEvent { type: string; data?: unknown }
export class JsonRpcGatewayClient {
  constructor(_opts?: Record<string, unknown>) {}
  connect(): void {}
  disconnect(): void {}
  on(_event: string, _handler: (...args: unknown[]) => void): void {}
  off(_event: string, _handler: (...args: unknown[]) => void): void {}
  request<T = unknown>(_method: string, _params?: Record<string, unknown>): Promise<T> { return Promise.resolve(undefined as unknown as T) }
}
