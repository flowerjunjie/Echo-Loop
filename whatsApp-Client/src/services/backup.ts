// @ts-nocheck
/**
 * 数据库备份服务
 * 支持手动备份和定时自动备份
 */

import * as fs from 'fs';
import * as path from 'path';
import { logger } from '../logger';

const BACKUP_DIR = process.env.BACKUP_DIR || path.join(process.cwd(), 'backups');
const MAX_BACKUPS = 10; // 最多保留10个备份

export function getBackupDir(): string {
  if (!fs.existsSync(BACKUP_DIR)) {
    fs.mkdirSync(BACKUP_DIR, { recursive: true });
  }
  return BACKUP_DIR;
}

export function createBackup(description?: string): string {
  const dbPath = process.env.DB_PATH || path.join(process.cwd(), 'data', 'wa_platform.db');
  if (!fs.existsSync(dbPath)) {
    throw new Error('Database file not found: ' + dbPath);
  }

  const backupDir = getBackupDir();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupName = description ? `${description}_${timestamp}.db` : `${timestamp}.db`;
  const backupPath = path.join(backupDir, backupName);

  // Copy database file
  fs.copyFileSync(dbPath, backupPath);

  // Also copy WAL file if exists
  const walPath = dbPath + '-wal';
  if (fs.existsSync(walPath)) {
    fs.copyFileSync(walPath, backupPath + '-wal');
  }
  const shmPath = dbPath + '-shm';
  if (fs.existsSync(shmPath)) {
    fs.copyFileSync(shmPath, backupPath + '-shm');
  }

  logger.info(`[Backup] Created backup: ${backupName}`);
  return backupPath;
}

export function listBackups(): Array<{ name: string; size: number; createdAt: number }> {
  const backupDir = getBackupDir();
  if (!fs.existsSync(backupDir)) return [];

  return fs.readdirSync(backupDir)
    .filter(f => f.endsWith('.db') && !f.endsWith('-wal') && !f.endsWith('-shm'))
    .map(f => {
      const stat = fs.statSync(path.join(backupDir, f));
      return { name: f, size: stat.size, createdAt: stat.mtimeMs };
    })
    .sort((a, b) => b.createdAt - a.createdAt);
}

export function deleteBackup(filename: string): boolean {
  const backupDir = getBackupDir();
  const filePath = path.join(backupDir, filename);
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    // Also remove associated WAL/SHM if any
    try { fs.unlinkSync(filePath + '-wal'); } catch {}
    try { fs.unlinkSync(filePath + '-shm'); } catch {}
    logger.info(`[Backup] Deleted: ${filename}`);
    return true;
  }
  return false;
}

export function restoreBackup(filename: string): void {
  const backupDir = getBackupDir();
  const backupPath = path.join(backupDir, filename);
  const dbPath = process.env.DB_PATH || path.join(process.cwd(), 'data', 'wa_platform.db');

  if (!fs.existsSync(backupPath)) {
    throw new Error('Backup file not found: ' + filename);
  }

  // Stop any active connections first
  logger.info(`[Backup] Restoring from: ${filename}`);

  // Copy backup to database location
  fs.copyFileSync(backupPath, dbPath);

  // Restore WAL/SHM if present
  try { fs.copyFileSync(backupPath + '-wal', dbPath + '-wal'); } catch {}
  try { fs.copyFileSync(backupPath + '-shm', dbPath + '-shm'); } catch {}

  logger.info(`[Backup] Restore completed: ${filename}`);
}

export function autoBackup(): void {
  try {
    createBackup('auto');
    // Clean up old backups
    const backups = listBackups();
    while (backups.length > MAX_BACKUPS) {
      const oldest = backups.pop();
      if (oldest) deleteBackup(oldest.name);
    }
  } catch (err) {
    logger.error('[Backup] Auto backup failed:', err);
  }
}
