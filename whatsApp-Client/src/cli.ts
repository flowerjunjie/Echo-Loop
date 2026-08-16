/**
 * WhatsApp CLI 客户端
 *
 * 提供命令行界面，支持账户管理、消息发送、接收等功能。
 */

import { WAAdapter } from './wa-adapter';
import { AccountManager } from './account-manager';
import { logger as baseLogger, setLogLevel, LogLevel } from './logger';
import * as readline from 'readline';
import * as fs from 'fs';
import * as path from 'path';

// ─── 类型定义 ────────────────────────────────────────────────

interface CLIConfig {
  logLevel?: LogLevel;
  defaultAccount?: string;
}

// ─── CLI 客户端 ──────────────────────────────────────────────

export class WAIClient {
  private accountManager: AccountManager;
  private currentAccount: string | null = null;
  rl: readline.Interface;
  running: boolean = false;

  constructor(private config: CLIConfig = {}) {
    this.accountManager = new AccountManager();
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    if (config.logLevel) {
      setLogLevel(config.logLevel);
    }
  }

  /**
   * 启动 CLI
   */
  async start(): Promise<void> {
    baseLogger.info('='.repeat(60));
    baseLogger.info('WhatsApp Client CLI');
    baseLogger.info('='.repeat(60));
    baseLogger.info('');
    baseLogger.info('Commands:');
    baseLogger.info('  add <file> [name]     - Add an account from export file');
    baseLogger.info('  remove <id>           - Remove an account');
    baseLogger.info('  list                  - List all accounts');
    baseLogger.info('  connect <id>          - Connect to an account');
    baseLogger.info('  disconnect <id>       - Disconnect from an account');
    baseLogger.info('  send <jid> <message>  - Send a message');
    baseLogger.info('  messages [filter]     - Show recent messages');
    baseLogger.info('  status                - Show connection status');
    baseLogger.info('  help                  - Show this help');
    baseLogger.info('  quit                  - Exit');
    baseLogger.info('');

    this.running = true;
    this.prompt();
  }

  /**
   * 显示提示符
   */
  private prompt(): void {
    const accountPrefix = this.currentAccount ? `[${this.currentAccount}] ` : '';
    this.rl.question(`${accountPrefix}wa> `, async (input) => {
      if (!this.running) return;

      const trimmed = input.trim();
      if (!trimmed) {
        this.prompt();
        return;
      }

      try {
        await this.handleCommand(trimmed);
      } catch (error) {
        baseLogger.error('Error:', error instanceof Error ? error.message : String(error));
      }

      this.prompt();
    });
  }

  /**
   * 处理命令
   */
  private async handleCommand(input: string): Promise<void> {
    const parts = input.split(/\s+/);
    const command = parts[0].toLowerCase();
    const args = parts.slice(1);

    switch (command) {
      case 'help':
        this.showHelp();
        break;

      case 'quit':
      case 'exit':
        this.running = false;
        this.rl.close();
        process.exit(0);
        break;

      case 'add': {
        const file = args[0];
        const name = args[1] || file;
        if (!file) {
          throw new Error('Usage: add <export-file> [name]');
        }
        await this.addAccount(file, name);
        break;
      }

      case 'remove': {
        const id = args[0];
        if (!id) {
          throw new Error('Usage: remove <id>');
        }
        await this.removeAccount(id);
        break;
      }

      case 'list':
        this.listAccounts();
        break;

      case 'connect': {
        const id = args[0];
        if (!id) {
          throw new Error('Usage: connect <id>');
        }
        await this.connectAccount(id);
        break;
      }

      case 'disconnect': {
        const id = args[0] || this.currentAccount;
        if (!id) throw new Error("No account specified. Use: disconnect <id>");
        await this.disconnectAccount(id);
        break;
      }

      case 'send': {
        const jid = args[0];
        const message = args.slice(1).join(' ');
        if (!jid || !message) {
          throw new Error('Usage: send <jid> <message>');
        }
        await this.sendMessage(jid, message);
        break;
      }

      case 'messages': {
        const filter = args[0];
        this.showMessages(filter);
        break;
      }

      case 'status':
        this.showStatus();
        break;

      default:
        throw new Error(`Unknown command: ${command}. Type 'help' for usage.`);
    }
  }

  /**
   * 添加账户
   */
  private async addAccount(file: string, name: string): Promise<void> {
    if (!fs.existsSync(file)) {
      throw new Error(`File not found: ${file}`);
    }

    const id = name.replace(/\s+/g, '-').toLowerCase();
    await this.accountManager.addAccount({
      id,
      name,
      exportFile: file,
    });

    baseLogger.info(`Account added: ${name} (${id})`);
  }

