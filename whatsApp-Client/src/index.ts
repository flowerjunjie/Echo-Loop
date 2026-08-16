/**
 * 主入口 — 同时启动 Admin Server + CLI
 */

import { logger } from './logger';

async function main() {
  logger.info('='.repeat(50));
  logger.info('WhatsApp Business Platform v2.0');
  logger.info('='.repeat(50));

  // Start admin server
  const { server } = await import('./admin/server');

  logger.info('Platform ready. Admin UI: http://localhost:3456');
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
