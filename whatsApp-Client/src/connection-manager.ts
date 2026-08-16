/**
 * WhatsApp 连接管理器
 *
 * 处理 Noise 协议握手、认证流程、断线重连等核心连接逻辑。
 */

import makeWASocket, {
  type WAConnectionState,
  DisconnectReason,
  fetchLatestBaileysVersion,
} from '@whiskeysockets/baileys';
import type { AuthenticationState } from '@whiskeysockets/baileys/lib/Types/Auth';
import type { ConnectionState } from './wa-adapter';
import { logger as baseLogger } from './logger';
import type { ParsedExport } from './key-parser';

// ─── 类型定义 ────────────────────────────────────────────────

export interface ConnectionResult {
  success: boolean;
  reason?: string;
  qrCode?: string;
  state: ConnectionState;
}

export interface ConnectConfig {
  authState: AuthenticationState;
  parsed: ParsedExport;
  browser?: [string, string, string];
  maxRetries?: number;
  retryDelayMs?: number;
}

// ─── 连接管理器 ──────────────────────────────────────────────

export class ConnectionManager {
  private socket: ReturnType<typeof makeWASocket> | null = null;
  private state: ConnectionState = {
    connected: false,
    lastError: null,
    qrAvailable: false,
  };
  private maxRetries: number;
  private retryDelayMs: number;
  private onMessageHandler?: (jid: string, message: string) => void;
  private stateChangeHandler?: (state: ConnectionState) => void;

  constructor(private config: ConnectConfig) {
    this.maxRetries = config.maxRetries ?? 3;
    this.retryDelayMs = config.retryDelayMs ?? 5000;
  }

  /**
   * 设置消息回调
   */
  onMessage(handler: (jid: string, message: string) => void): void {
    this.onMessageHandler = handler;
  }

  /**
   * 设置状态变化回调
   */
  onStateChanged(handler: (state: ConnectionState) => void): void { this.stateChangeHandler = handler;
  }

  /**
   * 建立连接
   */
  async connect(): Promise<ConnectionResult> {
    baseLogger.info('[ConnectionManager] Starting connection...');

    try {
      // 获取最新协议版本
      const { version } = await fetchLatestBaileysVersion();
      baseLogger.info(`[ConnectionManager] WhatsApp version: ${version.join('.')}`);

      // 创建 socket 连接
      this.socket = makeWASocket({
        auth: this.config.authState,
        browser: this.config.browser ?? ['WhatsApp', 'Android', '17.0'],
        version,
        logger: baseLogger as any,
        connectTimeoutMs: 30000,
        keepAliveIntervalMs: 30000,
        getMessage: async (key) => {
          baseLogger.debug('[ConnectionManager] getMessage called for:', key.id);
          return undefined;
        },
      });

      // 监听连接状态变化
      this.socket.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (connection === 'open') {
          baseLogger.info('[ConnectionManager] ✓ Connected successfully!');
          this.state = { connected: true, lastError: null, qrAvailable: false };
          this.notifyStateChange();

          // 上报凭证更新
          this.socket?.ev.on('creds.update', (creds) => {
            baseLogger.debug('[ConnectionManager] Creds updated:', {
              me: creds.me?.id,
              registered: creds.registered,
            });
          });
        } else if (connection === 'close') {
          const reason = this.getDisconnectReason(lastDisconnect?.error);
          baseLogger.warn(`[ConnectionManager] Connection closed: ${reason}`);
          this.state = {
            connected: false,
            lastError: reason,
            qrAvailable: false,
          };
          this.notifyStateChange();
          await this.handleDisconnect(reason, lastDisconnect);
        } else if (connection === 'connecting') {
          baseLogger.info('[ConnectionManager] Connecting...');
          this.state = { connected: false, lastError: null, qrAvailable: false };
          this.notifyStateChange();
        }

        // QR 配对
        if (qr) {
          baseLogger.warn('[ConnectionManager] QR pairing required');
          this.state.qrAvailable = true;
          this.notifyStateChange();
        }

      });

      // 监听消息
      this.socket.ev.on('messages.upsert', ({ messages }) => {
        for (const msg of messages) {
          if (msg.message?.conversation) {
            const jid = msg.key.remoteJid || 'unknown';
            const content = msg.message.conversation;
            baseLogger.info(`[ConnectionManager] Message from ${jid}: ${content.substring(0, 100)}`);
            this.onMessageHandler?.(jid, content);
          }
        }
      });

