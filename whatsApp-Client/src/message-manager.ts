/**
 * WhatsApp 消息管理器
 *
 * 处理消息发送、接收、媒体下载等核心功能。
 */

import type { WAConnectionState, WASocket, DownloadableMessage } from '@whiskeysockets/baileys';
import * as fs from 'fs';
import * as path from 'path';
import { logger as baseLogger } from './logger';

// ─── 类型定义 ────────────────────────────────────────────────

export interface Message {
  id: string;
  jid: string;
  fromMe: boolean;
  timestamp: number;
  body: string;
  type: 'text' | 'image' | 'video' | 'audio' | 'document' | 'sticker' | 'ptt' | 'unknown';
}

export interface MessageFilter {
  jid?: string;
  fromMe?: boolean;
  type?: string;
  limit?: number;
}

export interface DownloadOptions {
  directory?: string;
  fileName?: string;
}

// ─── 消息管理器 ──────────────────────────────────────────────

export class MessageManager {
  private socket: WASocket | null = null;
  private messages: Map<string, Message> = new Map();
  private messageLimit = 1000;
  private downloadDir: string;
  private onMessageCallback?: (message: Message) => void;
  private pairingCodeHandler?: (code: string) => void;
  
  constructor(options: { downloadDir?: string; messageLimit?: number } = {}) {
    this.downloadDir = options.downloadDir ?? './downloads';
    this.messageLimit = options.messageLimit ?? 1000;

    // Ensure download directory exists
    if (!fs.existsSync(this.downloadDir)) {
      fs.mkdirSync(this.downloadDir, { recursive: true });
    }
  }

  /**
   * 绑定 Socket 实例
   */
  bindSocket(socket: WASocket): void {
    this.socket = socket;

    // 监听消息
    socket.ev.on('messages.upsert', ({ messages }) => {
      for (const waMsg of messages) {
        const message = this.parseMessage(waMsg);
        if (message) {
          this.storeMessage(message);
          this.onMessageCallback?.(message);
          baseLogger.info(`[MessageManager] ${message.fromMe ? 'Sent' : 'Received'}: ${message.jid} - ${message.body.substring(0, 50)}`);
        }
      }
    });

    // 监听配对码
    socket.ev.on('creds.update', (creds) => {
      if (creds.pairingCode) {
        baseLogger.info(`[MessageManager] Pairing code: ${creds.pairingCode}`);
        this.pairingCodeHandler?.(creds.pairingCode);
      }
    });
  }

  /**
   * 设置消息回调
   */
  onMessage(handler: (message: Message) => void): void {
    this.onMessageCallback = handler;
  }

  /**
   * 设置配对码回调
   */
  onPairingCode(handler: (code: string) => void): void {
    this.pairingCodeHandler = handler;
  }/**
   * 发送文本消息
   */
  async sendText(to: string, content: string): Promise<string> {
    if (!this.socket) {
      throw new Error('Socket not bound');
    }

    const jid = to.includes('@') ? to : `${to}@s.whatsapp.net`;

    const msgId = await this.socket.sendMessage(jid, {
      text: content,
    });

    baseLogger.info(`[MessageManager] Sent text to ${jid}: ${content.substring(0, 50)}...`);
    return "sent";
  }

  /**
   * 发送图片消息
   */
  async sendImage(to: string, imagePath: string, caption?: string): Promise<string> {
    if (!this.socket) {
      throw new Error('Socket not bound');
    }

    const jid = to.includes('@') ? to : `${to}@s.whatsapp.net`;

    const buffer = fs.readFileSync(imagePath);

    const msgId = await this.socket.sendMessage(jid, {
      image: buffer,
      caption: caption || '',
    });

    baseLogger.info(`[MessageManager] Sent image to ${jid}: ${imagePath}`);
    return "sent";
  }

  /**
   * 发送文档消息
   */
  async sendDocument(to: string, filePath: string, fileName?: string): Promise<string> {
    if (!this.socket) {
      throw new Error('Socket not bound');
    }

    const jid = to.includes('@') ? to : `${to}@s.whatsapp.net`;
    const buffer = fs.readFileSync(filePath);

    const msgId = await this.socket.sendMessage(jid, { document: buffer, fileName: fileName || path.basename(filePath), mimetype: "application/octet-stream" });

    baseLogger.info(`[MessageManager] Sent document to ${jid}: ${filePath}`);
    return "sent";
  }

