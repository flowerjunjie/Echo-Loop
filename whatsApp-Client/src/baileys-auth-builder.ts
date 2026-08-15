/**
 * Baileys 认证状态构建器
 *
 * 将解析后的 WhatsApp 密钥材料转换为 Baileys AuthenticationState 格式，
 * 实现从导出密钥到可连接客户端的桥梁。
 */

import type {
  AuthenticationState,
  AuthenticationCreds,
  KeyPair,
  SignalKeyStore,
} from '@whiskeysockets/baileys/lib/Types/Auth';
import { randomBytes } from 'crypto';
import { Curve } from '@whiskeysockets/baileys/lib/Utils/crypto';
import type { ParsedExport, ParsedPreKey } from './key-parser';

// ─── 类型定义 ────────────────────────────────────────────────

export interface AuthBuilderConfig {
  /** 解析后的导出数据 */
  parsed: ParsedExport;
  /** 浏览器标识（用于设备指纹） */
  browser?: [string, string, string];
  /** 是否强制重新生成 signedPreKey（当私钥缺失时） */
  regenerateSignedPreKey?: boolean;
}

// ─── 核心实现 ────────────────────────────────────────────────

/**
 * 构建 Baileys AuthenticationState
 *
 * 映射关系：
 * - identity.hexPrivate/Hex → creds.signedIdentityKey
 * - clientStaticKeypairBase64 → creds.noiseKey
 * - preKeys[] → keys.get('pre-key', ids)
 * - signedPreKey → creds.signedPreKey
 * - registration_id → creds.registrationId
 */
