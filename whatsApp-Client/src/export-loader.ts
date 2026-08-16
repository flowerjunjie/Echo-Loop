/**
 * 导出文件加载器
 */

import * as fs from 'fs';
import * as path from 'path';
import type { WhatsAppExportData } from './key-parser';

export type { WhatsAppExportData } from './key-parser';

/**
 * 加载 WhatsApp 导出文件
 * 支持：JSON 文件、文本文件（包含 JSON）
 */
export async function loadExport(
  source: string | WhatsAppExportData
): Promise<WhatsAppExportData> {
  // 如果已经是解析后的数据，直接返回
  if (typeof source === 'object' && !('toString' in source)) {
    return source as WhatsAppExportData;
  }

  const filePath = source as string;

  // 检查文件是否存在
  if (!fs.existsSync(filePath)) {
    throw new Error(`Export file not found: ${filePath}`);
  }

  // 读取文件内容
  const content = fs.readFileSync(filePath, 'utf8').trim();

  // 尝试解析 JSON
  try {
    return JSON.parse(content) as WhatsAppExportData;
  } catch (e) {
    throw new Error(`Failed to parse export file: ${e instanceof Error ? e.message : String(e)}`);
  }
}

/**
 * 从 doc 目录加载默认导出文件
 */
export async function loadDefaultExport(): Promise<WhatsAppExportData> {
  const docDir = path.join(__dirname, '..', 'doc');
  const files = fs.readdirSync(docDir).filter((f) => f.endsWith('.txt'));

  if (files.length === 0) {
    throw new Error('No export files found in doc/ directory');
  }

  // 优先使用 requirement.txt
  const targetFile = files.includes('requirement.txt')
    ? 'requirement.txt'
    : files[0];

  return loadExport(path.join(docDir, targetFile));
}
