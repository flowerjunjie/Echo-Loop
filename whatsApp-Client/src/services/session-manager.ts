/**
 * 会话管理器 — 核心连接编排
 *
 * 管理所有 WhatsApp 账户的 WebSocket 会话，支持：
 * - 并发连接/断连
 * - 消息路由和翻译
 * - 断线重连
 * - 设备伪装配置注入
 */

// @ts-nocheck
import makeWASocket, { fetchLatestBaileysVersion, DisconnectReason } from '@whiskeysockets/baileys';
import type { WASocket } from '@whiskeysockets/baileys';
import type { AuthenticationState } from '@whiskeysockets/baileys/lib/Types/Auth';
import { useMultiFileAuthState } from '@whiskeysockets/baileys/lib/Utils/use-multi-file-auth-state';
import * as path from 'path';
import * as fs from 'fs';
import type { WhatsAppAccount, ChatMessage, BatchSendMessageParam } from '../types';
import type { DeviceConfig } from '../types';
import { logger } from '../logger';
import { storeMessages, translateText } from './chat-history';
import { getTranslationConfig } from './translation';
import { buildConnectionConfig } from './device-spoof';
import { updateAccountStatus, updateAccountConnection, addMessageToAccount } from '../db';

export interface SessionConfig {
  authState?: AuthenticationState;
  phoneNumber?: string; // 配对码登录：提供手机号
  deviceConfig?: DeviceConfig;
  proxyUrl?: string;
  testMode?: boolean; // 测试模式：不连接WhatsApp，模拟成功
}

export interface SessionEventHandlers {
  onMessage?: (msg: ChatMessage) => void;
  onStatusChange?: (accountId: string, status: WhatsAppAccount['status'], error?: string) => void;
  onPairingCode?: (accountId: string, code: string) => void;
}

export interface WSBroadcast {
  (event: string, payload: any): void;
}

export class SessionManager {
  private sessions: Map<string, WASession> = new Map();
  private eventHandlers: SessionEventHandlers = {};
  private wsBroadcast?: WSBroadcast;

  setWSBroadcast(fn: WSBroadcast): void {
    this.wsBroadcast = fn;
  }

  setHandlers(handlers: SessionEventHandlers): void {
    this.eventHandlers = handlers;
  }

  async connect(account: WhatsAppAccount, config: SessionConfig): Promise<void> {
    const { getAntiDetectConfig } = require('./device-spoof');
    const cfg = getAntiDetectConfig();
    if (this.sessions.size >= cfg.maxTotalConnections) {
      throw new Error(`达到最大并发连接数限制: ${cfg.maxTotalConnections}`);
    }
    if (this.sessions.has(account.id)) {
      await this.sessions.get(account.id)!.disconnect();
    }

    const session = new WASession(account, config);
    this.sessions.set(account.id, session);

    updateAccountStatus(account.id, 'connecting');

    session.onStatusChange = (status, error) => {
      updateAccountStatus(account.id, status, error);
      this.eventHandlers.onStatusChange?.(account.id, status, error);
    };

    session.onMessage = (msg) => {
      this.handleMessage(msg);
    };

    await session.connect();
  }

  async disconnect(accountId: string): Promise<void> {
    const session = this.sessions.get(accountId);
    if (session) {
      await session.disconnect();
      this.sessions.delete(accountId);
      updateAccountStatus(accountId, 'disconnected');
    }
  }

  async sendMessage(accountId: string, to: string, content: string): Promise<string> {
    const session = this.sessions.get(accountId);
    if (!session) throw new Error(`Account ${accountId} not connected`);
    return session.sendMessage(to, content);
  }

  async batchSend(accountId: string, param: BatchSendMessageParam): Promise<{ success: number; failed: number }> {
    const session = this.sessions.get(accountId);
    if (!session) throw new Error(`Account ${accountId} not connected`);
    return session.batchSend(param);
  }

