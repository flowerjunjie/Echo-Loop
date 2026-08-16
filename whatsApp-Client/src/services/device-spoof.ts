// @ts-nocheck
/**
 * 设备/代理伪装服务
 *
 * 实现：随机化设备指纹、IP 代理切换、模拟真实用户行为
 * 防封号策略：错峰登录、随机延迟、多样化设备配置
 */

import type { DeviceConfig, WhatsAppAccount } from '../types';
import { insertDeviceConfig, getDeviceConfig, listDeviceConfigs, deleteDeviceConfig } from '../db';
import { logger } from '../logger';

// ─── 设备指纹库 ──────────────────────────────────────────────

const DEVICE_PROFILES = [
  { platform: 'Android', browser: ['WhatsApp', 'Android', '12.0'], model: 'Pixel 7', osVersion: '12', screenWidth: 1080, screenHeight: 2400, dpi: 420 },
  { platform: 'Android', browser: ['WhatsApp', 'Android', '13.0'], model: 'Samsung Galaxy S23', osVersion: '13', screenWidth: 1080, screenHeight: 2340, dpi: 425 },
  { platform: 'Android', browser: ['WhatsApp', 'Android', '14.0'], model: 'OnePlus 11', osVersion: '14', screenWidth: 1440, screenHeight: 3216, dpi: 512 },
  { platform: 'iOS', browser: ['WhatsApp', 'iPhone', '17.0'], model: 'iPhone16,1', osVersion: '17', screenWidth: 1179, screenHeight: 2556, dpi: 460 },
  { platform: 'iOS', browser: ['WhatsApp', 'iPhone', '16.5'], model: 'iPhone14,7', osVersion: '16.5', screenWidth: 1170, screenHeight: 2532, dpi: 460 },
  { platform: 'Windows', browser: ['WhatsApp', 'Windows', '10'], model: 'PC', osVersion: '10', screenWidth: 1920, screenHeight: 1080, dpi: 96 },
  { platform: 'Mac', browser: ['WhatsApp', 'Mac', '14.0'], model: 'Mac', osVersion: '14', screenWidth: 2560, screenHeight: 1600, dpi: 72 },
];

const LOCALES = ['en_US', 'zh_CN', 'zh_TW', 'ja_JP', 'ko_KR', 'ar_SA', 'es_ES', 'fr_FR', 'de_DE', 'ru_RU'];
const TIMEZONES = ['Asia/Shanghai', 'Asia/Hong_Kong', 'Asia/Tokyo', 'Asia/Seoul', 'America/New_York', 'Europe/London', 'Europe/Berlin', 'Australia/Sydney'];

// ─── 设备配置管理 ────────────────────────────────────────────

