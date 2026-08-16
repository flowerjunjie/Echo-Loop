/**
 * 平台类型定义
 *
 * 覆盖：账户、管理员、子账号、代理设备、翻译配置等核心类型
 */

// ─── 账户相关 ────────────────────────────────────────────────

export interface AccountDeviceConfig {
  id: string;
  browser: [string, string, string];
  platform: string;
  model: string;
  osVersion: string;
  ipAddress?: string;
  proxyUrl?: string;
  userAgent?: string;
  locale?: string;
  timezone?: string;
  screenWidth?: number;
  screenHeight?: number;
  dpi?: number;
}

export interface WhatsAppAccount {
  id: string;
  name: string;
  phone: string;
  exportFile: string;
  status: 'idle' | 'connecting' | 'connected' | 'disconnected' | 'banned' | 'error' | 'pairing';
  deviceId: string;
  deviceConfigId: string;
  lastConnectedAt?: number;
  lastError?: string;
  assignedTo?: string; // 分配给哪个子账号
  createdAt: number;
  updatedAt: number;
  messageCount: number;
  connectionId?: string;
  tier: 'A' | 'B' | 'C';
  proxyUrl?: string;
}

export interface DeviceConfig {
  id: string;
  name: string;
  browser: [string, string, string];
  platform: string;
  model: string;
  osVersion: string;
  userAgent: string;
  locale: string;
  timezone: string;
  screenWidth: number;
  screenHeight: number;
  dpi: number;
  createdAt: number;
}

// ─── 管理员/子账号相关 ────────────────────────────────────────

export interface AdminUser {
  id: string;
  username: string;
  passwordHash: string;
  role: 'admin' | 'sub';
  name: string;
  permissions: string[];
  isActive: boolean;
  lastLoginAt?: number;
  createdAt: number;
}

export interface SubAccountSession {
  accountId: string;
  userId: string;
  connectedAt: number;
  status: 'online' | 'offline' | 'paused';
  lastActivityAt: number;
}

// ─── 消息/聊天相关 ────────────────────────────────────────────

export interface ChatMessage {
  id: string;
  accountId: string;
  jid: string;
  fromMe: boolean;
  timestamp: number;
  body: string;
  type: 'text' | 'image' | 'video' | 'audio' | 'document' | 'sticker' | 'ptt' | 'unknown';
  translatedBody?: string;
  translationSource?: string;
  translationTargetLang?: string;
}

export interface Conversation {
  jid: string;
  name?: string;
  lastMessage?: ChatMessage;
  messageCount: number;
  unreadCount: number;
  participants?: string[];
  isGroup: boolean;
}

export interface ChatHistoryQuery {
  accountId: string;
  jid?: string;
  fromTime?: number;
  toTime?: number;
  limit?: number;
  offset?: number;
  type?: string;
}

// ─── 翻译相关 ────────────────────────────────────────────────

export type TranslationProvider = 'google' | 'deepl' | 'openai' | 'deepseek' | 'custom';

export interface TranslationConfig {
  enabled: boolean;
  provider: TranslationProvider;
  targetLang: string; // e.g. 'zh', 'en', 'ja', 'ko'
  apiKey?: string;
  baseUrl?: string;
  autoDetect: boolean;
  minMessageLength: number; // 少于这个长度不翻译
  batchSize: number; // 批量翻译条数
}

export interface TranslationJob {
  id: string;
  accountId: string;
  messages: ChatMessage[];
  status: 'pending' | 'translating' | 'done' | 'failed';
  createdAt: number;
  completedAt?: number;
}

// ─── 批量任务相关 ────────────────────────────────────────────

export type BatchTaskType = 'login' | 'send_message' | 'chat_farm' | 'sync_history' | 'migrate_accounts';

export interface BatchTask {
  id: string;
  type: BatchTaskType;
  name: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'paused';
  accountIds: string[];
  params: Record<string, any>;
  progress: number; // 0-100
  total: number;
  success: number;
  failed: number;
  error?: string;
  createdAt: number;
  startedAt?: number;
  completedAt?: number;
  createdBy?: string;
}

export interface BatchSendMessageParam {
  targetJids: string[];
  message: string;
  delayMs: number;
  randomized: boolean;
  maxRetries: number;
}

export interface BatchLoginParam {
  exportFiles: string[];
  deviceConfigs: string[];
  concurrent: number;
  delayBetween: number;
  autoConnect: boolean;
}

// ─── 审计日志 ────────────────────────────────────────────────

export interface AuditLog {
  id: string;
  userId: string;
  action: string;
  targetType: 'account' | 'task' | 'user' | 'config';
  targetId: string;
  details: string;
  ip?: string;
  userAgent?: string;
  createdAt: number;
}

// ─── WebSocket 事件 ──────────────────────────────────────────

export interface WSMessage {
  type: string;
  payload: any;
  timestamp: number;
}

export type WSEventType =
  | 'account_status_change'
  | 'message_received'
  | 'task_progress'
  | 'task_complete'
  | 'error'
  | 'chat_history'
  | 'translation_update'
  | 'user_login';

// ─── API 响应 ────────────────────────────────────────────────

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  meta?: {
    total: number;
    page: number;
    limit: number;
  };
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  meta: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}
