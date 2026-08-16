/**
 * 日志工具
 */

export enum LogLevel {
  ERROR = 0,
  WARN = 1,
  INFO = 2,
  DEBUG = 3,
}

let currentLevel: LogLevel = LogLevel.INFO;

export function setLogLevel(level: LogLevel): void {
  currentLevel = level;
}

export const logger = {
  level: "warn" as const,
  child: () => logger,
  error: (msg: string, ...args: unknown[]): void => {
    if (currentLevel <= LogLevel.ERROR) {
      console.error(`[ERROR] ${msg}`, ...args);
    }
  },
  warn: (msg: string, ...args: unknown[]): void => {
    if (currentLevel <= LogLevel.WARN) {
      console.warn(`[WARN] ${msg}`, ...args);
    }
  },
  info: (msg: string, ...args: unknown[]): void => {
    if (currentLevel <= LogLevel.INFO) {
      console.log(`[INFO] ${msg}`, ...args);
    }
  },
  debug: (msg: string, ...args: unknown[]): void => {
    if (currentLevel <= LogLevel.DEBUG) {
      console.debug(`[DEBUG] ${msg}`, ...args);
    }
  },
  trace: (msg: string, ...args: unknown[]): void => {
    if (currentLevel <= LogLevel.DEBUG) {
      console.debug(`[TRACE] ${msg}`, ...args);
    }
  },
};
