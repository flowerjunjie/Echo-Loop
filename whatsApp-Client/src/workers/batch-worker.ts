// @ts-nocheck
/**
 * 后台任务轮询器
 *
 * 定期检查待执行的批量任务并分发到 task-runner
 */

import { listTasks, updateTaskProgress } from '../db';
import { runTask } from '../services/task-runner';
import { logger } from '../logger';

let pollingInterval: ReturnType<typeof setInterval> | null = null;
let isPaused = false;

export function pauseTasks(): void { isPaused = true; logger.info('[TaskPoller] Tasks paused'); }
export function resumeTasks(): void { isPaused = false; logger.info('[TaskPoller] Tasks resumed'); }
export function isTaskPaused(): boolean { return isPaused; }

export function startTaskPolling(intervalMs = 3000): void {
  if (pollingInterval) return;
  pollingInterval = setInterval(pollTasks, intervalMs);
  logger.info('[TaskPoller] Started, interval=' + intervalMs + 'ms');
}

export function stopTaskPolling(): void {
  if (pollingInterval) {
    clearInterval(pollingInterval);
    pollingInterval = null;
    logger.info('[TaskPoller] Stopped');
  }
}

export async function pollTasks(): Promise<void> {
  const tasks = listTasks(20);
  const pending = tasks.filter(t => t.status === 'pending');

  for (const task of pending) {
    try {
      logger.info(`[TaskPoller] Running task ${task.id}: ${task.name} (${task.type})`);
      await runTask(task.id);
    } catch (err) {
      logger.error(`[TaskPoller] Task ${task.id} failed:`, err);
      updateTaskProgress(task.id, {
        status: 'failed',
        error: err instanceof Error ? err.message : String(err),
        completedAt: Date.now(),
      });
    }
  }
}
