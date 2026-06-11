import { EventEmitter } from 'events'

export type ConnectionState = 'connecting' | 'connected' | 'disconnected' | 'error'

export enum GatewayEventType {
  MESSAGE = 'message',
  NOTIFICATION = 'notification',
  ERROR = 'error',
  STATE_CHANGE = 'state_change',
}

export interface GatewayEvent {
  type: GatewayEventType
  payload: unknown
  timestamp?: number
}

export interface GatewayClientOptions {
  url?: string
  reconnect?: boolean
  reconnectInterval?: number
  maxReconnectAttempts?: number
}

export class JsonRpcGatewayClient extends EventEmitter {
  public state: ConnectionState = 'disconnected'
  protected options: GatewayClientOptions

  constructor(options?: GatewayClientOptions) {
    super()
    this.options = options || {}
  }

  async connect(): Promise<void> {
    this.state = 'connected'
    this.emit('state_change', this.state)
  }

  async disconnect(): Promise<void> {
    this.state = 'disconnected'
    this.emit('state_change', this.state)
  }

  async request<T = unknown>(method: string, params?: unknown): Promise<T> {
    return {} as T
  }

  async notify(method: string, params?: unknown): Promise<void> {}

  onEvent(handler: (event: GatewayEvent) => void): () => void {
    this.on('event', handler)
    return () => this.off('event', handler)
  }
}