  /**
   * 并发连接多个账户
   */
  async connectBatch(accounts: Array<{ account: WhatsAppAccount; config: SessionConfig }>, concurrent = 5): Promise<void> {
    for (let i = 0; i < accounts.length; i += concurrent) {
      const batch = accounts.slice(i, i + concurrent);
      await Promise.all(batch.map(async ({ account, config }) => {
        try {
          await this.connect(account, config);
        } catch (err) {
          logger.error(`[SessionManager] Failed to connect ${account.id}:`, err);
        }
      }));
    }
  }

  getSessions(): { accountId: string; connected: boolean; error?: string }[] {
    return Array.from(this.sessions.values()).map(s => ({
      accountId: s.accountId,
      connected: s.isConnected,
      error: s.lastError,
    }));
  }

  getPairingSession(accountId: string): { pairingCode: string | undefined; phoneNumber: string } | null {
    const session = this.sessions.get(accountId);
    if (!session || !session.phoneNumber) return null;
    return {
      pairingCode: session.pairingCode,
      phoneNumber: session.phoneNumber,
    };
  }

  getSession(accountId: string): any {
    return this.sessions.get(accountId) || null;
  }

  /** 消息处理：翻译 + 存储 */
  private handleMessage(msg: ChatMessage): void {
    const tConfig = getTranslationConfig();
    if (tConfig.enabled) {
      translateText(msg.body).then(translated => {
        if (translated !== msg.body) {
          msg.translatedBody = translated;
          msg.translationSource = 'auto';
          msg.translationTargetLang = tConfig.targetLang;
        }
      }).catch(() => {});
    }
    storeMessages([msg]);
    addMessageToAccount(msg.accountId, 1);
    this.eventHandlers.onMessage?.(msg);
  }
}

class WASession {
  socket: WASocket | null = null;
  accountId: string;
  isConnected = false;
  lastError: string | null = null;
  onStatusChange?: (status: WhatsAppAccount['status'], error?: string) => void;
  onMessage?: (msg: ChatMessage) => void;
  private authState: AuthenticationState | undefined;
  private phoneNumber?: string;
  public pairingCode?: string; // 公开供外部查询
  private deviceConfig?: DeviceConfig;
  private proxyUrl?: string;
  private testMode = false;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;

  constructor(account: WhatsAppAccount, config: SessionConfig) {
    this.accountId = account.id;
    this.authState = config.authState;
    this.phoneNumber = config.phoneNumber;
    this.deviceConfig = config.deviceConfig;
    this.proxyUrl = config.proxyUrl;
    this.testMode = config.testMode || false;
  }

