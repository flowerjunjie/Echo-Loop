/**
 * WhatsApp 客户端适配器
 *
 * 整合密钥解析和认证状态构建，提供完整的 WhatsApp 客户端连接能力。
 */

import makeWASocket, { type WAConnectionState } from '@whiskeysockets/baileys';
import type { AuthenticationState } from '@whiskeysockets/baileys/lib/Types/Auth';
import { loadExport, type WhatsAppExportData } from './export-loader';
import { parseWhatsAppExport } from './key-parser';
import { buildAuthenticationState } from './baileys-auth-builder';
import type { ParsedExport } from './key-parser';
import { logger as baseLogger } from './logger';

// ─── 类型定义 ────────────────────────────────────────────────

export interface WAAdapterConfig {
  /** 导出文件路径或数据对象 */
  exportSource: string | WhatsAppExportData;
  /** 浏览器标识 */
  browser?: [string, string, string];
  /** 是否强制重新生成 signedPreKey */
  regenerateSignedPreKey?: boolean;
  /** 连接超时（毫秒） */
  connectTimeoutMs?: number;
  /** 重试次数 */
  maxRetries?: number;
}

export interface ConnectionState {
  connected: boolean;
  lastError: string | null;
  qrAvailable: boolean;
}

// ─── 适配器类 ────────────────────────────────────────────────

export class WAAdapter {
  private socket: ReturnType<typeof makeWASocket> | null = null;
  private parsed: ParsedExport | null = null;
  private authState: AuthenticationState | null = null;
  private state: ConnectionState = {
    connected: false,
    lastError: null,
    qrAvailable: false,
  };
  private reconnectAttempts = 0;
  private maxRetries: number;
  private connectTimeoutMs: number;

  constructor(private config: WAAdapterConfig) {
    this.maxRetries = config.maxRetries ?? 3;
    this.connectTimeoutMs = config.connectTimeoutMs ?? 30000;
  }

  /**
   * 初始化：解析密钥并构建认证状态
   */
  async init(): Promise<ParsedExport> {
    baseLogger.info('[WAAdapter] Initializing...');

    // Step 1: 加载导出数据
    const exportData = await loadExport(this.config.exportSource);
    baseLogger.info(
      `[WAAdapter] Loaded export: account=${exportData.account}, nickname=${exportData.data.nickname}, preKeys=${exportData.data.phoneKeyStore.preKeys.length}`
    );

    // Step 2: 解析密钥
    this.parsed = parseWhatsAppExport(exportData);
    baseLogger.info(
      `[WAAdapter] Parsed keys: regId=${this.parsed.identity.registrationId}, minPreKey=${this.parsed.minPreKeyId}, maxPreKey=${this.parsed.maxPreKeyId}`
    );

    // Step 3: 检查关键缺口
    if (this.parsed.missingServerStatic) {
      baseLogger.warn('[WAAdapter] ⚠️  serverStaticPublic is null - may fail to connect');
    }
    if (this.parsed.missingRoutingInfo) {
      baseLogger.warn('[WAAdapter] ⚠️  routingInfo is null - may have routing issues');
    }

    // Step 4: 构建认证状态
    this.authState = buildAuthenticationState({
      parsed: this.parsed,
      browser: this.config.browser,
      regenerateSignedPreKey: this.config.regenerateSignedPreKey,
    });

    baseLogger.info(
      `[WAAdapter] Auth state built: me=${this.authState.creds.me?.id}, regId=${this.authState.creds.registrationId}`
    );

    return this.parsed;
  }

