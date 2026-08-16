// @ts-nocheck
/**
 * 配对码登录服务
 *
 * 支持手机号 → 配对码 → 真实登录流程
 * 用于没有密钥导出文件的情况
 */

import makeWASocket, { fetchLatestBaileysVersion } from '@whiskeysockets/baileys';
import type { AuthenticationState } from '@whiskeysockets/baileys/lib/Types/Auth';
import { useMultiFileAuthState } from '@whiskeysockets/baileys/lib/Utils/use-multi-file-auth-state';
import { logger } from '../logger';

export interface PairingConfig {
  phoneNumber: string;
  deviceName?: string;
}

export interface PairingResult {
  success: boolean;
  pairingCode?: string;
  error?: string;
  accountId?: string;
}

export interface PairingSession {
  accountId: string;
  phoneNumber: string;
  pairingCode: string;
  socket: ReturnType<typeof makeWASocket>;
  authState: AuthenticationState;
  connected: boolean;
  error?: string;
}

// 配对会话存储
const pairingSessions = new Map<string, PairingSession>();

/**
 * 开始配对流程
 */
export async function startPairing(
  accountId: string,
  config: PairingConfig
): Promise<PairingResult> {
  try {
    logger.info(`[Pairing] Starting pairing for ${config.phoneNumber}`);

    // 创建认证状态
    const authState = await useMultiFileAuthState(`./auth_data/${accountId}`);

    // 创建 socket
    const { version } = await fetchLatestBaileysVersion();
    const socket = makeWASocket({
      auth: authState,
      browser: ['WhatsApp', 'Android', '17.0'] as any,
      version,
      connectTimeoutMs: 30000,
      keepAliveIntervalMs: 30000,
      getMessage: async () => undefined,
    });

    // 等待连接
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Connection timeout')), 60000);

      socket.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (connection === 'open') {
          clearTimeout(timeout);
          logger.info(`[Pairing] Connected successfully!`);
          resolve();
        } else if (connection === 'close') {
          clearTimeout(timeout);
          const reason = lastDisconnect?.error?.output?.statusCode;
          reject(new Error(`Connection failed: ${reason}`));
        }

        if (qr) {
          logger.warn('[Pairing] QR required, falling back to pairing code');
        }
      });
    });

    // 请求配对码
    const pairingCode = await socket.requestPairingCode(config.phoneNumber);
    logger.info(`[Pairing] Pairing code: ${pairingCode}`);

    // 保存会话
    pairingSessions.set(accountId, {
      accountId,
      phoneNumber: config.phoneNumber,
      pairingCode,
      socket,
      authState,
      connected: true,
    });

    return { success: true, pairingCode, accountId };
  } catch (err) {
    logger.error('[Pairing] Failed:', err);
    return { success: false, error: err instanceof Error ? err.message : 'Unknown error' };
  }
}

/**
 * 获取配对码
 */
export function getPairingCode(accountId: string): string | undefined {
  const session = pairingSessions.get(accountId);
  return session?.pairingCode;
}

/**
 * 检查配对状态
 */
export function getPairingStatus(accountId: string): PairingSession | undefined {
  return pairingSessions.get(accountId);
}

/**
 * 断开配对
 */
export function stopPairing(accountId: string): void {
  const session = pairingSessions.get(accountId);
  if (session) {
    session.socket.end(undefined);
    pairingSessions.delete(accountId);
    logger.info(`[Pairing] Stopped pairing for ${accountId}`);
  }
}

/**
 * 清理所有配对会话
 */
export function cleanupAllPairings(): void {
  for (const [id, session] of pairingSessions) {
    session.socket.end(undefined).catch(() => {});
  }
  pairingSessions.clear();
}