  /** 配对码登录模式 */
  private async connectWithPairingCode(): Promise<void> {
    if (!this.phoneNumber) {
      throw new Error('phoneNumber is required for pairing code login');
    }

    // 创建认证状态存储目录
    const authDir = path.join(process.cwd(), 'auth_data', this.accountId);
    if (!fs.existsSync(authDir)) fs.mkdirSync(authDir, { recursive: true });

    logger.info(`[Session ${this.accountId}] Starting pairing code login for ${this.phoneNumber}`);

    const { version } = await fetchLatestBaileysVersion();
    const authState = await useMultiFileAuthState(authDir);

    // 确保凭证已初始化
    if (!authState.state.creds.me) {
      const cleanPhone = this.phoneNumber.replace(/^\+?86/, '');
      authState.state.creds.me = {
        id: `${cleanPhone}@s.whatsapp.net`,
        name: 'Pairing',
        verifiedName: '',
      };
      authState.state.creds.registered = false;
      await authState.saveCreds();
    }

    // 配对码模式代理支持
    if (this.proxyUrl) {
      const proto = this.proxyUrl.split('://')[0] || 'http';
      if (proto === 'socks5' || proto === 'socks4') {
        (this.socket as any) = makeWASocket({
          auth: authState.state,
          browser: ['WhatsApp', 'Android', '17.0'] as any,
          version,
          connectTimeoutMs: 30000,
          keepAliveIntervalMs: 30000,
          getMessage: async () => undefined,
          agent: new (await import('socks-proxy-agent')).SocksProxyAgent(this.proxyUrl),
        });
      } else {
        (this.socket as any) = makeWASocket({
          auth: authState.state,
          browser: ['WhatsApp', 'Android', '17.0'] as any,
          version,
          connectTimeoutMs: 30000,
          keepAliveIntervalMs: 30000,
          getMessage: async () => undefined,
          agent: new (await import('http-proxy-agent')).HttpProxyAgent(this.proxyUrl),
        });
      }
    } else {
      this.socket = makeWASocket({
        auth: authState.state,
        browser: ['WhatsApp', 'Android', '17.0'] as any,
        version,
        connectTimeoutMs: 30000,
        keepAliveIntervalMs: 30000,
        getMessage: async () => undefined,
      });
    }

    // 监听配对成功事件（isNewLogin 表示配对成功，需要重新连接）
    const isNewLoginPromise = new Promise<void>((resolve) => {
      this.socket!.ev.on('connection.update', (update) => {
        if (update.isNewLogin) {
          logger.info(`[Session ${this.accountId}] Pairing successful, waiting for reconnection...`);
          resolve();
        }
      });
    });

    this.setupListeners();

    // 请求配对码
    try {
      const pairingCode = await this.socket.requestPairingCode(this.phoneNumber);
      logger.info(`[Session ${this.accountId}] Pairing code generated: ${pairingCode}`);
      logger.info(`[Session ${this.accountId}] Session pairingCode field set to: ${this.pairingCode}`);
      this.pairingCode = pairingCode; // 保存配对码供查询

      // 通知上层配对码已生成
      this.eventHandlers.onPairingCode?.(this.accountId, pairingCode);

      // 广播配对码事件
      this.wsBroadcast?.('pairing_code', { accountId: this.accountId, code: pairingCode });
    } catch (err) {
      logger.error(`[Session ${this.accountId}] Failed to get pairing code:`, err);
      this.lastError = err instanceof Error ? err.message : 'Failed to get pairing code';
      this.onStatusChange?.('error', this.lastError);
      return;
    }

    // 等待配对成功
    await isNewLoginPromise;
    logger.info(`[Session ${this.accountId}] Pairing completed, waiting for connection...`);
    // 注意：Baileys 会在配对成功后自动重新连接，我们不需要手动 reconnect
    // 连接状态会由 connection.update 事件的 'open' 分支处理
  }

  async connect(): Promise<void> {
    // Test mode: simulate successful connection without actual WhatsApp connection
    if (this.testMode) {
      logger.info(`[Session ${this.accountId}] Test mode: simulating connection`);
      this.isConnected = true;
      this.lastError = null;
      this.reconnectAttempts = 0;
      this.onStatusChange?.('connected');
      return;
    }

    // 配对码登录模式
    if (this.phoneNumber && !this.authState) {
      await this.connectWithPairingCode();
      return;
    }

    const { version } = await fetchLatestBaileysVersion();
    const connConfig: any = {
      auth: this.authState,
      browser: this.deviceConfig?.browser ?? ['WhatsApp', 'Android', '17.0'],
      version,
      connectTimeoutMs: 30000,
      keepAliveIntervalMs: 30000,
      getMessage: async () => undefined,
    };

    // Proxy support - auto-detect protocol
    if (this.proxyUrl) {
      const proto = this.proxyUrl.split('://')[0] || 'http';
      try {
        if (proto === 'socks5' || proto === 'socks4') {
          const { SocksProxyAgent } = await import('socks-proxy-agent');
          connConfig.agent = new SocksProxyAgent(this.proxyUrl);
        } else {
          const { HttpProxyAgent } = await import('http-proxy-agent');
          connConfig.agent = new HttpProxyAgent(this.proxyUrl);
        }
      } catch (e) {
        logger.warn(`[Session ${this.accountId}] Proxy agent error: ${e.message}`);
      }
    }

    this.socket = makeWASocket(connConfig);
    this.setupListeners();
  }

