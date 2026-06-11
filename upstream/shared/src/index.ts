/**
 * @hermes/shared — Stub pour PULSAR CHU Desktop
 * Remplace le package interne du monorepo NousResearch/hermes-desktop (privé).
 * Contient les types et classes minimaux requis par hermes-desktop v0.15.1.
 */

// ── Types de connexion ─────────────────────────────────────────────────────

export type ConnectionState = 'open' | 'closed' | 'connecting' | 'reconnecting' | 'error'

export interface GatewayEvent<T = unknown> {
  type: string
  payload?: T
  session_id?: string
}

// ── Options du constructeur ────────────────────────────────────────────────

export interface JsonRpcGatewayClientOptions {
  closedErrorMessage?: string
  connectErrorMessage?: string
  notConnectedErrorMessage?: string
  requestTimeoutMs?: number
  createRequestId?: (nextId: number) => number | string
}

// ── Classe de base JsonRpcGatewayClient ───────────────────────────────────

type StateListener = (state: ConnectionState) => void
type EventListener<T = unknown> = (event: GatewayEvent<T>) => void
type Unsubscribe = () => void

export abstract class JsonRpcGatewayClient {
  private _connectionState: ConnectionState = 'closed'
  private _stateListeners: Set<StateListener> = new Set()
  private _eventListeners: Set<EventListener> = new Set()
  private _ws: WebSocket | null = null
  private _requestCounter = 0
  private _pendingRequests: Map<
    number | string,
    { resolve: (value: unknown) => void; reject: (reason: unknown) => void; timer: ReturnType<typeof setTimeout> }
  > = new Map()
  protected readonly options: JsonRpcGatewayClientOptions

  constructor(options: JsonRpcGatewayClientOptions = {}) {
    this.options = options
  }

  get connectionState(): ConnectionState {
    return this._connectionState
  }

  private _setState(state: ConnectionState): void {
    this._connectionState = state
    this._stateListeners.forEach(fn => fn(state))
  }

  onState(listener: StateListener): Unsubscribe {
    this._stateListeners.add(listener)
    return () => this._stateListeners.delete(listener)
  }

  onEvent<T = unknown>(listener: EventListener<T>): Unsubscribe {
    this._eventListeners.add(listener as EventListener)
    return () => this._eventListeners.delete(listener as EventListener)
  }

  async connect(url: string): Promise<void> {
    if (this._ws) {
      this._ws.close()
      this._ws = null
    }
    this._setState('connecting')
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url)
      this._ws = ws

      ws.onopen = () => {
        this._setState('open')
        resolve()
      }

      ws.onerror = () => {
        this._setState('closed')
        reject(new Error(this.options.connectErrorMessage ?? 'Could not connect to gateway'))
      }

      ws.onclose = () => {
        this._setState('closed')
      }

      ws.onmessage = (evt: MessageEvent) => {
        try {
          const data = JSON.parse(evt.data as string)
          // JSON-RPC response
          if (data.id !== undefined && (data.result !== undefined || data.error !== undefined)) {
            const pending = this._pendingRequests.get(data.id)
            if (pending) {
              clearTimeout(pending.timer)
              this._pendingRequests.delete(data.id)
              if (data.error) {
                pending.reject(new Error(data.error.message ?? 'RPC error'))
              } else {
                pending.resolve(data.result)
              }
            }
          } else if (data.method || data.type) {
            // Gateway event
            const event: GatewayEvent = {
              type: data.method ?? data.type ?? 'unknown',
              payload: data.params ?? data.payload,
              session_id: data.session_id
            }
            this._eventListeners.forEach(fn => fn(event))
          }
        } catch {
          // ignore parse errors
        }
      }
    })
  }

  close(): void {
    if (this._ws) {
      this._ws.close()
      this._ws = null
    }
    this._setState('closed')
    // Reject all pending requests
    this._pendingRequests.forEach(({ reject, timer }) => {
      clearTimeout(timer)
      reject(new Error(this.options.closedErrorMessage ?? 'Gateway connection closed'))
    })
    this._pendingRequests.clear()
  }

  async request<T = unknown>(method: string, params?: unknown, timeoutMs?: number): Promise<T> {
    return this._request<T>(method, params, timeoutMs)
  }

  protected async _request<T = unknown>(method: string, params?: unknown, timeoutMs?: number): Promise<T> {
    if (this._connectionState !== 'open' || !this._ws) {
      throw new Error(this.options.notConnectedErrorMessage ?? 'Gateway is not connected')
    }
    const id = this.options.createRequestId
      ? this.options.createRequestId(++this._requestCounter)
      : ++this._requestCounter
    const timeout = timeoutMs ?? this.options.requestTimeoutMs ?? 30_000

    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this._pendingRequests.delete(id)
        reject(new Error(`Request timeout: ${method}`))
      }, timeout)

      this._pendingRequests.set(id, {
        resolve: resolve as (value: unknown) => void,
        reject,
        timer
      })

      this._ws!.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }))
    })
  }
}
