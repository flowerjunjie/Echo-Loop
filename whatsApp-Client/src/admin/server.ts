/**
 * Admin REST API Server
 *
 * Endpoints for:
 * 1. 批量登号管理
 * 2. 账户连接/断开
 * 3. 消息发送
 * 4. 聊天历史查询
 * 5. 设备/代理配置
 * 6. 翻译服务控制
 * 7. 子账号管理
 * 8. 批量任务调度
 * 9. 审计日志
 */

// @ts-nocheck
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import http from 'http';
import path from 'path';
import { WebSocketServer, WebSocket } from 'ws';
import type { IncomingMessage } from 'http';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../logger';

// ─── DB imports ──────────────────────────────────────────────
import { initDb, closeDb, listAccounts, getAccount, insertAccount,
  updateAccountStatus, updateAccountConnection,
  listDeviceConfigs, getDeviceConfig, insertDeviceConfig, deleteDeviceConfig,
  listAdminUsers, createAdminUser, findAdminUserByUsername,
  updateAdminLastLogin, getChatHistory, getConversations,
  insertMessages, insertTask, getTask, listTasks,
  updateTaskProgress, getPlatformStats, logAudit, getAuditLogs,
  assignAccount, removeAccount,
} from '../db';
import { exportChatHistory } from '../services/chat-history';
import { login, register, verifyToken, isAdmin, hasPermission } from '../auth';
import { sessionManager } from '../services/session-manager';

// WebSocket broadcast helper (inline to avoid circular deps)
function wsBroadcast(event, payload) {
  // Access connectedClients from wss (hack but works for now)
  const msg = JSON.stringify({ type: event, payload, timestamp: Date.now() });
  // We'll use a simpler approach: export from server and import in session-manager
}
import { startTaskPolling, stopTaskPolling } from '../workers/batch-worker';
import { buildAuthenticationState } from '../baileys-auth-builder';
import { loadExport } from '../export-loader';
import { parseWhatsAppExport } from '../key-parser';
import { generateDeviceProfile, setProxyList, proxyList, addProxy, getRandomProxy } from '../services/device-spoof';
import { setTranslationConfig, getTranslationConfig, setProviderApiKey } from '../services/translation';
import { storeMessages } from '../services/chat-history';
import { createBackup, listBackups, deleteBackup, restoreBackup } from '../services/backup';
import { scheduleTask, unscheduleTask, listScheduledTasks, getSchedulerStats } from '../services/scheduler';
import { createTemplate, getTemplate, listTemplates, deleteTemplate, renderTemplate } from '../services/template';
import { broadcastAll, broadcastToUser } from './server'; // circular, will fix
import { translateText } from '../services/translation';

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// Rate limiters — 本地管理后台适度宽松，防止测试封号但允许正常重试
const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 30,
  message: { success: false, error: '请求过于频繁，请稍后重试' },
  standardHeaders: true,
  legacyHeaders: false,
});
const generalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 200,
  message: { success: false, error: '请求过于频繁' },
});

// Middleware
app.use(cors({ origin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : undefined }));
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  crossOriginOpenerPolicy: false,
  crossOriginEmbedderPolicy: false,
}));
app.use(express.json({ limit: '10mb' }));

// ─── 初始化 ──────────────────────────────────────────────────

initDb();
startTaskPolling(3000);
setupWebSocket();

// Auto-configure local SOCKS5 proxy if available (common in China)
const { getRandomProxy, addProxy } = require('../services/device-spoof');
const localProxy = process.env.WA_PROXY_URL || 'socks5://127.0.0.1:10808';
addProxy({ url: localProxy, type: 'socks5', ip: '127.0.0.1', country: 'local' });
logger.info(`[Server] Proxy configured: ${localProxy}`);

// ─── Auth 中间件 ─────────────────────────────────────────────

function authMiddleware(req: any, res: any, next: any): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ success: false, error: '未授权' });
    return;
  }
  try {
    const payload = verifyToken(authHeader.slice(7));
    (req as any).user = payload;
    next();
  } catch {
    res.status(401).json({ success: false, error: 'Token 无效或已过期' });
  }
}

