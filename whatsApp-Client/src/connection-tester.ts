/**
 * WhatsApp 连接测试器
 *
 * 提供连接测试功能，验证密钥材料是否有效。
 */

import { WAAdapter } from './wa-adapter';
import { logger as baseLogger, setLogLevel, LogLevel } from './logger';
import { parseWhatsAppExport } from './key-parser';
import { buildAuthenticationState } from './baileys-auth-builder';
import { loadExport } from './export-loader';

// ─── 类型定义 ────────────────────────────────────────────────

export interface TestResult {
  success: boolean;
  account: string;
  nickname: string;
  preKeys: number;
  errors: string[];
  warnings: string[];
}

// ─── 连接测试器 ──────────────────────────────────────────────

export class ConnectionTester {
  private results: TestResult[] = [];

  /**
   * 测试单个导出文件
   */
  async testFile(filePath: string): Promise<TestResult> {
    baseLogger.info(`[ConnectionTester] Testing: ${filePath}`);

    const result: TestResult = {
      success: false,
      account: '',
      nickname: '',
      preKeys: 0,
      errors: [],
      warnings: [],
    };

    try {
      // 加载导出文件
      const exportData = await loadExport(filePath);
      result.account = exportData.account;
      result.nickname = exportData.data.nickname;
      result.preKeys = exportData.data.phoneKeyStore.preKeys.length;

      // 解析密钥
      const parsed = parseWhatsAppExport(exportData);
      result.preKeys = parsed.preKeys.length;

      // 检查关键缺口
      if (parsed.missingServerStatic) {
        result.warnings.push('serverStaticPublic is null - may fail to connect');
      }
      if (parsed.missingRoutingInfo) {
        result.warnings.push('routingInfo is null - may have routing issues');
      }

      // 构建认证状态
      const authState = buildAuthenticationState({ parsed });

      // 验证密钥结构
      result.errors.push(...this.validateKeys(parsed));

      // 尝试连接（超时 10 秒）
      try {
        const adapter = new WAAdapter({
          exportSource: exportData,
          browser: ['WhatsApp', 'Android', '17.0'],
          connectTimeoutMs: 10000,
          maxRetries: 1,
        });

        await adapter.init();
        await adapter.connect();

        result.success = adapter.getState().connected;
        if (!result.success) {
          result.errors.push(`Connection failed: ${adapter.getState().lastError}`);
        }

        await adapter.disconnect();
      } catch (connectError) {
        result.warnings.push(`Connection test skipped: ${connectError instanceof Error ? connectError.message : 'Unknown error'}`);
      }

      baseLogger.info(`[ConnectionTester] Test completed for ${result.account}: success=${result.success}, errors=${result.errors.length}, warnings=${result.warnings.length}`);
    } catch (error) {
      result.errors.push(error instanceof Error ? error.message : 'Unknown error');
      baseLogger.error('[ConnectionTester] Test failed:', error);
    }

    this.results.push(result);
    return result;
  }

  /**
   * 验证密钥结构
   */
  private validateKeys(parsed: any): string[] {
    const errors: string[] = [];

    // 验证 identity key
    if (parsed.identity.private.length !== 32) {
      errors.push('Invalid identity private key length');
    }
    if (parsed.identity.public.length !== 33) {
      errors.push('Invalid identity public key length');
    }

    // 验证 noise key
    if (parsed.noiseKey.private.length !== 32) {
      errors.push('Invalid noise key length');
    }

    // 验证 pre-keys
    if (parsed.preKeys.length === 0) {
      errors.push('No pre-keys found');
    }

    // 验证 signed pre-key
    if (!parsed.signedPreKey.public || parsed.signedPreKey.public.length !== 33) {
      errors.push('Invalid signed pre-key public key');
    }

    return errors;
  }

  /**
   * 获取所有测试结果
   */
  getResults(): TestResult[] {
    return this.results;
  }

  /**
   * 打印测试结果摘要
   */
  printSummary(): void {
    baseLogger.info('='.repeat(60));
    baseLogger.info('Connection Test Summary');
    baseLogger.info('='.repeat(60));

    for (const result of this.results) {
      baseLogger.info(`\nAccount: ${result.account} (${result.nickname})`);
      baseLogger.info(`PreKeys: ${result.preKeys}`);
      baseLogger.info(`Success: ${result.success ? '✓ YES' : '✗ NO'}`);

      if (result.warnings.length > 0) {
        baseLogger.info('Warnings:');
        for (const w of result.warnings) {
          baseLogger.info(`  ⚠ ${w}`);
        }
      }

      if (result.errors.length > 0) {
        baseLogger.info('Errors:');
        for (const e of result.errors) {
          baseLogger.info(`  ✗ ${e}`);
        }
      }
    }

    baseLogger.info('='.repeat(60));
  }
}

// ─── 便捷函数 ────────────────────────────────────────────────

/**
 * 快速测试
 */
export async function quickTest(filePath: string): Promise<TestResult> {
  const tester = new ConnectionTester();
  return tester.testFile(filePath);
}