      // 监听凭证更新
      this.socket.ev.on('creds.update', (creds) => {
        baseLogger.debug('[ConnectionManager] Creds updated:', {
          me: creds.me?.id,
          registered: creds.registered,
        });
      });

      // 等待连接建立
      await this.waitForConnection(30000);

      return {
        success: this.state.connected,
        state: this.state,
      };
    } catch (error) {
      baseLogger.error('[ConnectionManager] Connection failed:', error);
      this.state.lastError = error instanceof Error ? error.message : 'Unknown error';
      return {
        success: false,
        state: this.state,
      };
    }
  }

  /**
   * 等待连接建立
   */
  private async waitForConnection(timeoutMs: number): Promise<void> {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      if (this.state.connected) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
    throw new Error(`Connection timeout after ${timeoutMs}ms`);
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    if (this.socket) {
      await this.socket.end(undefined);
      this.socket = null;
      this.state.connected = false;
      baseLogger.info('[ConnectionManager] Disconnected');
    }
  }

  /**
   * 发送消息
   */
  async sendMessage(to: string, content: string): Promise<void> {
    if (!this.socket || !this.state.connected) {
      throw new Error('Not connected');
    }

    const jid = to.includes('@') ? to : `${to}@s.whatsapp.net`;

    await this.socket.sendMessage(jid, {
      text: content,
    });

    baseLogger.info(`[ConnectionManager] Message sent to ${jid}`);
  }

  /**
   * 获取当前状态
   */
  getState(): ConnectionState {
    return { ...this.state };
  }

  /**
   * 获取 socket 实例（用于绑定 message manager）
   */
  getSocket(): ReturnType<typeof makeWASocket> | null {
    return this.socket;
  }

  /**
   * 处理断连
   */
  private async handleDisconnect(reason: string, disconnect?: any): Promise<void> {
    // 永久封禁
    if (reason.includes('401') || reason.includes('Unauthorized')) {
      baseLogger.error('[ConnectionManager] Account permanently banned');
      this.state.lastError = 'Account permanently banned';
      return;
    }

    // 临时封禁
    if (reason.includes('403')) {
      baseLogger.warn('[ConnectionManager] Account temporarily banned');
      this.state.lastError = 'Account temporarily banned';
      return;
    }

    // 会话冲突
    if (reason.includes('414') || reason.includes('conflict')) {
      baseLogger.warn('[ConnectionManager] Session conflict - may need re-pairing');
      this.state.lastError = 'Session conflict';
      return;
    }

    // 需要 QR 配对
    if (reason.includes('not-authorized') || reason.includes('pairing')) {
      baseLogger.warn('[ConnectionManager] QR pairing required');
      this.state.qrAvailable = true;
      this.notifyStateChange();
      return;
    }

    // 网络错误 - 尝试重连
    if (this.state.connected === false && reason.includes('timeout')) {
      baseLogger.info('[ConnectionManager] Network timeout, will retry');
      this.state.lastError = reason;
      return;
    }

    // 其他错误 - 尝试重连
    baseLogger.info('[ConnectionManager] Attempting reconnect...');
    await new Promise((resolve) => setTimeout(resolve, this.retryDelayMs));
    try {
      await this.connect();
    } catch (e) {
      baseLogger.error('[ConnectionManager] Reconnect failed:', e);
    }
  }

  /**
   * 获取断连原因
   */
  private getDisconnectReason(error?: any): string {
    if (!error) return 'unknown';

    const boomError = error?.output?.statusCode || error?.code;
    const message = error?.message || error?.error?.message || '';

    // 映射常见原因
    const reasonMap: Record<number, string> = {
      401: 'Unauthorized (可能账号被封禁)',
      403: 'Forbidden (可能账号被临时封禁)',
      414: 'Conflict (会话冲突)',
      440: 'Disconnected (重新登录)',
      500: 'Internal Server Error',
    };

    if (boomError && reasonMap[boomError]) {
      return `${boomError}: ${reasonMap[boomError]}`;
    }

    if (message) {
      return message.substring(0, 100);
    }

    return String(boomError || 'unknown');
  }

  /**
   * 通知状态变化
   */
  private notifyStateChange(): void {
    this.stateChangeHandler?.(this.state);
  }
}

// ─── 便捷函数 ────────────────────────────────────────────────

/**
 * 快速连接并返回结果
 */
export async function quickConnect(config: ConnectConfig): Promise<ConnectionResult> {
  const manager = new ConnectionManager(config);
  return manager.connect();
}