function requireAdmin(req: any, res: any, next: any): void {
  if (!isAdmin((req as any).user)) {
    res.status(403).json({ success: false, error: '需要管理员权限' });
    return;
  }
  next();
}

// ─── 登录/注册 ───────────────────────────────────────────────

app.post('/api/auth/login', authLimiter, async (req, res) => {
  try {
    const { username, password } = req.body;
    const result = await login(username, password, req.ip, req.headers['user-agent']);
    res.json({ success: true, data: result });
  } catch (err) {
    res.status(401).json({ success: false, error: err instanceof Error ? err.message : '登录失败' });
  }
});

app.post('/api/auth/register', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const user = await register(req.body);
    logAudit({ userId: (req as any).user.userId, action: 'register_user', targetType: 'user', targetId: user.id, details: `Registered user: ${user.username}` });
    const { passwordHash: _ph, ...safe } = user;
    res.json({ success: true, data: safe });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '注册失败' });
  }
});

// ─── 平台统计 ────────────────────────────────────────────────

app.get('/api/health', (req, res) => { res.json({ success: true, data: { status: 'ok', uptime: process.uptime() } }); });
app.get('/api/stats', generalLimiter, authMiddleware, (req, res) => {
  const stats = getPlatformStats();
  res.json({ success: true, data: stats });
});

// ─── 账户管理 ────────────────────────────────────────────────

app.get('/api/accounts', authMiddleware, (req, res) => {
  const filters: any = {};
  if (req.query.status) filters.status = req.query.status;
  if (!(req as any).user || (req as any).user.role === 'sub') {
    filters.assignedTo = (req as any).user.userId;
  }
  const accounts = listAccounts(filters);
  res.json({ success: true, data: accounts });
});