  /**
   * 移除账户
   */
  private async removeAccount(id: string): Promise<void> {
    await this.accountManager.removeAccount(id);
    if (this.currentAccount === id) {
      this.currentAccount = null;
    }
    baseLogger.info(`Account removed: ${id}`);
  }

  /**
   * 列出账户
   */
  private listAccounts(): void {
    const accounts = this.accountManager.getAccounts();
    if (accounts.length === 0) {
      baseLogger.info('No accounts added.');
      return;
    }

    baseLogger.info('Accounts:');
    for (const acc of accounts) {
      const status = acc.connected ? '✓ connected' : acc.qrAvailable ? '◉ QR ready' : '✗ disconnected';
      const marker = acc.id === this.currentAccount ? '*' : ' ';
      baseLogger.info(`  ${marker} ${acc.id}: ${acc.name} - ${status}`);
    }
  }

  /**
   * 连接账户
   */
  private async connectAccount(id: string): Promise<void> {
    // Disconnect current account first
    if (this.currentAccount) {
      await this.accountManager.disconnectAccount(this.currentAccount);
    }

    const result = await this.accountManager.connectAccount(id);
    this.currentAccount = id;

    if (result.connected) {
      baseLogger.info(`Connected to: ${id}`);
    } else if (result.qrAvailable) {
      baseLogger.info(`QR pairing required for: ${id}`);
      baseLogger.info('Please scan the QR code with your WhatsApp app.');
    } else {
      baseLogger.warn(`Connection failed for ${id}: ${result.lastError}`);
    }
  }

  /**
   * 断开账户
   */
  private async disconnectAccount(id?: string): Promise<void> {
    const accountId = id || this.currentAccount;
    if (accountId) {
      await this.accountManager.disconnectAccount(accountId);
      if (this.currentAccount === accountId) {
        this.currentAccount = null;
      }
      baseLogger.info(`Disconnected from: ${accountId}`);
    }
  }

  /**
   * 发送消息
   */
  private async sendMessage(jid: string, message: string): Promise<void> {
    if (!this.currentAccount) {
      throw new Error('No account connected. Use "connect <id>" first.');
    }

    await this.accountManager.sendMessage(this.currentAccount, jid, message);
    baseLogger.info(`Message sent to ${jid}`);
  }

  /**
   * 显示消息
   */
  private showMessages(filter?: string): void {
    if (!this.currentAccount) {
      baseLogger.info('No account connected.');
      return;
    }

    const handle = this.accountManager.getAccountStatus(this.currentAccount || "");
    if (!handle) {
      throw new Error(`Account ${this.currentAccount} not found`);
    }

    baseLogger.info(`Messages for ${this.currentAccount}: ${handle.messageCount} total`);
  }

  /**
   * 显示状态
   */
  private showStatus(): void {
    baseLogger.info('='.repeat(40));
    baseLogger.info('Status Overview');
    baseLogger.info('='.repeat(40));

    const accounts = this.accountManager.getAccounts();
    for (const acc of accounts) {
      const marker = acc.id === this.currentAccount ? '*' : ' ';
      baseLogger.info(`${marker} ${acc.id}: ${acc.connected ? 'connected' : acc.qrAvailable ? 'QR ready' : 'disconnected'}`);
      if (acc.lastError) {
        baseLogger.info(`  Error: ${acc.lastError}`);
      }
    }

    baseLogger.info(`Current: ${this.currentAccount || 'none'}`);
    baseLogger.info('='.repeat(40));
  }

  /**
   * 显示帮助
   */
  private showHelp(): void {
    baseLogger.info('WhatsApp Client CLI');
    baseLogger.info('');
    baseLogger.info('Commands:');
    baseLogger.info('  add <file> [name]     - Add an account from export file');
    baseLogger.info('  remove <id>           - Remove an account');
    baseLogger.info('  list                  - List all accounts');
    baseLogger.info('  connect <id>          - Connect to an account');
    baseLogger.info('  disconnect <id>       - Disconnect from an account');
    baseLogger.info('  send <jid> <message>  - Send a message');
    baseLogger.info('  messages [filter]     - Show recent messages');
    baseLogger.info('  status                - Show connection status');
    baseLogger.info('  help                  - Show this help');
    baseLogger.info('  quit                  - Exit');
  }
}

// ─── 主入口 ──────────────────────────────────────────────────

async function main() {
  const cli = new WAIClient({
    logLevel: LogLevel.INFO,
  });

  // Handle exit signals
  process.on('SIGINT', () => {
    cli['running'] = false;
    cli.running = false; cli.rl.close();
    process.exit(0);
  });

  await cli.start();
}

// Run if called directly
main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});

