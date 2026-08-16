/**
 * WhatsApp 账户管理器
 *
 * 管理多个 WhatsApp 账户的认证和连接。
 */

import type { AuthenticationState } from '@whiskeysockets/baileys/lib/Types/Auth';
import { logger as baseLogger } from './logger';
import type { ParsedExport } from './key-parser';
import { ConnectionManager } from './connection-manager';
import { MessageManager } from './message-manager';
import type { ConnectionState } from './wa-adapter';

// ─── 类型定义 ────────────────────────────────────────────────

export interface AccountConfig {
  id: string;
  name: string;
  exportFile: string;
  browser?: [string, string, string];
}

export interface AccountStatus {
  id: string;
  name: string;
  connected: boolean;
  lastError: string | null;
  qrAvailable: boolean;
  messageCount: number;
}

// ─── 账户管理器 ──────────────────────────────────────────────

export class AccountManager {
  private accounts: Map<string, AccountHandle> = new Map();

  constructor() {
    baseLogger.info('[AccountManager] Initialized');
  }

  /**
   * 添加账户
   */
  async addAccount(config: AccountConfig): Promise<AccountHandle> {
    if (this.accounts.has(config.id)) {
      throw new Error(`Account ${config.id} already exists`);
    }

    baseLogger.info(`[AccountManager] Adding account: ${config.name} (${config.id})`);

    // Load and parse export
    const { parseWhatsAppExport } = await import('./key-parser');
    const { buildAuthenticationState } = await import('./baileys-auth-builder');
    const { loadExport } = await import('./export-loader');

    const exportData = await loadExport(config.exportFile);
    const parsed = parseWhatsAppExport(exportData);

    // Build auth state
    const authState = buildAuthenticationState({
      parsed,
      browser: config.browser,
    });

    // Create account handle
    const handle = new AccountHandle(config.id, config.name, parsed, authState);
    this.accounts.set(config.id, handle);

    baseLogger.info(`[AccountManager] Account added: ${config.name}, preKeys=${parsed.preKeys.length}`);

    return handle;
  }

  /**
   * 移除账户
   */
  async removeAccount(id: string): Promise<void> {
    const handle = this.accounts.get(id);
    if (!handle) {
      throw new Error(`Account ${id} not found`);
    }

    await handle.disconnect();
    this.accounts.delete(id);
    baseLogger.info(`[AccountManager] Account removed: ${id}`);
  }

  /**
   * 连接账户
   */
  async connectAccount(id: string): Promise<ConnectionState> {
    const handle = this.accounts.get(id);
    if (!handle) {
      throw new Error(`Account ${id} not found`);
    }

    return handle.connect();
  }

  /**
   * 断开账户
   */
  async disconnectAccount(id: string): Promise<void> {
    const handle = this.accounts.get(id);
    if (handle) {
      await handle.disconnect();
    }
  }

  /**
   * 获取账户列表
   */
  getAccounts(): AccountStatus[] {
    return Array.from(this.accounts.values()).map(h => h.getStatus());
  }

  /**
   * 发送消息到指定账户
   */
  async sendMessage(accountId: string, to: string, content: string): Promise<string> {
    const handle = this.accounts.get(accountId);
    if (!handle) {
      throw new Error(`Account ${accountId} not found`);
    }

    return handle.sendMessage(to, content);
  }

  /**
   * 获取账户状态
   */
  getAccountStatus(id: string): AccountStatus | undefined {
    const handle = this.accounts.get(id);
    return handle?.getStatus();
  }
}

// ─── 账户句柄 ────────────────────────────────────────────────

class AccountHandle {
  id: string;
  name: string;
  parsed: ParsedExport;
  authState: AuthenticationState;
  connectionManager: ConnectionManager;
  messageManager: MessageManager;
  private state: ConnectionState = {
    connected: false,
    lastError: null,
    qrAvailable: false,
  };

  constructor(id: string, name: string, parsed: ParsedExport, authState: AuthenticationState) {
    this.id = id;
    this.name = name;
    this.parsed = parsed;
    this.authState = authState;
    this.connectionManager = new ConnectionManager({
      authState,
      parsed,
    });
    this.messageManager = new MessageManager();
  }

  async connect(): Promise<ConnectionState> {
    const result = await this.connectionManager.connect();
    this.state = result.state;

    if (result.success) {
      // Bind socket to message manager
      // Note: We need to get the socket from the connection manager
      // For now, we'll set up the message manager after connection
      const sock = this.connectionManager.getSocket(); if (sock) this.messageManager.bindSocket(sock);
    }

    return this.state;
  }

  async disconnect(): Promise<void> {
    await this.connectionManager.disconnect();
    this.state.connected = false;
  }

  async sendMessage(to: string, content: string): Promise<string> {
    return this.messageManager.sendText(to, content);
  }

  getStatus(): AccountStatus {
    return {
      id: this.id,
      name: this.name,
      connected: this.state.connected,
      lastError: this.state.lastError,
      qrAvailable: this.state.qrAvailable,
      messageCount: this.messageManager.getMessageCount(),
    };
  }
}