export function buildAuthenticationState(config: AuthBuilderConfig): AuthenticationState {
  const { parsed, browser = ['WhatsApp', 'Android', '17.0'], regenerateSignedPreKey = false } = config;

  // ─── Step 1: 构建 SignalCreds ──────────────────────────────

  // signedIdentityKey: 直接使用导出的 identity key
  // 必须转换为 Buffer，因为 libsignal 要求 Buffer 而非 Uint8Array
  const signedIdentityKey: KeyPair = {
    public: Buffer.from(parsed.identity.public),
    private: Buffer.from(parsed.identity.private),
  };

  // signedPreKey: 尝试从 preKeys 中匹配公钥找到私钥
  let signedPreKeyPair: KeyPair;
  let signedPreKeySignature: Uint8Array;
  let signedPreKeyId: number;

  if (regenerateSignedPreKey) {
    // 方案 B: 重新生成 signedPreKey（使用 identity 私钥签名新预密钥）
    const newKeyPair = Curve.generateKeyPair();
    // 注意：实际签名需要用 identity 私钥对 (keyId || pubkey) 进行 Ed25519 签名
    // 这里简化处理，假设服务器接受新签名的 pre-key
    signedPreKeyPair = newKeyPair;
    signedPreKeySignature = Buffer.from(
      '00'.repeat(64), // placeholder - 实际需要 Ed25519 签名
      'hex'
    );
    signedPreKeyId = parsed.signedPreKey.jsonPreKeyId;
  } else {
    // 方案 C: 从 preKeys 中查找匹配的公钥
    const matchingPreKey = findMatchingPreKey(parsed.signedPreKey.public, parsed.preKeys);
    if (matchingPreKey) {
      signedPreKeyPair = {
        public: Buffer.from(matchingPreKey.public),
        private: Buffer.from(matchingPreKey.private),
      };
      signedPreKeySignature = parsed.signedPreKey.signature;
      signedPreKeyId = parsed.signedPreKey.keyId;
      console.log(
        `[AuthBuilder] Found matching preKey for signedPreKey: internalId=${matchingPreKey.internalId}`
      );
    } else {
      // 找不到匹配，回退到方案 B
      console.warn(
        '[AuthBuilder] No matching preKey found for signedPreKey, will regenerate'
      );
      const newKeyPair = Curve.generateKeyPair();
      signedPreKeyPair = newKeyPair;
      signedPreKeySignature = Buffer.from('00'.repeat(64), 'hex');
      signedPreKeyId = parsed.signedPreKey.jsonPreKeyId;
    }
  }

  const signedPreKey = {
    keyPair: signedPreKeyPair,
    signature: signedPreKeySignature,
    keyId: signedPreKeyId,
  };

  // ─── Step 2: 构建完整 AuthenticationCreds ──────────────────

  const creds: AuthenticationCreds = {
    // SignalCreds
    signedIdentityKey,
    signedPreKey,
    registrationId: parsed.identity.registrationId,

    // Noise key (from clientStaticKeypairBase64)
    noiseKey: parsed.noiseKey,

    // Pairing ephemeral key (需要新生成)
    pairingEphemeralKeyPair: Curve.generateKeyPair(),

    // ADV secret key (需要新生成)
    advSecretKey: randomBytes(32).toString('base64'),

    // Account info
    me: {
      id: `${parsed.account}@s.whatsapp.net`,
      name: parsed.nickname,
    },

    // Pre-key bookkeeping
    firstUnuploadedPreKeyId: parsed.minPreKeyId,
    nextPreKeyId: parsed.maxPreKeyId + 1,

    // Device info
    platform: parsed.deviceId,

    // History
    processedHistoryMessages: [],
    accountSyncCounter: 0,
    accountSettings: { unarchiveChats: false },

    // Registration state
    registered: false,
    pairingCode: undefined,
    lastPropHash: undefined,

    // Routing (可能为 undefined)
    routingInfo: undefined,
    additionalData: undefined,
  };

  // ─── Step 3: 构建 SignalKeyStore ───────────────────────────

  const preKeyMap = buildPreKeyMap(parsed.preKeys);

  const keys: SignalKeyStore = {
    async get(type, ids) {
      const result: { [id: string]: unknown } = {};

      for (const id of ids) {
        switch (type) {
          case 'pre-key': {
            const pk = preKeyMap.get(parseInt(id, 10));
            result[id] = pk ?? null;
            break;
          }
          case 'identity-key': {
            // 返回 identity 公钥
            result[id] = signedIdentityKey.public;
            break;
          }
          case 'session':
          case 'sender-key':
          case 'sender-key-memory':
          case 'app-state-sync-key':
          case 'app-state-sync-version':
          case 'lid-mapping':
          case 'device-list': {
            result[id] = null;
            break;
          }
          default: {
            result[id] = null;
            break;
          }
        }
      }

      return result as any;
    },

    async set(data) {
      // 处理服务端推送的密钥更新
      for (const [type, entries] of Object.entries(data)) {
        if (type === 'pre-key' && entries) {
          for (const [id, pair] of Object.entries(entries as Record<string, KeyPair | null>)) {
            const keyId = parseInt(id, 10);
            if (pair === null) {
              preKeyMap.delete(keyId);
            } else {
              preKeyMap.set(keyId, pair);
            }
          }
        }
        // 其他类型（session、identity-key 等）由 Baileys 内部处理
      }
    },

    async clear() {
      preKeyMap.clear();
    },
  };

  return { creds, keys };
}

// ─── 辅助函数 ────────────────────────────────────────────────

/**
 * 构建 preKey 查找映射
 */
function buildPreKeyMap(preKeys: ParsedPreKey[]): Map<number, KeyPair> {
  const map = new Map<number, KeyPair>();
  for (const pk of preKeys) {
    map.set(pk.preKeyId, {
      public: Buffer.from(pk.public),
      private: Buffer.from(pk.private),
    });
  }
  return map;
}

/**
 * 在 preKeys 中查找与给定公钥匹配的条目
 */
function findMatchingPreKey(
  targetPubkey: Uint8Array,
  preKeys: ParsedPreKey[]
): ParsedPreKey | null {
  for (const pk of preKeys) {
    if (pk.public.length === targetPubkey.length) {
      let match = true;
      for (let i = 0; i < pk.public.length; i++) {
        if (pk.public[i] !== targetPubkey[i]) {
          match = false;
          break;
        }
      }
      if (match) {
        return pk;
      }
    }
  }
  return null;
}

// ─── 导出 ────────────────────────────────────────────────────

export { buildPreKeyMap, findMatchingPreKey };
