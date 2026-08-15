// @ts-nocheck
/**
 * 会话管理器 — 核心连接编排
 *
 * 管理所有 WhatsApp 账户的 WebSocket 会话，支持：
 * - 并发连接/断连
 * - 消息路由和翻译
 * - 断线重连
 * - 设备伪装配置注入
 */

import makeWASocket, { fetchLatestBaileysVersion, DisconnectReason } from '@whiskeysockets/baileys';
import type { WASocket } from '@whiskeysockets/baileys';
import type { AuthenticationState } from '@whiskeysockets/baileys/lib/Types/Auth';
import type { WhatsAppAccount, ChatMessage, BatchSendMessageParam } from '../types';
import type { DeviceConfig } from '../types';
import { logger } from '../logger';
import { storeMessages, translateText } from './chat-history';
import { getTranslationConfig } from './translation';
import { buildConnectionConfig } from './device-spoof';
import { updateAccountStatus, updateAccountConnection, addMessageToAccount } from '../db';

export interface SessionConfig {
  authState: AuthenticationState;
  deviceConfig?: DeviceConfig;
  proxyUrl?: string;
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
  private authState: AuthenticationState;
  private deviceConfig?: DeviceConfig;
  private proxyUrl?: string;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;

  constructor(account: WhatsAppAccount, config: SessionConfig) {
    this.accountId = account.id;
    this.authState = config.authState;
    this.deviceConfig = config.deviceConfig;
    this.proxyUrl = config.proxyUrl;
  }

  async connect(): Promise<void> {
    const { version } = await fetchLatestBaileysVersion();
    const connConfig: any = {
      auth: this.authState,
      browser: this.deviceConfig?.browser ?? ['WhatsApp', 'Android', '17.0'],
      version,
      connectTimeoutMs: 30000,
      keepAliveIntervalMs: 30000,
      getMessage: async () => undefined,
    };

    // Proxy support (Baileys 7.x uses 'agent' instead of 'httpOpts')
    if (this.proxyUrl) {
      const { SocksProxyAgent } = await import('socks-proxy-agent');
      connConfig.agent = new SocksProxyAgent(this.proxyUrl);
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
    if (!this.socket || !this.isConnected) {
      throw new Error(`Account not connected: ${this.accountId}`);
    }
    const jid = to.includes('@') ? to : `${to}@s.whatsapp.net`;
    const result = await this.socket.sendMessage(jid, { text: content });
    return result?.messageId || 'sent';
  }

  async batchSend(param: BatchSendMessageParam): Promise<{ success: number; failed: number }> {
    if (!this.socket || !this.isConnected) {
      throw new Error(`Account not connected: ${this.accountId}`);
    }
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