  /**
   * 连接 WhatsApp 服务器
   */
  async connect(): Promise<void> {
    if (!this.authState) {
      throw new Error('Must call init() before connect()');
    }

    baseLogger.info('[WAAdapter] Connecting to WhatsApp...');

    this.socket = makeWASocket({
      auth: this.authState,
      browser: this.config.browser ?? ['WhatsApp', 'Android', '17.0'],
      version: [2, 3000, 1043857760],
      logger: baseLogger as any,
      connectTimeoutMs: this.connectTimeoutMs,
      keepAliveIntervalMs: 30000,
      // 消息存储（需要实现）
      getMessage: async (key) => {
        baseLogger.debug('[WAAdapter] getMessage called for key:', key.id);
        return undefined;
      },
    });

    // 监听连接状态
    this.socket.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (connection === 'open') {
        baseLogger.info('[WAAdapter] ✓ Connected successfully!');
        this.state = { connected: true, lastError: null, qrAvailable: false };
        this.reconnectAttempts = 0;
      } else if (connection === 'close') {
        const reason = (lastDisconnect?.error as any)?.output?.statusCode;
        const message = (lastDisconnect?.error as any)?.message;
        baseLogger.warn(`[WAAdapter] Connection closed: reason=${reason}, message=${message}`);
        this.state = {
          connected: false,
          lastError: `reason=${reason}, message=${message}`,
          qrAvailable: false,
        };
        this.handleDisconnect(reason);
      } else if (connection === 'connecting') {
        baseLogger.info('[WAAdapter] Connecting...');
        this.state = { connected: false, lastError: null, qrAvailable: false };
      }

      // QR 配对提示
      if (qr) {
        baseLogger.warn('[WAAdapter] QR pairing required - server rejected identity keys');
        this.state.qrAvailable = true;
      }
    });

    // 监听凭证更新
    this.socket.ev.on('creds.update', (creds) => {
      baseLogger.debug('[WAAdapter] Creds updated:', {
        me: creds.me?.id,
        registered: creds.registered,
        pairingCode: creds.pairingCode,
      });
    });

    // 监听消息
    this.socket.ev.on('messages.upsert', ({ messages }) => {
      for (const msg of messages) {
        baseLogger.debug('[WAAdapter] Received message:', {
          id: msg.key.id,
          from: msg.key.remoteJid,
          hasMessage: !!msg.message,
        });
      }
    });
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    if (this.socket) {
      await this.socket.end(undefined);
      this.socket = null;
      this.state.connected = false;
      baseLogger.info('[WAAdapter] Disconnected');
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

    baseLogger.info(`[WAAdapter] Message sent to ${jid}`);
  }

  /**
   * 获取当前连接状态
   */
  getState(): ConnectionState {
    return { ...this.state };
  }

  /**
   * 获取解析后的密钥数据
   */
  getParsed(): ParsedExport | null {
    return this.parsed;
  }

  /**
   * 处理断连
   */
  private async handleDisconnect(reason: number | undefined): Promise<void> {
    // 临时封禁
    if (reason === 403) {
      baseLogger.error('[WAAdapter] Account temporarily banned (403)');
      this.state.lastError = 'Account temporarily banned';
      return;
    }

    // 永久封禁
    if (reason === 401) {
      baseLogger.error('[WAAdapter] Account permanently banned (401)');
      this.state.lastError = 'Account permanently banned';
      return;
    }

    // 需要重新配对
    if (reason === 414) {
      baseLogger.warn('[WAAdapter] Session conflict - may need re-pairing');
      this.state.lastError = 'Session conflict';
      return;
    }

    // 网络错误 - 尝试重连
    if (this.reconnectAttempts < this.maxRetries) {
      this.reconnectAttempts++;
      const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
      baseLogger.info(`[WAAdapter] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
      await new Promise((r) => setTimeout(r, delay));
      try {
        await this.connect();
      } catch (e) {
        baseLogger.error('[WAAdapter] Reconnect failed:', e);
      }
    } else {
      baseLogger.error('[WAAdapter] Max retries exceeded');
      this.state.lastError = 'Max reconnect retries exceeded';
    }
  }
}

// ─── 便捷函数 ────────────────────────────────────────────────

/**
 * 创建并连接 WhatsApp 客户端
 */
export async function createWAAdapter(config: WAAdapterConfig): Promise<WAAdapter> {
  const adapter = new WAAdapter(config);
  await adapter.init();
  await adapter.connect();
  return adapter;
}
