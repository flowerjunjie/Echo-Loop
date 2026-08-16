/**
 * 数据库迁移脚本
 * 用于在运行时手动触发 schema 初始化 + 列迁移
 */

import { initDb, migrate } from './index';

console.log('[migrate] Initializing database...');
initDb();
console.log('[migrate] Running migrations...');
migrate();
console.log('[migrate] Done.');
