/**
 * WhatsApp QR 配对管理器
 *
 * 处理 QR 码生成和配对流程，用于绕过 serverStaticPublic 限制。
 */

import makeWASocket, {
  type WAConnectionState,
  DisconnectReason,
  fetchLatestBaileysVersion,
} from '@whiskeysockets/baileys';
import QrCode from 'qrcode';
import * as fs from 'fs';
import * as path from 'path';
import { logger as baseLogger } from './logger';

// ─── 类型定义 ────────────────────────────────────────────────

export interface QRPairingConfig {
  phoneNumber: string;
  authDir?: string;
  browser?: [string, string, string];
}

export interface QRPairingResult {
  success: boolean;
  qrCode?: string;
  pairingCode?: string;
  error?: string;
}

// ─── QR 配对管理器 ──────────────────────────────────────────

export class QRPairingManager {
  private socket: ReturnType<typeof makeWASocket> | null = null;
  private phoneNumber: string;
  private authDir: string;
  private browser: [string, string, string];
  private pairingCode?: string;
  private onQRCode?: (qr: string) => void;
  private onPairingCode?: (code: string) => void;
  private onConnected?: () => void;

  constructor(config: QRPairingConfig) {
    this.phoneNumber = config.phoneNumber;
    this.authDir = config.authDir ?? './auth_data';
    this.browser = config.browser ?? ['WhatsApp', 'Android', '17.0'];
  }

  /**
   * 设置 QR 码回调
   */
  setOnQRCode(handler: (qr: string) => void): void {
    this.onQRCode = handler;
  }

  /**
   * 设置配对码回调
   */
  setOnPairingCode(handler: (code: string) => void): void {
    this.onPairingCode = handler;
  }

  /**
   * 设置连接成功回调
   */
  setOnConnected(handler: () => void): void {
    this.onConnected = handler;
  }

  /**
   * 开始 QR 配对流程
   */
  async startPairing(): Promise<QRPairingResult> {
    baseLogger.info('[QRPairing] Starting QR pairing for: ' + this.phoneNumber);

    try {
      // 确保认证目录存在
      if (!fs.existsSync(this.authDir)) {
        fs.mkdirSync(this.authDir, { recursive: true });
      }

      // 获取最新协议版本
      const { version } = await fetchLatestBaileysVersion();
      baseLogger.info('[QRPairing] Using WhatsApp version: ' + version.join('.'));

      // 创建 socket 连接
      this.socket = makeWASocket({
        auth: { creds: {} as any, keys: { get: async () => ({}), set: async () => {} } } as any,
        browser: this.browser,
        version,
        logger: baseLogger as any,
        connectTimeoutMs: 30000,
        keepAliveIntervalMs: 30000,
        getMessage: async () => undefined,
      });

      // 监听连接状态
      this.socket.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (connection === 'open') {
          baseLogger.info('[QRPairing] Connected successfully!');
          this.onConnected?.();
        } else if (connection === 'close') {
          const reason = this.getDisconnectReason(lastDisconnect?.error);
          baseLogger.warn('[QRPairing] Connection closed: ' + reason);
        }

        // QR 码
        if (qr) {
          baseLogger.info('[QRPairing] QR code received, scanning with WhatsApp app...');
          const qrData = await QrCode.toDataURL(qr);
          this.onQRCode?.(qrData);
        }
      });

      // 监听凭证更新
      this.socket.ev.on('creds.update', (creds) => {
        baseLogger.debug('[QRPairing] Creds updated:', {
          me: creds.me?.id,
          registered: creds.registered,
        });
      });

      // 请求配对码
      baseLogger.info('[QRPairing] Requesting pairing code...');
      const pairingCode = await this.socket.requestPairingCode(this.phoneNumber);
      baseLogger.info('[QRPairing] Pairing code: ' + pairingCode);
      this.pairingCode = pairingCode;
      this.onPairingCode?.(pairingCode);

      return {
        success: true,
        pairingCode,
      };
    } catch (error) {
      baseLogger.error('[QRPairing] Failed to start pairing:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    if (this.socket) {
      await this.socket.end(undefined);
      this.socket = null;
      baseLogger.info('[QRPairing] Disconnected');
    }
  }

  /**
   * 获取当前配对码
   */
  getPairingCode(): string | undefined {
    return this.pairingCode;
  }

  /**
   * 获取断连原因
   */
  private getDisconnectReason(error?: any): string {
    if (!error) return 'unknown';

    const boomError = error?.output?.statusCode || error?.code;
    const message = error?.message || error?.error?.message || '';

    const reasonMap: Record<number, string> = {
      401: 'Unauthorized (Account exception)',
      403: 'Forbidden (Account banned)',
      414: 'Conflict (Session conflict)',
      440: 'Disconnected (Re-login required)',
      500: 'Internal Server Error',
    };

    if (boomError && reasonMap[boomError]) {
      return boomError + ': ' + reasonMap[boomError];
    }

    if (message) {
      return message.substring(0, 100);
    }

    return String(boomError || 'unknown');
  }
}

// ─── 便捷函数 ────────────────────────────────────────────────

/**
 * 快速开始配对
 */
export async function quickPair(config: QRPairingConfig): Promise<QRPairingResult> {
  const manager = new QRPairingManager(config);
  return manager.startPairing();
}

// ─── 导出 ────────────────────────────────────────────────────