  /**
   * 下载媒体消息
   */
  async downloadMedia(message: DownloadableMessage, options?: DownloadOptions): Promise<string> {
    const buffer = await (this.socket as any).downloadMediaMessage(message);
    const ext = this.getExtension(message);
    const fileName = options?.fileName || `${Date.now()}.${ext}`;
    const filePath = path.join(options?.directory || this.downloadDir, fileName);

    fs.writeFileSync(filePath, buffer);
    baseLogger.info(`[MessageManager] Downloaded media to: ${filePath}`);

    return filePath;
  }

  /**
   * 获取消息历史
   */
  getMessages(filter?: MessageFilter): Message[] {
    let msgs = Array.from(this.messages.values());

    if (filter?.jid) {
      msgs = msgs.filter(m => m.jid === filter.jid);
    }
    if (filter?.fromMe !== undefined) {
      msgs = msgs.filter(m => m.fromMe === filter.fromMe);
    }
    if (filter?.type) {
      msgs = msgs.filter(m => m.type === filter.type);
    }
    if (filter?.limit) {
      msgs = msgs.slice(-filter.limit);
    }

    return msgs.sort((a, b) => a.timestamp - b.timestamp);
  }

  /**
   * 获取消息数量
   */
  getMessageCount(filter?: MessageFilter): number {
    let count = this.messages.size;
    if (filter?.jid) {
      count = Array.from(this.messages.values()).filter(m => m.jid === filter.jid).length;
    }
    return count;
  }

  /**
   * 清空消息缓存
   */
  clearMessages(): void {
    this.messages.clear();
    baseLogger.info('[MessageManager] Cleared all messages');
  }

  /**
   * 解析 WhatsApp 消息
   */
  private parseMessage(waMsg: any): Message | null {
    try {
      const key = waMsg.key;
      if (!key) return null;

      const msg = waMsg.message;
      if (!msg) return null;

      // Extract text content
      let body = '';
      if (msg.conversation) {
        body = msg.conversation;
      } else if (msg.extendedTextMessage?.text) {
        body = msg.extendedTextMessage.text;
      } else if (msg.imageMessage?.caption) {
        body = msg.imageMessage.caption || '[Image]';
      } else if (msg.videoMessage?.caption) {
        body = msg.videoMessage.caption || '[Video]';
      } else if (msg.documentMessage?.caption) {
        body = msg.documentMessage.caption || '[Document]';
      } else if (msg.audioMessage?.caption) {
        body = msg.audioMessage.caption || '[Audio]';
      }

      if (!body) {
        body = this.getMessageType(msg);
      }

      return {
        id: key.id,
        jid: key.remoteJid || key.participant || 'unknown',
        fromMe: key.fromMe || false,
        timestamp: waMsg.messageTimestamp || Date.now() / 1000,
        body,
        type: this.getMessageType(msg) as Message["type"],
      };
    } catch (error) {
      baseLogger.error('[MessageManager] Failed to parse message:', error);
      return null;
    }
  }

  /**
   * 获取消息类型
   */
  private getMessageType(msg: any): string {
    if (msg.imageMessage) return 'image';
    if (msg.videoMessage) return 'video';
    if (msg.audioMessage) return 'audio';
    if (msg.documentMessage) return 'document';
    if (msg.stickerMessage) return 'sticker';
    if (msg.pttMessage) return 'ptt';
    if (msg.conversation || msg.extendedTextMessage?.text || msg.imageMessage?.caption) return 'text';
    return 'unknown';
  }

  /**
   * 存储消息
   */
  private storeMessage(message: Message): void {
    this.messages.set(message.id, message);

    // Enforce limit
    if (this.messages.size > this.messageLimit) {
      const ids = Array.from(this.messages.keys());
      ids.slice(0, ids.length - this.messageLimit).forEach(id => this.messages.delete(id));
    }
  }

  /**
   * 获取文件扩展名
   */
  private getExtension(msg: any): string {
    if (msg.imageMessage?.mimetype?.includes('png')) return 'png';
    if (msg.imageMessage?.mimetype?.includes('jpeg')) return 'jpg';
    if (msg.videoMessage?.mimetype?.includes('mp4')) return 'mp4';
    if (msg.audioMessage?.mimetype?.includes('ogg')) return 'ogg';
    return 'bin';
  }
}