app.post('/api/accounts', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { name, phone, exportFile, deviceConfigId, assignedTo } = req.body;
    const exportData = await loadExport(exportFile);
    const parsed = parseWhatsAppExport(exportData);
    const account = {
      id: `acct-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      name: name || parsed.nickname || exportData.account,
      phone: phone || parsed.account,
      exportFile,
      status: 'idle',
      deviceId: parsed.deviceId,
      deviceConfigId: deviceConfigId || '',
      assignedTo: assignedTo || null,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      messageCount: 0,
    };
    insertAccount(account);
    logAudit({ userId: (req as any).user.userId, action: 'create_account', targetType: 'account', targetId: account.id, details: `Created account: ${account.name}${assignedTo ? ' → user ' + assignedTo : ''}` });
    res.json({ success: true, data: account });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '创建失败' });
  }
});

app.post('/api/accounts/:id/connect', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const account = getAccount(id);
    if (!account) { res.status(404).json({ success: false, error: '账户不存在' }); return; }

    const exportData = await loadExport(account.exportFile);
    const parsed = parseWhatsAppExport(exportData);
    const authState = buildAuthenticationState({ parsed });

    const config: any = { authState };
    const deviceConfig = getDeviceConfig(account.deviceConfigId);
    if (deviceConfig) config.deviceConfig = deviceConfig;

    // Auto-assign proxy if available
    const proxy = getRandomProxy();
    if (proxy) {
      config.proxyUrl = proxy.url;
      proxy.lastUsedAt = Date.now();
    }

    await sessionManager.connect(account, config);
    res.json({ success: true, data: { accountId: id, status: 'connecting' } });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : '连接失败' });
  }
});

app.post('/api/accounts/:id/disconnect', authMiddleware, requireAdmin, async (req, res) => {
  try {
    await sessionManager.disconnect(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : '断开失败' });
  }
});

app.delete('/api/accounts/:id', authMiddleware, requireAdmin, (req, res) => {
  // Remove account from DB
  removeAccount(req.params.id);
  sessionManager.disconnect(req.params.id).catch(() => {});
  res.json({ success: true });
});

// ─── 批量登号 ────────────────────────────────────────────────

app.post('/api/tasks/login', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { name, exportFiles, deviceConfigs, concurrent, delayBetween, autoConnect } = req.body;
    const taskId = `task-${Date.now()}`;
    const task = insertTask({
      id: taskId,
      type: 'login',
      name: name || '批量登录',
      status: 'pending',
      accountIds: [],
      params: { exportFiles, deviceConfigs, concurrent, delayBetween, autoConnect },
      total: exportFiles?.length || 0,
      createdBy: (req as any).user.userId,
    });
    res.json({ success: true, data: task });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '创建任务失败' });
  }
});

// ─── 发消息 ──────────────────────────────────────────────────

app.post('/api/accounts/:id/messages', authMiddleware, async (req, res) => {
  try {
    const { jid, content } = req.body;
    const result = await sessionManager.sendMessage(req.params.id, jid, content);
    res.json({ success: true, data: { messageId: result } });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '发送失败' });
  }
});

app.post('/api/tasks/send_message', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { name, accountIds, targetJids, message, delayMs, randomized, maxRetries } = req.body;
    const taskId = `task-${Date.now()}`;
    const task = insertTask({
      id: taskId,
      type: 'send_message',
      name: name || '批量发消息',
      status: 'pending',
      accountIds,
      params: { targetJids, message, delayMs: delayMs || 2000, randomized: randomized || true, maxRetries },
      total: accountIds?.length || 0,
      createdBy: (req as any).user.userId,
    });
    res.json({ success: true, data: task });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '创建任务失败' });
  }
});

// ─── 聊天农场 ────────────────────────────────────────────────

app.post('/api/tasks/chat_farm', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { name, accountIds, targetJids, messages } = req.body;
    const taskId = `task-${Date.now()}`;
    insertTask({
      id: taskId,
      type: 'chat_farm',
      name: name || '聊天农场',
      status: 'pending',
      accountIds,
      params: { targetJids, messages },
      total: accountIds?.length || 0,
      createdBy: (req as any).user.userId,
    });
    res.json({ success: true, data: { id: taskId } });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '创建失败' });
  }
});

// ─── 聊天历史 ────────────────────────────────────────────────

app.get('/api/accounts/:id/conversations', authMiddleware, (req: Request, res: Response) => {
  const convs = getConversations(req.params.id, 50);
  res.json({ success: true, data: convs });
});

app.get('/api/accounts/:id/history', authMiddleware, (req, res) => {
  const query = {
    accountId: req.params.id,
    jid: req.query.jid as string | undefined,
    fromTime: req.query.fromTime ? Number(req.query.fromTime) : undefined,
    toTime: req.query.toTime ? Number(req.query.toTime) : undefined,
    limit: Number(req.query.limit) || 50,
    offset: Number(req.query.offset) || 0,
    type: req.query.type as string | undefined,
  };
  const result = getChatHistory(query);
  res.json({ success: true, data: result.messages, meta: { total: result.total, page: query.offset / query.limit + 1 } });
});

app.get('/api/accounts/:id/export', authMiddleware, (req, res) => {
  const format = req.query.format as string || 'json';
  const content = exportChatHistory(req.params.id, format as any);
  res.setHeader('Content-Type', format === 'csv' ? 'text/csv' : 'application/json');
  res.setHeader('Content-Disposition', `attachment; filename="chat_history_${req.params.id}.${format}"`);
  res.send(content);
});

// ─── 翻译 ────────────────────────────────────────────────────

app.get('/api/translation/config', authMiddleware, (req, res) => {
  res.json({ success: true, data: getTranslationConfig() });
});

app.put('/api/translation/config', authMiddleware, (req, res) => {
  setTranslationConfig(req.body);
  res.json({ success: true });
});

app.post('/api/translation/providers/:provider/key', authMiddleware, (req, res) => {
  setProviderApiKey(req.params.provider as any, req.body.key);
  res.json({ success: true });
});

app.post('/api/translation/translate', authMiddleware, async (req, res) => {
  try {
    const { text, targetLang } = req.body;
    const result = await translateText(text, targetLang);
    res.json({ success: true, data: { original: text, translated: result } });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : '翻译失败' });
  }
});

// ─── 设备配置 ────────────────────────────────────────────────

app.get('/api/devices', authMiddleware, (req, res) => {
  const devices = listDeviceConfigs();
  res.json({ success: true, data: devices });
});

app.post('/api/devices', authMiddleware, requireAdmin, (req, res) => {
  const config = generateDeviceProfile();
  config.name = req.body.name || config.name;
  if (req.body.platform) config.platform = req.body.platform;
  if (req.body.model) config.model = req.body.model;
  if (req.body.userAgent) config.userAgent = req.body.userAgent;
  if (req.body.locale) config.locale = req.body.locale;
  if (req.body.timezone) config.timezone = req.body.timezone;
  insertDeviceConfig(config);
  logAudit({ userId: (req as any).user.userId, action: 'create_device', targetType: 'config', targetId: config.id, details: `Created device: ${config.name}` });
  res.json({ success: true, data: config });
});

app.post('/api/devices/generate', authMiddleware, requireAdmin, (req, res) => {
  const count = req.body.count || 1;
  const devices = [];
  for (let i = 0; i < count; i++) {
    const config = generateDeviceProfile();
    config.name = req.body.prefix ? `${req.body.prefix}-${i + 1}` : config.name;
    insertDeviceConfig(config);
    devices.push(config);
  }
  res.json({ success: true, data: devices });
});

app.delete('/api/devices/:id', authMiddleware, requireAdmin, (req, res) => {
  deleteDeviceConfig(req.params.id);
  res.json({ success: true });
});

// ─── 代理配置 ────────────────────────────────────────────────

app.get('/api/proxies', authMiddleware, (req, res) => {
  res.json({ success: true, data: proxyList });
});

app.post('/api/proxies', authMiddleware, requireAdmin, (req, res) => {
  addProxy(req.body);
  res.json({ success: true });
});

app.post('/api/proxies/batch', authMiddleware, requireAdmin, (req, res) => {
  setProxyList(req.body.proxies || []);
  res.json({ success: true });
});

// ─── 子账号管理 ──────────────────────────────────────────────

app.get('/api/users', authMiddleware, requireAdmin, (req, res) => {
  const users = listAdminUsers();
  res.json({ success: true, data: users });
});

app.post('/api/users/assign', authMiddleware, requireAdmin, async (req, res) => {
  const { accountId, userId } = req.body;
  assignAccount(accountId, userId);
  logAudit({ userId: (req as any).user.userId, action: 'assign_account', targetType: 'account', targetId: accountId, details: `Assigned account to user ${userId}` });
  res.json({ success: true });
});

app.get('/api/users/:userId/activity', authMiddleware, requireAdmin, (req, res) => {
  const logs = getAuditLogs({ userId: req.params.userId, limit: 100 });
  res.json({ success: true, data: logs });
});

// ─── 批量任务控制 ────────────────────────────────────────────

app.post('/api/tasks/pause', authMiddleware, requireAdmin, (req, res) => {
  const { pauseTasks } = require('../workers/batch-worker');
  pauseTasks();
  logAudit({ userId: (req as any).user.userId, action: 'pause_tasks', targetType: 'task', targetId: 'all', details: 'Task polling paused' });
  res.json({ success: true });
});

app.post('/api/tasks/resume', authMiddleware, requireAdmin, (req, res) => {
  const { resumeTasks } = require('../workers/batch-worker');
  resumeTasks();
  logAudit({ userId: (req as any).user.userId, action: 'resume_tasks', targetType: 'task', targetId: 'all', details: 'Task polling resumed' });
  res.json({ success: true });
});

app.get('/api/tasks/paused', authMiddleware, (req, res) => {
  const { isTaskPaused } = require('../workers/batch-worker');
  res.json({ success: true, data: { paused: isTaskPaused() } });
});

// ─── 批量任务

app.get('/api/tasks', authMiddleware, (req, res) => {
  const tasks = listTasks(50);
  res.json({ success: true, data: tasks });
});

app.get('/api/tasks/:id', authMiddleware, (req, res) => {
  const task = getTask(req.params.id);
  if (!task) { res.status(404).json({ success: false, error: 'Task not found' }); return; }
  res.json({ success: true, data: task });
});

// ─── 审计日志 ────────────────────────────────────────────────

app.get('/api/audit', authMiddleware, requireAdmin, (req, res) => {
  const logs = logAudit ? getAuditLogs({ limit: 200 }) : [];
  res.json({ success: true, data: logs });
});

// ─── WebSocket ───────────────────────────────────────────────

function setupWebSocket(): void {
  wss.on('connection', (ws: WebSocket, req: IncomingMessage) => {
    const token = req.url?.split('token=')[1];
    if (!token) { ws.close(4001, 'No token'); return; }

    try {
      const payload = verifyToken(token);
      allClients.add(ws);
      if (!clientByUser.has(payload.userId)) clientByUser.set(payload.userId, new Set());
      clientByUser.get(payload.userId)!.add(ws);
      logger.info(`[WS] Client connected: ${payload.username} (${payload.userId})`);

      ws.on('message', (data: string) => {
        try {
          const msg = JSON.parse(data);
          handleWSMessage(ws, msg, payload);
        } catch {}
      });

      ws.on('close', () => {
        removeClient(ws, payload.userId);
        logger.info('[WS] Client disconnected');
      });
      ws.on('error', () => {
        removeClient(ws);
      });
    } catch {
      ws.close(4001, 'Invalid token');
    }
  });
}

function handleWSMessage(ws: WebSocket, msg: any, user: any): void {
  switch (msg.type) {
    case 'subscribe':
      ws.subscription = msg.channel || 'all';
      if (msg.channel === 'admin') {
        // Admin subscribes to all events
      }
      break;
    case 'ping':
      ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
      break;
  }
}


// ─── CSV联系人导入 ────────────────────────────────────────

app.post('/api/contacts/import', authMiddleware, (req, res) => {
  try {
    const { content, delimiter = ',' } = req.body;
    if (!content) { res.status(400).json({ success: false, error: '缺少内容' }); return; }

    const lines = content.trim().split(/\r?\n/);
    const header = lines[0].split(delimiter).map(h => h.trim().toLowerCase());
    const phoneIdx = header.findIndex(h => h.includes('phone') || h.includes('tel') || h.includes('号码'));
    const nameIdx = header.findIndex(h => h.includes('name') || h.includes('name') || h.includes('姓名'));

    if (phoneIdx === -1) {
      res.status(400).json({ success: false, error: 'CSV需包含电话号码列' });
      return;
    }

    const contacts = lines.slice(1).filter(l => l.trim()).map(line => {
      const cols = line.split(delimiter);
      return {
        phone: cols[phoneIdx]?.trim() || '',
        name: nameIdx >= 0 ? cols[nameIdx]?.trim() || '' : '',
      };
    }).filter(c => c.phone);

    res.json({ success: true, data: { count: contacts.length, contacts } });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '解析失败' });
  }
});




// ─── 消息模板 ──────────────────────────────────────────────

app.post('/api/templates', authMiddleware, requireAdmin, (req, res) => {
  try {
    const tmpl = createTemplate(req.body);
    res.json({ success: true, data: tmpl });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '创建失败' });
  }
});

app.get('/api/templates', authMiddleware, (req, res) => {
  res.json({ success: true, data: listTemplates() });
});

app.get('/api/templates/:id', authMiddleware, (req, res) => {
  const tmpl = getTemplate(req.params.id);
  if (!tmpl) { res.status(404).json({ success: false, error: '模板不存在' }); return; }
  res.json({ success: true, data: tmpl });
});

app.delete('/api/templates/:id', authMiddleware, requireAdmin, (req, res) => {
  res.json({ success: deleteTemplate(req.params.id) });
});

app.post('/api/templates/:id/render', authMiddleware, (req, res) => {
  try {
    const rendered = renderTemplate(req.params.id, req.body.variables || {});
    res.json({ success: true, data: { rendered } });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '渲染失败' });
  }
});

// ─── 定时任务 ──────────────────────────────────────────────

app.post('/api/scheduler/tasks', authMiddleware, requireAdmin, (req, res) => {
  try {
    const { name, cron, taskType, params } = req.body;
    const id = scheduleTask({ id: req.body.id, name, cron, taskType, params: params || {}, enabled: true });
    res.json({ success: true, data: { id, name } });
  } catch (err) {
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : '创建失败' });
  }
});

app.delete('/api/scheduler/tasks/:id', authMiddleware, requireAdmin, (req, res) => {
  const deleted = unscheduleTask(req.params.id);
  res.json({ success: deleted });
});

app.get('/api/scheduler/tasks', authMiddleware, (req, res) => {
  const tasks = listScheduledTasks();
  const stats = getSchedulerStats();
  res.json({ success: true, data: { tasks, stats } });
});

// ─── 数据库备份 ────────────────────────────────────────────

app.post('/api/backup/create', authMiddleware, requireAdmin, (req, res) => {
  try {
    const desc = req.body.description || 'manual';
    const result = createBackup(desc);
    logAudit({ userId: (req as any).user.userId, action: 'backup_create', targetType: 'config', targetId: 'db', details: `Created backup: ${path.basename(result)}` });
    res.json({ success: true, data: { path: result, name: path.basename(result) } });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : '备份失败' });
  }
});

app.get('/api/backup/list', authMiddleware, requireAdmin, (req, res) => {
  const backups = listBackups();
  res.json({ success: true, data: backups });
});

app.delete('/api/backup/:filename', authMiddleware, requireAdmin, (req, res) => {
  const deleted = deleteBackup(decodeURIComponent(req.params.filename));
  res.json({ success: deleted });
});

app.post('/api/backup/restore/:filename', authMiddleware, requireAdmin, (req, res) => {
  try {
    restoreBackup(decodeURIComponent(req.params.filename));
    logAudit({ userId: (req as any).user.userId, action: 'backup_restore', targetType: 'config', targetId: 'db', details: `Restored from: ${req.params.filename}` });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : '恢复失败' });
  }
});

// ─── 静态文件服务
const publicDir = path.join(__dirname, 'public');
app.use(express.static(publicDir));

// ─── 启动 ────────────────────────────────────────────────────

const PORT = parseInt(process.env.PORT || '3456');
server.listen(PORT, () => {
  logger.info(`[AdminServer] Admin API running on http://0.0.0.0:${PORT}`);
  logger.info(`[AdminServer] WebSocket on ws://0.0.0.0:${PORT}/ws`);
  logger.info(`[AdminServer] Default admin: admin / admin123`);
  logger.info(`[AdminServer] UI: http://localhost:${PORT}`);
});

