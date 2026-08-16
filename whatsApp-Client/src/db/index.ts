/**
 * 数据库层 — SQLite + Better-SQLite3
 *
 * 管理：账户、设备配置、管理员/子账号、消息历史、批量任务、审计日志
 */

import Database from 'better-sqlite3';
import * as path from 'path';
import * as fs from 'fs';
// @ts-nocheck
import type {
  WhatsAppAccount,
  DeviceConfig,
  AdminUser,
  ChatMessage,
  BatchTask,
  AuditLog,
  Conversation,
} from '../types';

const DB_PATH = process.env.DB_PATH || path.join(process.cwd(), 'data', 'wa_platform.db');

let db: Database.Database | null = null;

// ─── 初始化 ──────────────────────────────────────────────────

export function getDb(): Database.Database {
  if (!db) {
    const dir = path.dirname(DB_PATH);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
  }
  return db;
}

export function initDb(): void {
  const d = getDb();
  d.exec(`
    CREATE TABLE IF NOT EXISTS admin_users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'sub',
      name TEXT NOT NULL,
      permissions TEXT NOT NULL DEFAULT '[]',
      is_active INTEGER NOT NULL DEFAULT 1,
      last_login_at INTEGER,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      export_file TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'idle',
      device_id TEXT,
      device_config_id TEXT,
      last_connected_at INTEGER,
      last_error TEXT,
      assigned_to TEXT,
      message_count INTEGER NOT NULL DEFAULT 0,
      connection_id TEXT,
      tier TEXT NOT NULL DEFAULT 'B',
      proxy_url TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (assigned_to) REFERENCES admin_users(id)
    );

    // Migration: add proxy_url to accounts if not exists (SQLite 3.25+)
    do {
      const cols = d.prepare("PRAGMA table_info(accounts)").all() as any[];
      if (!cols.some(c => c.name === 'proxy_url')) {
        try { d.exec('ALTER TABLE accounts ADD COLUMN proxy_url TEXT'); } catch {}
      }
      break;
    } while (false);

    CREATE TABLE IF NOT EXISTS device_configs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      browser TEXT NOT NULL DEFAULT '["WhatsApp","Android","17.0"]',
      platform TEXT NOT NULL DEFAULT 'Android',
      model TEXT NOT NULL DEFAULT 'Pixel 7',
      os_version TEXT NOT NULL DEFAULT '13',
      user_agent TEXT NOT NULL,
      locale TEXT NOT NULL DEFAULT 'en_US',
      timezone TEXT NOT NULL DEFAULT 'Asia/Shanghai',
      screen_width INTEGER NOT NULL DEFAULT 1080,
      screen_height INTEGER NOT NULL DEFAULT 2400,
      dpi INTEGER NOT NULL DEFAULT 420,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS chat_messages (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      jid TEXT NOT NULL,
      from_me INTEGER NOT NULL DEFAULT 0,
      timestamp INTEGER NOT NULL,
      body TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'text',
      translated_body TEXT,
      translation_source TEXT,
      translation_target_lang TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_messages_account ON chat_messages(account_id);
    CREATE INDEX IF NOT EXISTS idx_messages_jid ON chat_messages(jid);
    CREATE INDEX IF NOT EXISTS idx_messages_time ON chat_messages(timestamp);

    CREATE TABLE IF NOT EXISTS batch_tasks (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      account_ids TEXT NOT NULL DEFAULT '[]',
      params TEXT NOT NULL DEFAULT '{}',
      progress INTEGER NOT NULL DEFAULT 0,
      total INTEGER NOT NULL DEFAULT 0,
      success INTEGER NOT NULL DEFAULT 0,
      failed INTEGER NOT NULL DEFAULT 0,
      error TEXT,
      created_at INTEGER NOT NULL,
      started_at INTEGER,
      completed_at INTEGER,
      updated_at INTEGER,
      created_by TEXT
    );

    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      action TEXT NOT NULL,
      target_type TEXT,
      target_id TEXT,
      details TEXT,
      ip TEXT,
      user_agent TEXT,
      created_at INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
    CREATE INDEX IF NOT EXISTS idx_audit_time ON audit_logs(created_at);
  `);

  // 创建默认管理员账号: admin / admin123
  const existing = d.prepare('SELECT id FROM admin_users WHERE username = ?').get('admin') as { id: string } | undefined;
  if (!existing) {
    const bcrypt = require('bcryptjs');
    const hash = bcrypt.hashSync('admin123', 10);
    d.prepare(
      'INSERT INTO admin_users (id, username, password_hash, role, name, permissions, is_active, created_at)' +
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    ).run(
      'admin-001', 'admin', hash, 'admin', '系统管理员',
      JSON.stringify(['*']), 1, Date.now()
    );
    console.log('[DB] Default admin created: admin / admin123');
  }

  console.log(`[DB] Initialized at ${DB_PATH}`);
}

