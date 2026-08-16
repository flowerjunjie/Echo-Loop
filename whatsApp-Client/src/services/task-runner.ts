// @ts-nocheck
/**
 * 批量任务处理器
 *
 * 实现：批量登录、批量发消息、聊天农场、历史同步等并发任务
 */

import type { BatchTask, BatchLoginParam, BatchSendMessageParam, WhatsAppAccount } from '../types';
import { insertTask, updateTaskProgress, getTask, listTasks, insertAccount } from '../db';
import { logger } from '../logger';
import { sessionManager } from './session-manager';
import { randomLoginDelay } from './device-spoof';
import { buildAuthenticationState } from '../baileys-auth-builder';
import { loadExport } from '../export-loader';
import { parseWhatsAppExport } from '../key-parser';

// ─── 任务类型注册 ────────────────────────────────────────────

const handlers: Record<string, (task: BatchTask) => Promise<void>> = {};

function registerHandler(type: string, fn: (task: BatchTask) => Promise<void>): void {
  handlers[type] = fn;
}

// ─── 批量登录 ────────────────────────────────────────────────

import * as fs from 'fs';
import * as path from 'path';

registerHandler('login', async (task) => {
  const param = task.params as BatchLoginParam;
  // Support both direct file paths and directory scanning
  const rawFiles = param.exportFiles || [];
  const files: string[] = [];
  for (const f of rawFiles) {
    if (fs.existsSync(f) && fs.statSync(f).isDirectory()) {
      // Scan directory for .txt export files
      const dirFiles = fs.readdirSync(f)
        .filter(n => n.endsWith('.txt') || n.endsWith('.json'))
        .map(n => path.join(f, n));
      files.push(...dirFiles);
    } else {
      files.push(f);
    }
  }
  const concurrent = param.concurrent || 3;
  const autoConnect = param.autoConnect !== false;
  const deviceConfigs = param.deviceConfigs || [];

  updateTaskProgress(task.id, { status: 'running', startedAt: Date.now(), total: files.length });

  let idx = 0;
  const results = { success: 0, failed: 0 };

  while (idx < files.length) {
    const batch = files.slice(idx, idx + concurrent);
    const promises = batch.map(async (file, i) => {
      try {
        const exportData = await loadExport(file);
        const parsed = parseWhatsAppExport(exportData);
        const authState = buildAuthenticationState({ parsed });

        // Round-robin device config assignment
        const deviceConfigId = deviceConfigs[i % deviceConfigs.length] || '';

        const account: WhatsAppAccount = {
          id: `acct-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
          name: parsed.nickname || exportData.account,
          phone: parsed.account,
          exportFile: file,
          status: 'idle',
          deviceId: parsed.deviceId,
          deviceConfigId,
          createdAt: Date.now(),
          updatedAt: Date.now(),
          messageCount: 0,
        };

        insertAccount(account);

        if (autoConnect) {
          await sleep(randomLoginDelay());
          const { sessionManager } = require('./session-manager');
          await sessionManager.connect(account, { authState, deviceConfigId: deviceConfigId || undefined });
          logger.info(`[BatchLogin] Connected: ${account.name} (${account.phone})`);
        } else {
          logger.info(`[BatchLogin] Account added: ${account.name} (${account.phone})`);
        }

        results.success++;
      } catch (err) {
        results.failed++;
        logger.error(`[BatchLogin] Failed to process ${file}:`, err);
      }
    });

    await Promise.all(promises);
    idx += concurrent;

    const progress = Math.round((idx / files.length) * 100);
    updateTaskProgress(task.id, { progress, success: results.success, failed: results.failed });
  }

  updateTaskProgress(task.id, {
    status: 'completed',
    progress: 100,
    completedAt: Date.now(),
    success: results.success,
    failed: results.failed,
  });
});

// ─── 批量发消息 ──────────────────────────────────────────────

registerHandler('send_message', async (task) => {
  const param = task.params as BatchSendMessageParam;
  const accountIds = task.accountIds;

  updateTaskProgress(task.id, { status: 'running', startedAt: Date.now(), total: accountIds.length });

  let success = 0;
  let failed = 0;

  for (const accountId of accountIds) {
    try {
      // Wait a bit between accounts for anti-detection
      await sleep(randomLoginDelay());

      const { sessionManager } = require('./session-manager');
      await sessionManager.batchSend(accountId, param);
      success++;
    } catch (err) {
      failed++;
      logger.error(`[BatchSend] Failed for account ${accountId}:`, err);
    }

    const progress = Math.round(((success + failed) / accountIds.length) * 100);
    updateTaskProgress(task.id, { progress, success, failed });
  }

  updateTaskProgress(task.id, {
    status: 'completed',
    progress: 100,
    completedAt: Date.now(),
    success,
    failed,
  });
});

// ─── 聊天农场 ────────────────────────────────────────────────

registerHandler('chat_farm', async (task) => {
  const param = task.params as any;
  const accountIds = task.accountIds;
  const targetJids = param.targetJids || [];
  const messages = param.messages || [];

  updateTaskProgress(task.id, { status: 'running', startedAt: Date.now(), total: accountIds.length });

  let success = 0;
  let failed = 0;

  for (const accountId of accountIds) {
    if (targetJids.length === 0 || messages.length === 0) {
      updateTaskProgress(task.id, { failed: failed + 1 });
      failed++;
      continue;
    }

    try {
      await sleep(randomLoginDelay());
      const { sessionManager } = require('./session-manager');

      for (const jid of targetJids) {
        const msg = messages[Math.floor(Math.random() * messages.length)];
        await sessionManager.sendMessage(accountId, jid, msg);
        await sleep(2000 + Math.random() * 3000);
      }

      success++;
    } catch (err) {
      failed++;
      logger.error(`[ChatFarm] Failed for ${accountId}:`, err);
    }

    const progress = Math.round(((success + failed) / accountIds.length) * 100);
    updateTaskProgress(task.id, { progress, success, failed });
  }

  updateTaskProgress(task.id, {
    status: 'completed',
    progress: 100,
    completedAt: Date.now(),
    success,
    failed,
  });
});

// ─── 历史同步 ────────────────────────────────────────────────

registerHandler('sync_history', async (task) => {
  const param = task.params as any;
  const accountIds = task.accountIds;

  updateTaskProgress(task.id, { status: 'running', startedAt: Date.now(), total: accountIds.length });

  let synced = 0;
  for (const accountId of accountIds) {
    // History sync is handled via the chat-history service
    synced++;
    await sleep(500);
  }

  updateTaskProgress(task.id, {
    status: 'completed',
    progress: 100,
    completedAt: Date.now(),
    success: synced,
  });
});

// ─── 账号迁移 ────────────────────────────────────────────────

registerHandler('migrate_accounts', async (task) => {
  const param = task.params as any;

  // Reuse login handler logic
  const loginTask = { ...task, params: { ...task.params, exportFiles: param.exportFiles } };
  await handlers['login'](loginTask);
});

// ─── 任务调度器 ──────────────────────────────────────────────

export async function runTask(taskId: string): Promise<void> {
  const task = getTask(taskId);
  if (!task) throw new Error(`Task ${taskId} not found`);
  if (task.status !== 'pending') return;

  const handler = handlers[task.type];
  if (!handler) {
    updateTaskProgress(taskId, { status: 'failed', error: `Unknown task type: ${task.type}` });
    return;
  }

  await handler(task);
}

export function listAllTasks(): BatchTask[] {
  return listTasks(100);
}

// ─── 工具 ────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise(r => setTimeout(r, ms));
}