// Graceful shutdown
// WebSocket实时推送: userId -> Set<ws> + 全局广播用
const clientByUser = new Map<string, Set<WebSocket>>();
const allClients = new Set<WebSocket>();

export function broadcastToUser(userId: string, event: string, payload: any): void {
  const clients = clientByUser.get(userId);
  if (!clients) return;
  const msg = JSON.stringify({ type: event, payload, timestamp: Date.now() });
  for (const ws of clients) {
    if (ws.readyState === 1) ws.send(msg); // WebSocket.OPEN
  }
}

export function broadcastAll(event: string, payload: any): void {
  const msg = JSON.stringify({ type: event, payload, timestamp: Date.now() });
  for (const ws of allClients) {
    if (ws.readyState === 1) ws.send(msg);
  }
}

export function removeClient(ws: WebSocket, userId?: string): void {
  allClients.delete(ws);
  if (userId && clientByUser.has(userId)) {
    clientByUser.get(userId)!.delete(ws);
    if (clientByUser.get(userId)!.size === 0) clientByUser.delete(userId);
  }
}
function broadcastClose(): void {
  for (const client of connectedClients) {
    try { client.close(1001, 'Server shutting down'); } catch {}
  }
  connectedClients.clear();
}

process.on('SIGINT', () => {
  logger.info('[AdminServer] Shutting down...');
  stopTaskPolling();
  broadcastClose();
  closeDb();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000); // Force exit after 5s
});

process.on('SIGTERM', () => {
  process.emit('SIGINT');
});

export { app, server };