export function closeDb(): void {
  if (db) {
    db.close();
    db = null;
  }
}

// ─── 管理员 CRUD ─────────────────────────────────────────────

export function createAdminUser(data: {
  id: string; username: string; password: string; role: 'admin' | 'sub';
  name: string; permissions?: string[];
}): AdminUser {
  const d = getDb();
  const bcrypt = require('bcryptjs');
  const hash = bcrypt.hashSync(data.password, 10);
  const permissions = JSON.stringify(data.permissions || []);
  const now = Date.now();
  d.prepare(
    'INSERT INTO admin_users (id, username, password_hash, role, name, permissions, is_active, created_at)' +
    ' VALUES (?, ?, ?, ?, ?, ?, 1, ?)'
  ).run(data.id, data.username, hash, data.role, data.name, permissions, now);
  const { password: _pw, ...safeData } = data;
  return { ...safeData, passwordHash: hash, permissions: JSON.parse(permissions), createdAt: now, isActive: true };
}

export function findAdminUserByUsername(username: string): AdminUser | undefined {
  const d = getDb();
  const row = d.prepare('SELECT * FROM admin_users WHERE username = ?').get(username) as any;
  if (!row) return undefined;
  return {
    ...row,
    permissions: JSON.parse(row.permissions || '[]'),
    passwordHash: row.password_hash,
    lastLoginAt: row.last_login_at,
    createdAt: row.created_at,
    isActive: !!row.is_active,
  };
}

export function updateAdminLastLogin(id: string): void {
  getDb().prepare('UPDATE admin_users SET last_login_at = ? WHERE id = ?').run(Date.now(), id);
}

export function listAdminUsers(): AdminUser[] {
  const d = getDb();
  return (d.prepare('SELECT id, username, role, name, permissions, is_active, last_login_at, created_at FROM admin_users ORDER BY created_at').all() as any[])
    .map(r => ({ ...r, permissions: JSON.parse(r.permissions || '[]') }));
}

// ─── 账户 CRUD ───────────────────────────────────────────────