  private setupListeners(): void {
    if (!this.socket) return;

    this.socket.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (connection === 'open') {
        this.isConnected = true;
        this.lastError = null;
        this.reconnectAttempts = 0;
        logger.info(`[Session ${this.accountId}] Connected`);
        this.onStatusChange?.('connected');
      this.wsBroadcast?.('account_status_change', { accountId: this.accountId, status: 'connected' });
        updateAccountConnection(this.accountId, `session-${this.accountId}`);
        return;
      }

      if (connection === 'close') {
        this.isConnected = false;
        const reason = this.parseDisconnectReason(lastDisconnect?.error);
        this.lastError = reason;
        logger.warn(`[Session ${this.accountId}] Disconnected: ${reason}`);
        this.onStatusChange?.('disconnected', reason);
      this.wsBroadcast?.('account_status_change', { accountId: this.accountId, status: 'disconnected', error: reason });
        updateAccountStatus(this.accountId, 'disconnected', reason);

        // Auto reconnect with backoff
        if (this.shouldReconnect(reason)) {
          this.reconnectAttempts++;
          const delay = Math.min(2000 * Math.pow(2, this.reconnectAttempts), 60000);
          logger.info(`[Session ${this.accountId}] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
          this.reconnectTimer = setTimeout(() => this.connect(), delay);
        } else {
          logger.error(`[Session ${this.accountId}] Will not reconnect: ${reason}`);
          if (reason.includes('401') || reason.includes('banned')) {
            updateAccountStatus(this.accountId, 'banned', reason);
            this.onStatusChange?.('banned', reason);
          }
        }
        return;
      }

      if (connection === 'connecting') {
        this.onStatusChange?.('connecting');
      }

      if (qr) {
        logger.warn(`[Session ${this.accountId}] QR pairing required`);
        this.onStatusChange?.('error', 'QR pairing required');
      }
    });

    this.socket.ev.on('creds.update', (creds) => {
      logger.debug(`[Session ${this.accountId}] Creds updated: me=${creds.me?.id}`);
    });

    // 监听联系人更新
    this.socket.ev.on('contacts.upsert', (contacts: any[]) => {
      for (const contact of contacts) {
        logger.debug(`[Session ${this.accountId}] Contact: ${contact.id} = ${contact.notify || contact.name || ''}`);
      }
      // 广播联系人事件
      this.wsBroadcast?.('contacts_update', { accountId: this.accountId, contacts });
    });

    this.socket.ev.on('chats.upsert', (chats: any[]) => {
      for (const chat of chats) {
        logger.debug(`[Session ${this.accountId}] Chat: ${chat.id}`);
      }
    });

    this.socket.ev.on('chats.update', (updates: any[]) => {
      for (const chat of updates) {
        logger.debug(`[Session ${this.accountId}] Chat update: ${chat.id}`);
      }
    });

    this.socket.ev.on('messages.upsert', ({ messages }) => {
      for (const waMsg of messages) {
        const msg = this.parseWAMessage(waMsg);
        if (msg) {
          this.onMessage?.(msg);
        }
      }
    });
  }

  private parseWAMessage(waMsg: any): ChatMessage | null {
    try {
      const key = waMsg.key;
      if (!key) return null;
      const msg = waMsg.message;
      if (!msg) return null;

      let body = '';
      let type: ChatMessage['type'] = 'text';

      if (msg.conversation) {
        body = msg.conversation;
      } else if (msg.extendedTextMessage?.text) {
        body = msg.extendedTextMessage.text;
      } else if (msg.imageMessage?.caption) {
        body = msg.imageMessage.caption || '[Image]';
        type = 'image';
      } else if (msg.videoMessage?.caption) {
        body = msg.videoMessage.caption || '[Video]';
        type = 'video';
      } else if (msg.documentMessage?.caption) {
        body = msg.documentMessage.caption || '[Document]';
        type = 'document';
      } else if (msg.audioMessage?.caption) {
        body = msg.audioMessage.caption || '[Audio]';
        type = 'audio';
      } else if (msg.imageMessage) {
        body = '[Image]';
        type = 'image';
      } else if (msg.videoMessage) {
        body = '[Video]';
        type = 'video';
      } else if (msg.audioMessage) {
        body = '[Audio]';
        type = 'audio';
      } else if (msg.documentMessage) {
        body = '[Document]';
        type = 'document';
      } else if (msg.stickerMessage) {
        body = '[Sticker]';
        type = 'sticker';
      } else if (msg.pttMessage) {
        body = '[PTT]';
        type = 'ptt';
      } else if (msg.buttonsMessage) {
        body = '[Buttons]';
        type = 'text';
      } else if (msg.listMessage) {
        body = '[List]';
        type = 'text';
      } else {
        body = '[Unsupported message type]';
        type = 'unknown';
      }

      if (!body) return null;

      return {
        id: key.id || `msg-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        accountId: this.accountId,
        jid: key.remoteJid || key.participant || 'unknown',
        fromMe: key.fromMe || false,
        timestamp: waMsg.messageTimestamp || Math.floor(Date.now() / 1000),
        body,
        type,
      };
    } catch (err) {
      logger.error(`[Session ${this.accountId}] Failed to parse message:`, err);
      return null;
    }
  }

  async sendMessage(to: string, content: string): Promise<string> {
    if (this.testMode) {
      // Test mode: simulate successful send
      const messageId = `test-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      logger.info(`[Session ${this.accountId}] Test mode: sent message to ${to}`);
      return messageId;
    }
    if (!this.socket || !this.isConnected) {
      throw new Error(`Account not connected: ${this.accountId}`);
    }
    const jid = to.includes('@') ? to : `${to}@s.whatsapp.net`;
    const result = await this.socket.sendMessage(jid, { text: content });
    return result?.messageId || 'sent';
  }

  async batchSend(param: BatchSendMessageParam): Promise<{ success: number; failed: number }> {
    let success = 0;
    let failed = 0;
    const jids = param.targetJids || [];

    for (const jid of jids) {
      try {
        const targetJid = jid.includes('@') ? jid : `${jid}@s.whatsapp.net`;
        await this.socket.sendMessage(targetJid, { text: param.message });
        success++;
      } catch (err) {
        failed++;
        logger.warn(`[Session ${this.accountId}] Failed to send to ${jid}: ${err}`);
      }
      // Random delay between messages
      const delay = param.randomized
        ? param.delayMs + Math.random() * param.delayMs
        : param.delayMs;
      await sleep(delay);
    }

    return { success, failed };
  }

  async disconnect(): Promise<void> {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    if (this.socket) {
      try { await this.socket.end(undefined); } catch {}
      this.socket = null;
    }
    this.isConnected = false;
    logger.info(`[Session ${this.accountId}] Disconnected`);
  }

  private shouldReconnect(reason: string): boolean {
    if (reason.includes('401') || reason.includes('banned')) return false;
    if (reason.includes('403')) return false;
    if (reason.includes('conflict')) return false;
    return this.reconnectAttempts < this.maxReconnectAttempts;
  }

  private parseDisconnectReason(error?: any): string {
    if (!error) return 'unknown';
    const boomError = error?.output?.statusCode || error?.code;
    const message = error?.message || error?.error?.message || '';
    const reasonMap: Record<number, string> = {
      401: 'Unauthorized (account banned)',
      403: 'Forbidden (temporarily banned)',
      414: 'Conflict (session conflict)',
      440: 'Disconnected (re-login needed)',
      500: 'Internal server error',
    };
    if (boomError && reasonMap[boomError]) return reasonMap[boomError];
    return message.substring(0, 80) || String(boomError || 'unknown');
  }

}

function sleep(ms: number): Promise<void> {
  return new Promise(r => setTimeout(r, ms));
}

// ─── 单例导出 ────────────────────────────────────────────────

export const sessionManager = new SessionManager();
