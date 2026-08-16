// @ts-nocheck
/**
 * 定时任务调度器
 * 支持 cron 表达式和简单间隔调度
 */

import { logger } from '../logger';
import { insertTask, updateTaskProgress } from '../db';

interface ScheduledTask {
  id: string;
  name: string;
  cron: string;
  taskType: string;
  params: any;
  enabled: boolean;
  lastRun?: number;
  nextRun?: number;
}

const scheduledTasks: Map<string, ScheduledTask> = new Map();
const intervals: Map<string, ReturnType<typeof setInterval>> = new Map();

export function scheduleTask(task: ScheduledTask): string {
  const id = task.id || 'task-' + Date.now();
  scheduledTasks.set(id, task);
  startInterval(id);
  logger.info(`[Scheduler] Scheduled task: ${task.name} (${task.cron})`);
  return id;
}

export function unscheduleTask(id: string): boolean {
  const task = scheduledTasks.get(id);
  if (!task) return false;
  const interval = intervals.get(id);
  if (interval) clearInterval(interval);
  intervals.delete(id);
  scheduledTasks.delete(id);
  logger.info(`[Scheduler] Unscheduled: ${id}`);
  return true;
}

export function listScheduledTasks(): ScheduledTask[] {
  return Array.from(scheduledTasks.values());
}

function startInterval(id: string): void {
  const task = scheduledTasks.get(id);
  if (!task) return;

  // Simple interval-based scheduling (every N minutes)
  // Parse cron-like expressions: 'every 5 minutes', 'daily at 9', etc.
  let delayMs = 5 * 60 * 1000; // default 5 minutes

  if (task.cron.includes('minute')) {
    const match = task.cron.match(/every\s+(\d+)\s+minutes?/);
    if (match) delayMs = parseInt(match[1]) * 60 * 1000;
  } else if (task.cron.includes('hour')) {
    const match = task.cron.match(/every\s+(\d+)\s+hours?/);
    if (match) delayMs = parseInt(match[1]) * 60 * 60 * 1000;
  } else if (task.cron.includes('day')) {
    delayMs = 24 * 60 * 60 * 1000;
  }

  const interval = setInterval(async () => {
    const t = scheduledTasks.get(id);
    if (!t || !t.enabled) return;

    t.lastRun = Date.now();
    t.nextRun = Date.now() + delayMs;
    logger.info(`[Scheduler] Running scheduled task: ${t.name}`);

    try {
      const newTask = insertTask({
        id: 'sched-' + id + '-' + Date.now(),
        type: t.taskType as any,
        name: `[定时] ${t.name}`,
        status: 'pending',
        params: t.params,
        createdBy: 'scheduler',
      });
      // Task poller will pick it up
    } catch (err) {
      logger.error(`[Scheduler] Failed to create task: ${err}`);
    }
  }, delayMs);

  intervals.set(id, interval);
}

export function getSchedulerStats() {
  return {
    total: scheduledTasks.size,
    enabled: Array.from(scheduledTasks.values()).filter(t => t.enabled).length,
  };
}