export function insertAccount(data: { id: string; name: string; phone: string; exportFile: string; deviceId?: string; deviceConfigId?: string; assignedTo?: string; lastError?: string; lastConnectedAt?: number; connectionId?: string; status?: WhatsAppAccount['status']; tier?: 'A' | 'B' | 'C'; proxyUrl?: string }): WhatsAppAccount {
  const d = getDb();
  const now = Date.now();
  const id = data.id;
  d.prepare(
    'INSERT INTO accounts (id, name, phone, export_file, status, device_id, device_config_id,' +
    ' last_connected_at, last_error, assigned_to, message_count, connection_id, tier, proxy_url, created_at, updated_at)' +
    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(
    id, data.name, data.phone, data.exportFile,
    data.status || 'idle', data.deviceId, data.deviceConfigId,
    data.lastConnectedAt || null, data.lastError || null,
    data.assignedTo || null, 0, data.connectionId || null, data.tier || 'B', data.proxyUrl || null, now, now
  );
  return { ...data, status: data.status || 'idle', createdAt: now, updatedAt: now, messageCount: 0, tier: data.tier || 'B' } as WhatsAppAccount;
}

export function updateAccountStatus(id: string, status: WhatsAppAccount['status'], error?: string): void {
  const d = getDb();
  d.prepare(
    'UPDATE accounts SET status = ?, last_error = ?, updated_at = ? WHERE id = ?'
  ).run(status, error || null, Date.now(), id);
}

export function updateAccountConnection(id: string, connectionId?: string, lastConnectedAt?: number): void {
  const d = getDb();
  d.prepare(
    'UPDATE accounts SET connection_id = ?, last_connected_at = ?, status = ?, updated_at = ? WHERE id = ?'
  ).run(connectionId || null, lastConnectedAt || null, 'connected', Date.now(), id);
}

export function addMessageToAccount(id: string, count: number): void {
  getDb().prepare('UPDATE accounts SET message_count = message_count + ?, updated_at = ? WHERE id = ?').run(count, Date.now(), id);
}

export function getAccount(id: string): WhatsAppAccount | undefined {
  const d = getDb();
  const row = d.prepare('SELECT * FROM accounts WHERE id = ?').get(id) as any;
  if (!row) return undefined;
  return {
    ...row,
    exportFile: row.export_file,
    assignedTo: row.assigned_to,
    deviceConfigId: row.device_config_id,
    deviceId: row.device_id,
    lastConnectedAt: row.last_connected_at,
    lastError: row.last_error,
    connectionId: row.connection_id,
    messageCount: row.message_count,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    tier: row.tier || 'B',
    proxyUrl: row.proxy_url,
  };
}

export function listAccounts(filters?: { status?: string; assignedTo?: string; tier?: string }): WhatsAppAccount[] {
  const d = getDb();
  let sql = 'SELECT * FROM accounts';
  const params: any[] = [];
  const where: string[] = [];
  if (filters?.status) { where.push('status = ?'); params.push(filters.status); }
  if (filters?.assignedTo) { where.push('assigned_to = ?'); params.push(filters.assignedTo); }
  if (filters?.tier) { where.push('tier = ?'); params.push(filters.tier); }
  if (where.length) sql += ' WHERE ' + where.join(' AND ');
  sql += ' ORDER BY created_at DESC';
  return (d.prepare(sql).all(...params) as any[]).map(r => ({
    ...r,
    assignedTo: r.assigned_to,
    deviceConfigId: r.device_config_id,
    deviceId: r.device_id,
    lastConnectedAt: r.last_connected_at,
    lastError: r.last_error,
    connectionId: r.connection_id,
    messageCount: r.message_count,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
    tier: r.tier || 'B',
    proxyUrl: r.proxy_url,
  }));
}

export function assignAccount(accountId: string, userId: string): void {
  getDb().prepare('UPDATE accounts SET assigned_to = ?, updated_at = ? WHERE id = ?').run(userId, Date.now(), accountId);
}

export function updateAccountTier(id: string, tier: string): void {
  getDb().prepare('UPDATE accounts SET tier = ?, updated_at = ? WHERE id = ?').run(tier, Date.now(), id);
}

export function updateAccount(id: string, data: { name?: string; phone?: string; tier?: string; deviceConfigId?: string; assignedTo?: string; proxyUrl?: string }): void {
  const d = getDb();
  const sets: string[] = [];
  const params: any[] = [];
  if (data.name !== undefined)     { sets.push('name = ?');           params.push(data.name); }
  if (data.phone !== undefined)     { sets.push('phone = ?');          params.push(data.phone); }
  if (data.tier !== undefined)      { sets.push('tier = ?');           params.push(data.tier); }
  if (data.deviceConfigId !== undefined) { sets.push('device_config_id = ?'); params.push(data.deviceConfigId); }
  if (data.assignedTo !== undefined) { sets.push('assigned_to = ?');    params.push(data.assignedTo); }
  if (data.proxyUrl !== undefined)  { sets.push('proxy_url = ?');      params.push(data.proxyUrl); }
  if (sets.length) {
    sets.push('updated_at = ?');
    params.push(Date.now());
    params.push(id);
    d.prepare(`UPDATE accounts SET ${sets.join(', ')} WHERE id = ?`).run(...params);
  }
}

export function filterAccountsByTier(tier: string): WhatsAppAccount[] {
  return listAccounts({ tier });
}

export function removeAccount(id: string): boolean {
  const d = getDb();
  const result = d.prepare('DELETE FROM accounts WHERE id = ?').run(id);
  return result.changes > 0;
}

// ─── 设备配置 CRUD ──────────────────────────────────────────

export function insertDeviceConfig(config: DeviceConfig): DeviceConfig {
  const d = getDb();
  d.prepare(
    'INSERT INTO device_configs (id, name, browser, platform, model, os_version, user_agent,' +
    ' locale, timezone, screen_width, screen_height, dpi, created_at)' +
    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(
    config.id, config.name, JSON.stringify(config.browser), config.platform, config.model,
    config.osVersion, config.userAgent, config.locale, config.timezone,
    config.screenWidth, config.screenHeight, config.dpi, config.createdAt
  );
  return config;
}

export function getDeviceConfig(id: string): DeviceConfig | undefined {
  const d = getDb();
  const row = d.prepare('SELECT * FROM device_configs WHERE id = ?').get(id) as any;
  if (!row) return undefined;
  return { ...row, browser: JSON.parse(row.browser) };
}

export function listDeviceConfigs(): DeviceConfig[] {
  const d = getDb();
  return (d.prepare('SELECT * FROM device_configs ORDER BY created_at DESC').all() as any[])
    .map(r => ({ ...r, browser: JSON.parse(r.browser) }));
}

export function deleteDeviceConfig(id: string): boolean {
  return getDb().prepare('DELETE FROM device_configs WHERE id = ?').run(id).changes > 0;
}

// ─── 聊天消息 CRUD ───────────────────────────────────────────

export function insertMessages(messages: ChatMessage[]): void {
  const d = getDb();
  const insert = d.prepare(
    'INSERT INTO chat_messages (id, account_id, jid, from_me, timestamp, body, type,' +
    ' translated_body, translation_source, translation_target_lang, created_at)' +
    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  );
  const batch = d.transaction((msgs: ChatMessage[]) => {
    for (const m of msgs) {
      insert.run(m.id, m.accountId, m.jid, m.fromMe ? 1 : 0, m.timestamp, m.body, m.type,
        m.translatedBody || null, m.translationSource || null, m.translationTargetLang || null, Date.now());
    }
  });
  batch(messages);
}

export function getChatHistory(query: {
  accountId: string; jid?: string; fromTime?: number; toTime?: number;
  limit?: number; offset?: number; type?: string;
}): { messages: ChatMessage[]; total: number } {
  const d = getDb();
  const parts: string[] = ['WHERE account_id = ?'];
  const params: any[] = [query.accountId];

  if (query.jid) { parts.push('jid = ?'); params.push(query.jid); }
  if (query.fromTime) { parts.push('timestamp >= ?'); params.push(query.fromTime); }
  if (query.toTime) { parts.push('timestamp <= ?'); params.push(query.toTime); }
  if (query.type) { parts.push('type = ?'); params.push(query.type); }

  const where = parts.join(' AND ');
  const countRow = d.prepare(`SELECT COUNT(*) as cnt FROM chat_messages ${where}`).get(...params) as { cnt: number };
  const total = countRow.cnt;

  params.push(query.limit || 50, query.offset || 0);
  const rows = d.prepare(
    `SELECT * FROM chat_messages ${where} ORDER BY timestamp DESC LIMIT ? OFFSET ?`
  ).all(...params) as any[];

  return {
    messages: rows.map(r => ({ ...r, fromMe: !!r.from_me })),
    total,
  };
}

export function getConversations(accountId: string, limit = 50): Conversation[] {
  const d = getDb();
  const rows = d.prepare(
    `SELECT jid, COUNT(*) as msg_count, MAX(timestamp) as last_ts FROM chat_messages` +
    ` WHERE account_id = ? GROUP BY jid ORDER BY last_ts DESC LIMIT ?`
  ).all(accountId, limit) as any[];

  return rows.map(r => ({
    jid: r.jid,
    name: r.jid.split('@')[0],
    messageCount: r.msg_count,
    unreadCount: 0,
    isGroup: r.jid.includes('@g.us'),
    lastMessage: undefined as any,
  }));
}

export function countMessagesByAccount(): Record<string, number> {
  const d = getDb();
  const rows = d.prepare(
    'SELECT account_id, COUNT(*) as cnt FROM chat_messages GROUP BY account_id'
  ).all() as any[];
  return Object.fromEntries(rows.map(r => [r.account_id, r.cnt]));
}

// ─── 批量任务 CRUD ───────────────────────────────────────────

export function insertTask(task: { id: string; type: string; name: string; status: string; accountIds?: string[]; params?: Record<string, any>; progress?: number; total?: number; success?: number; failed?: number; error?: string; startedAt?: number; completedAt?: number; createdBy?: string }): import('../types').BatchTask {
  const d = getDb();
  const now = Date.now();
  d.prepare(
    'INSERT INTO batch_tasks (id, type, name, status, account_ids, params,' +
    ' progress, total, success, failed, error, created_at, started_at, completed_at, updated_at, created_by)' +
    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(
    task.id, task.type, task.name, task.status,
    JSON.stringify(task.accountIds || []), JSON.stringify(task.params || {}),
    task.progress ?? 0, task.total ?? 0, task.success ?? 0, task.failed ?? 0,
    task.error || null, now, task.startedAt || null, task.completedAt || null,
    Date.now(), task.createdBy || null
  );
  return { ...task, id: task.id, progress: task.progress ?? 0, success: task.success ?? 0, failed: task.failed ?? 0, createdAt: now } as any;
}

export function updateTaskProgress(id: string, updates: Partial<Pick<BatchTask, 'status' | 'progress' | 'success' | 'failed' | 'error' | 'startedAt' | 'completedAt'>>): void {
  const d = getDb();
  const sets: string[] = [];
  const params: any[] = [];
  if (updates.status !== undefined) { sets.push('status = ?'); params.push(updates.status); }
  if (updates.progress !== undefined) { sets.push('progress = ?'); params.push(updates.progress); }
  if (updates.success !== undefined) { sets.push('success = ?'); params.push(updates.success); }
  if (updates.failed !== undefined) { sets.push('failed = ?'); params.push(updates.failed); }
  if (updates.error !== undefined) { sets.push('error = ?'); params.push(updates.error); }
  if (updates.startedAt !== undefined) { sets.push('started_at = ?'); params.push(updates.startedAt); }
  if (updates.completedAt !== undefined) { sets.push('completed_at = ?'); params.push(updates.completedAt); }
  if (sets.length) {
    d.prepare(`UPDATE batch_tasks SET ${sets.join(', ')} WHERE id = ?`).run(...params, id);
  }
}

export function getTask(id: string): BatchTask | undefined {
  const d = getDb();
  const row = d.prepare('SELECT * FROM batch_tasks WHERE id = ?').get(id) as any;
  if (!row) return undefined;
  return { ...row, accountIds: JSON.parse(row.account_ids), params: JSON.parse(row.params) };
}

export function listTasks(limit = 50): BatchTask[] {
  const d = getDb();
  const rows = d.prepare('SELECT * FROM batch_tasks ORDER BY created_at DESC LIMIT ?').all(limit) as any[];
  return rows.map(r => ({ ...r, accountIds: JSON.parse(r.account_ids), params: JSON.parse(r.params) }));
}

// ─── 审计日志 ────────────────────────────────────────────────

export function logAudit(entry: Omit<AuditLog, 'id' | 'createdAt'>): void {
  const d = getDb();
  const { v4: uuidv4 } = require('uuid');
  d.prepare(
    'INSERT INTO audit_logs (id, user_id, action, target_type, target_id, details, ip, user_agent, created_at)' +
    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(uuidv4(), entry.userId, entry.action, entry.targetType, entry.targetId, entry.details, entry.ip, entry.userAgent, Date.now());
}

export function getAuditLogs(filters?: { userId?: string; action?: string; limit?: number }): AuditLog[] {
  const d = getDb();
  let sql = 'SELECT * FROM audit_logs';
  const params: any[] = [];
  const where: string[] = [];
  if (filters?.userId) { where.push('user_id = ?'); params.push(filters.userId); }
  if (filters?.action) { where.push('action = ?'); params.push(filters.action); }
  if (where.length) sql += ' WHERE ' + where.join(' AND ');
  sql += ' ORDER BY created_at DESC LIMIT ' + (filters?.limit || 100);
  return d.prepare(sql).all(...params) as AuditLog[];
}

// ─── 统计 ────────────────────────────────────────────────────

export function getPlatformStats(): {
  totalAccounts: number; connectedAccounts: number; bannedAccounts: number;
  totalMessages: number; totalTasks: number; activeTasks: number;
  totalUsers: number; subUsers: number;
} {
  const d = getDb();
  const acct = d.prepare("SELECT COUNT(*) as c FROM accounts").get() as { c: number };
  const conn = d.prepare("SELECT COUNT(*) as c FROM accounts WHERE status = 'connected'").get() as { c: number };
  const banned = d.prepare("SELECT COUNT(*) as c FROM accounts WHERE status = 'banned'").get() as { c: number };
  const msgs = d.prepare("SELECT COALESCE(SUM(cnt), 0) as c FROM (SELECT COUNT(*) as cnt FROM chat_messages GROUP BY account_id)").get() as { c: number };
  const tasks = d.prepare("SELECT COUNT(*) as c FROM batch_tasks").get() as { c: number };
  const active = d.prepare("SELECT COUNT(*) as c FROM batch_tasks WHERE status IN ('pending', 'running')").get() as { c: number };
  const users = d.prepare("SELECT COUNT(*) as c FROM admin_users").get() as { c: number };
  const subs = d.prepare("SELECT COUNT(*) as c FROM admin_users WHERE role = 'sub'").get() as { c: number };
  return {
    totalAccounts: acct.c, connectedAccounts: conn.c, bannedAccounts: banned.c,
    totalMessages: msgs.c, totalTasks: tasks.c, activeTasks: active.c,
    totalUsers: users.c, subUsers: subs.c,
  };
}
