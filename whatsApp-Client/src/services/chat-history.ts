// @ts-nocheck
/**
 * 聊天历史管理服务
 *
 * 实现：聊天记录查询、云端恢复、历史消息持久化
 */

import type { ChatMessage, ChatHistoryQuery, Conversation } from '../types';
import {
  insertMessages, getChatHistory, getConversations, countMessagesByAccount,
  logAudit,
} from '../db';
import { logger } from '../logger';

// ─── 消息存储 ────────────────────────────────────────────────

/**
 * 持久化接收到的消息到数据库
 */
export function storeMessages(messages: ChatMessage[]): void {
  if (messages.length === 0) return;
  insertMessages(messages);
  logger.debug(`[ChatHistory] Stored ${messages.length} messages`);
}

/**
 * 查询聊天历史
 */
export function queryHistory(query: ChatHistoryQuery): { messages: ChatMessage[]; total: number } {
  return getChatHistory(query);
}

/**
 * 获取对话列表
 */
export function listConversations(accountId: string, limit = 50): Conversation[] {
  return getConversations(accountId, limit);
}

/**
 * 导出聊天记录为 JSON
 */
export function exportChatHistory(accountId: string, format: 'json' | 'csv' = 'json'): string {
  const { messages } = getChatHistory({ accountId, limit: 10000 });
  if (format === 'csv') {
    const header = 'timestamp,from_me,jid,type,body\n';
    const rows = messages.map(m =>
      `"${new Date(m.timestamp * 1000).toISOString()}",${m.fromMe},"${m.jid}","${m.type}","${m.body.replace(/"/g, '""')}"`
    ).join('\n');
    return header + rows;
  }
  return JSON.stringify(messages, null, 2);
}

/**
 * 清空指定账户的聊天记录
 */
export function clearChatHistory(accountId: string): void {
  const { getDb } = require('../db');
  const d = getDb();
  d.prepare('DELETE FROM chat_messages WHERE account_id = ?').run(accountId);
  logger.info(`[ChatHistory] Cleared history for account ${accountId}`);
}

/**
 * 统计各账户消息数量
 */
export function getAccountMessageStats(): Record<string, number> {
  return countMessagesByAccount();
}

// ─── 云端恢复模拟 ────────────────────────────────────────────

/**
 * 从远程服务器恢复聊天记录
 * （实际部署时对接云存储或后端 API）
 */
export async function restoreFromCloud(
  accountId: string,
  cloudApiUrl: string,
  token?: string
): Promise<{ restored: number; failed: number }> {
  logger.info(`[ChatHistory] Restoring history for ${accountId} from ${cloudApiUrl}`);

  try {
    const res = await require('axios').get(cloudApiUrl, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      timeout: 30000,
    });

    const messages: ChatMessage[] = Array.isArray(res.data) ? res.data : (res.data?.messages || []);
    if (messages.length > 0) {
      storeMessages(messages.map(m => ({
        ...m,
        accountId,
        fromMe: m.fromMe ?? false,
        translatedBody: m.translatedBody,
        translationSource: m.translationSource,
        translationTargetLang: m.translationTargetLang,
      })));
      logger.info(`[ChatHistory] Restored ${messages.length} messages for ${accountId}`);
      return { restored: messages.length, failed: 0 };
    }
    return { restored: 0, failed: 0 };
  } catch (err) {
    logger.error('[ChatHistory] Cloud restore failed:', err);
    return { restored: 0, failed: -1 };
  }
}

// ─── 消息同步（从 Baileys 事件获取历史）─────────────────────

/**
 * 请求并存储过去 N 天的消息
 * Baileys 不支持直接拉取历史，这里记录接口供外部同步使用
 */
export interface SyncRange {
  accountId: string;
  jid: string;
  since: number; // unix timestamp
}

export async function syncMessageRange(ranges: SyncRange[]): Promise<number> {
  // 注意：Baileys 本身不提供历史消息拉取 API
  // 此函数预留接口，实际由上层业务填充已收到的消息
  let synced = 0;
  for (const range of ranges) {
    // 在实际场景中，这里会从服务端拉取消息后调用 storeMessages
    synced++;
  }
  return synced;
}
