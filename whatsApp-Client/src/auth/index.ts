// @ts-nocheck
/**
 * 认证模块 — JWT + bcrypt
 *
 * 支持管理员/子账号登录、权限验证、Session 管理
 */

import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import type { AdminUser } from '../types';
import { logAudit } from '../db';

const _providedSecret = process.env.JWT_SECRET;
const JWT_SECRET = _providedSecret || 'whatsapp-platform-dev-secret-do-not-use-in-production-change-me';
if (!_providedSecret) {
  console.warn('[AUTH] WARNING: JWT_SECRET not set! Using weak default - set JWT_SECRET env var in production!');
}
const JWT_EXPIRES_IN = '24h';

export interface LoginResult {
  token: string;
  user: Omit<AdminUser, 'passwordHash'>;
}

export interface TokenPayload {
  userId: string;
  username: string;
  role: 'admin' | 'sub';
}

// ─── 登录 ────────────────────────────────────────────────────

export async function login(
  username: string,
  password: string,
  ip?: string,
  userAgent?: string
): Promise<LoginResult> {
  validateUsername(username);
  validatePassword(password);
  const { findAdminUserByUsername, updateAdminLastLogin } = require('../db');
  const user = findAdminUserByUsername(username);

  if (!user || !user.isActive) {
    throw new Error('用户名或密码错误');
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    throw new Error('用户名或密码错误');
  }

  updateAdminLastLogin(user.id);

  const payload: TokenPayload = {
    userId: user.id,
    username: user.username,
    role: user.role,
  };

  const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

  // Audit log
  try {
    logAudit({ userId: user.id, action: 'login', targetType: 'user', targetId: user.id, details: 'User login success', ip, userAgent });
  } catch {}

  const { passwordHash, password_hash, ...safeUser } = user;
  return { token, user: safeUser as any };
}

const PASSWORD_MIN_LENGTH = 6;
const USERNAME_MIN_LENGTH = 3;
const USERNAME_MAX_LENGTH = 50;

function validateUsername(u: string): void {
  if (!u || typeof u !== 'string' || u.length < USERNAME_MIN_LENGTH || u.length > USERNAME_MAX_LENGTH) {
    throw new Error(`用户名长度需在${USERNAME_MIN_LENGTH}-${USERNAME_MAX_LENGTH}之间`);
  }
  if (!/^[a-zA-Z0-9_]+$/.test(u)) throw new Error('用户名只能包含字母、数字、下划线');
}

function validatePassword(p: string): void {
  if (!p || typeof p !== 'string' || p.length < PASSWORD_MIN_LENGTH) {
    throw new Error(`密码长度至少${PASSWORD_MIN_LENGTH}位`);
  }
}

export async function register(data: { username: string; password: string; name: string; role: 'admin' | 'sub'; permissions?: string[] }): Promise<AdminUser> {
  validateUsername(data.username);
  validatePassword(data.password);
  const { createAdminUser } = require('../db');
  const user = createAdminUser({
    id: `user-${Date.now()}`,
    ...data,
  });
  return user;
}

// ─── Token 验证 ──────────────────────────────────────────────

export function verifyToken(token: string): TokenPayload {
  try {
    return jwt.verify(token, JWT_SECRET) as TokenPayload;
  } catch {
    throw new Error('Token 无效或已过期');
  }
}

export function getTokenUser(token: string): TokenPayload {
  return verifyToken(token);
}

// ─── 权限检查 ────────────────────────────────────────────────

export function hasPermission(user: AdminUser, permission: string): boolean {
  if (user.role === 'admin') return true;
  const perms = user.permissions || [];
  return perms.includes('*') || perms.includes(permission);
}

export function isAdmin(user: AdminUser): boolean {
  return user.role === 'admin';
}