export function generateDeviceProfile(): DeviceConfig {
  const profile = DEVICE_PROFILES[Math.floor(Math.random() * DEVICE_PROFILES.length)];
  const locale = LOCALES[Math.floor(Math.random() * LOCALES.length)];
  const timezone = TIMEZONES[Math.floor(Math.random() * TIMEZONES.length)];

  const userAgent = buildUserAgent(profile.platform, profile.osVersion, profile.model);

  const config: DeviceConfig = {
    id: `device-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    name: `${profile.model} (${locale})`,
    browser: profile.browser,
    platform: profile.platform,
    model: profile.model,
    osVersion: profile.osVersion,
    userAgent,
    locale,
    timezone,
    screenWidth: profile.screenWidth,
    screenHeight: profile.screenHeight,
    dpi: profile.dpi,
    createdAt: Date.now(),
  };

  return config;
}

function buildUserAgent(platform: string, osVersion: string, model: string): string {
  const configs: Record<string, string> = {
    Android: `Mozilla/5.0 (Linux; Android ${osVersion}; ${model}) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.0.0 Mobile Safari/537.36`,
    iPhone: `Mozilla/5.0 (iPhone; CPU iPhone OS ${osVersion.replace('.', '_')} like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148`,
    Windows: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`,
    Mac: `Mozilla/5.0 (Macintosh; Intel Mac OS X ${osVersion.replace('.', '.')}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`,
  };
  return configs[platform] || configs['Android'];
}

// ─── 反检测策略 ──────────────────────────────────────────────

export interface AntiDetectConfig {
  minDelayMs: number;
  maxDelayMs: number;
  maxConcurrentPerIp: number;
  maxTotalConnections: number;
  proxyRotationEnabled: boolean;
  jitterEnabled: boolean;
  sessionDurationMaxMin: number;
}

const DEFAULT_ANTI_DETECT: AntiDetectConfig = {
  minDelayMs: 3000,
  maxDelayMs: 15000,
  maxConcurrentPerIp: 3,
  proxyRotationEnabled: true,
  maxTotalConnections: 50,
  jitterEnabled: true,
  sessionDurationMaxMin: 30,
};

export function getAntiDetectConfig(): AntiDetectConfig {
  try {
    const raw = process.env.ANTI_DETECT_CONFIG;
    if (raw) return JSON.parse(raw) as AntiDetectConfig;
  } catch {}
  return DEFAULT_ANTI_DETECT;
}

/** 生成随机登录延迟（毫秒） */
export function randomLoginDelay(): number {
  const cfg = getAntiDetectConfig();
  let delay = cfg.minDelayMs + Math.random() * (cfg.maxDelayMs - cfg.minDelayMs);
  if (cfg.jitterEnabled) delay *= (0.8 + Math.random() * 0.4);
  return Math.round(delay);
}

/** 生成随机会话时长（毫秒） */
export function randomSessionDuration(): number {
  const cfg = getAntiDetectConfig();
  return Math.round((cfg.sessionDurationMaxMin * 60 * 1000) * (0.3 + Math.random() * 0.7));
}

// ─── 代理管理 ────────────────────────────────────────────────

export interface ProxyInfo {
  url: string;
  type: 'http' | 'https' | 'socks4' | 'socks5';
  ip: string;
  country?: string;
  lastUsedAt?: number;
}

export let proxyList: ProxyInfo[] = [];

export { proxyList };

export function setProxyList(proxies: ProxyInfo[]): void {
  proxyList = proxies;
  logger.info(`[DeviceSpoof] Loaded ${proxies.length} proxies`);
}

export function addProxy(proxy: ProxyInfo): void {
  proxyList.push(proxy);
}

/** 获取随机代理（轮询 + 随机） */
export function getRandomProxy(): ProxyInfo | undefined {
  if (proxyList.length === 0) return undefined;
  // 过滤掉刚用过的（避免同一 IP 频繁使用）
  const now = Date.now();
  const available = proxyList.filter(p => !p.lastUsedAt || now - p.lastUsedAt > 30000);
  const pool = available.length > 0 ? available : proxyList;
  const pick = pool[Math.floor(Math.random() * pool.length)];
  pick.lastUsedAt = now;
  return pick;
}

/** 按国家筛选代理 */
export function getProxyByCountry(country: string): ProxyInfo | undefined {
  return proxyList.find(p => p.country === country);
}

// ─── 设备配置 CRUD API ───────────────────────────────────────

export async function createDevice(nameOrConfig: string | DeviceConfig): Promise<DeviceConfig> {
  const { insertDeviceConfig } = require('../db');
  let config: DeviceConfig;
  if (typeof nameOrConfig === 'string') {
    config = generateDeviceProfile();
    config.name = nameOrConfig || config.name;
  } else {
    config = nameOrConfig;
  }
  return insertDeviceConfig(config);
}

export async function getDevice(id: string): Promise<DeviceConfig | undefined> {
  return getDeviceConfig(id);
}

export async function listDevices(): Promise<DeviceConfig[]> {
  return listDeviceConfigs();
}

export async function deleteDevice(id: string): Promise<boolean> {
  const { deleteDeviceConfig } = require('../db');
  return deleteDeviceConfig(id);
}

// ─── 设备配置构建 ────────────────────────────────────────────

/**
 * 根据账号 ID 和可选的设备 ID 构建 ConnectionManager 所需的连接配置
 */
export function buildConnectionConfig(
  account: WhatsAppAccount,
  deviceConfigId?: string
): { browser: [string, string, string]; userAgent?: string; locale?: string; timezone?: string } {
  let device: DeviceConfig | undefined;
  if (deviceConfigId) {
    device = getDeviceConfig(deviceConfigId);
  } else if (account.deviceConfigId) {
    device = getDeviceConfig(account.deviceConfigId);
  }

  if (device) {
    return {
      browser: device.browser,
      userAgent: device.userAgent,
      locale: device.locale,
      timezone: device.timezone,
    };
  }

  // 默认：Android
  return { browser: ['WhatsApp', 'Android', '17.0'] };
}
