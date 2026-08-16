// @ts-nocheck
/**
 * 聊天记录同步服务
 *
 * 从 WhatsApp 历史同步消息到数据库
 */

import type { WASocket } from '@whiskeysockets/baileys';
import { insertMessages } from '../db';
import { logger } from '../logger';
import type { ChatMessage } from '../types';

/**
 * 同步指定聊天室的历史消息
 */
export async function syncChatHistory(
  socket: WASocket,
  accountId: string,
  jid: string,
  limit = 100
): Promise<ChatMessage[]> {
  try {
    logger.info(`[HistorySync] Syncing history for ${jid}, limit=${limit}`);

    // 使用 Baileys 的 fetchMessages 方法
    const msgs = await (socket as any).fetchMessages(jid, { limit });

    if (!msgs || msgs.length === 0) {
      logger.info(`[HistorySync] No messages found for ${jid}`);
      return [];
    }

    const messages: ChatMessage[] = msgs.map((msg: any) => ({
      id: msg.key.id || `hist-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      accountId,
      jid,
      fromMe: msg.key.fromMe || false,
      timestamp: msg.messageTimestamp || Math.floor(Date.now() / 1000),
      body: extractBody(msg),
      type: extractType(msg),
    }));

    // 存储到数据库
    insertMessages(messages);
    logger.info(`[HistorySync] Synced ${messages.length} messages for ${jid}`);

    return messages;
  } catch (err) {
    logger.error(`[HistorySync] Failed to sync ${jid}:`, err);
    return [];
  }
}

/**
 * 从消息节点提取文本内容
 */
function extractBody(msg: any): string {
  try {
    const m = msg.message;
    if (!m) return '[Empty message]';

    if (m.conversation) return m.conversation;
    if (m.extendedTextMessage?.text) return m.extendedTextMessage.text;
    if (m.imageMessage?.caption) return m.imageMessage.caption;
    if (m.videoMessage?.caption) return m.videoMessage.caption;
    if (m.documentMessage?.caption) return m.documentMessage.caption;
    if (m.audioMessage?.caption) return m.audioMessage.caption || '[Audio]';
    if (m.imageMessage) return '[Image]';
    if (m.videoMessage) return '[Video]';
    if (m.documentMessage) return '[Document]';
    if (m.stickerMessage) return '[Sticker]';
    if (m.pttMessage) return '[PTT]';

    return '[Unsupported message type]';
  } catch {
    return '[Parse error]';
  }
}

/**
 * 从消息节点提取类型
 */
function extractType(msg: any): string {
  try {
    const m = msg.message;
    if (!m) return 'text';

    if (m.conversation || m.extendedTextMessage?.text) return 'text';
    if (m.imageMessage) return 'image';
    if (m.videoMessage) return 'video';
    if (m.documentMessage) return 'document';
    if (m.audioMessage) return 'audio';
    if (m.stickerMessage) return 'sticker';
    if (m.pttMessage) return 'ptt';

    return 'text';
  } catch {
    return 'text';
  }
}
