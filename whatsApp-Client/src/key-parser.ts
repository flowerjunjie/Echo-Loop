/**
 * WhatsApp Signal Protocol 密钥解析器
 *
 * 解析从 WhatsApp iOS 客户端导出的密钥材料，
 * 将自定义二进制格式转换为标准 X25519/Ed25519 密钥对。
 */

import type { KeyPair, SignedKeyPair } from '@whiskeysockets/baileys/lib/Types/Auth';

// ─── 类型定义 ───────────────────────────────────────────────

export interface WhatsAppExportData {
  account: string;
  channel: string;
  data: {
    _version: number;
    apiType: number;
    clientStaticKeypairBase64: string;
    deviceConfig: {
      board: string;
      brand: string;
      model: string;
      sdk_release: string;
      display: string;
      fingerprint: string;
      sim_operator: string;
    };
    nickname: string;
    phoneId: string;
    phoneKeyStore: PhoneKeyStore;
    proxy: unknown;
    routingInfo: unknown;
    serverStaticPublicBase64: string | null;
    sim_operator: unknown;
    uploadTokenRandomBytes: unknown;
    userId: string;
  };
  ecid: string;
  serial: string;
  unique: string;
}

export interface PhoneKeyStore {
  identity: IdentityKey;
  preKeys: PreKeyEntry[];
  signedPreKey: SignedPreKeyEntry;
}

export interface IdentityKey {
  hexPrivate: string;
  hexPublic: string;
  id: number;
  next_prekey_id: number;
  registration_id: number;
  timestamp: number;
}

export interface PreKeyEntry {
  hexKey: string;
  id: number;
  prekey_id: number;
  upload_time: number;
}

export interface SignedPreKeyEntry {
  hexKey: string;
  prekey_id: number;
  timestamp: number;
}

// ─── 解析结果类型 ────────────────────────────────────────────

export interface ParsedIdentity {
  /** 32 字节 Curve25519 私钥 */
  private: Uint8Array;
  /** 33 字节压缩公钥（含 0x05 前缀） */
  public: Uint8Array;
  registrationId: number;
  nextPrekeyId: number;
}

export interface ParsedPreKey {
  /** JSON 中的 prekey_id 字段 */
  preKeyId: number;
  /** 内部 id 字段（可能是服务端存储 ID） */
  internalId: number;
  /** 33 字节压缩公钥 */
  public: Uint8Array;
  /** 32 字节私钥 */
  private: Uint8Array;
  /** 时间戳/计数器（4 字节 big-endian） */
  timestamp: number;
  /** 上传时间（0 表示未上传） */
  uploadTime: number;
}

export interface ParsedSignedPreKey {
  /** 二进制格式中的 keyId（big-endian uint32） */
  keyId: number;
  /** JSON 中的 prekey_id 字段 */
  jsonPreKeyId: number;
  /** 33 字节压缩公钥 */
  public: Uint8Array;
  /** 105 字节签名 */
  signature: Uint8Array;
}

export interface ParsedExport {
  account: string;
  channel: string;
  nickname: string;
  deviceId: string;
  serial: string;
  ecid: string;
  identity: ParsedIdentity;
  noiseKey: KeyPair;
  signedPreKey: ParsedSignedPreKey;
  preKeys: ParsedPreKey[];
  minPreKeyId: number;
  maxPreKeyId: number;
  /** serverStaticPublic 是否为 null（致命缺口） */
  missingServerStatic: boolean;
  /** routingInfo 是否为 null */
  missingRoutingInfo: boolean;
}

// ─── 常量 ────────────────────────────────────────────────────

const PREKEY_TAG = 0x08;
const PREKEY_HEADER_SIZE = 6; // tag(1) + ts(4) + len(1)
const PUBKEY_LEN = 33;
const PRIVKEY_LEN = 32;
const PREKEY_TOTAL_SIZE = PREKEY_HEADER_SIZE + PUBKEY_LEN + 1 + PRIVKEY_LEN; // 72

const SIGNEDPREKEY_TAG = 0x08;
const SIGNEDPREKEY_HEADER_SIZE = 6; // tag(1) + keyId(4) + len(1)
const SIGNEDPREKEY_PUBKEY_OFFSET = SIGNEDPREKEY_HEADER_SIZE;
const SIGNEDPREKEY_SIG_OFFSET = SIGNEDPREKEY_HEADER_SIZE + PUBKEY_LEN; // 39
const SIGNEDPREKEY_TOTAL_SIZE = 148;
const SIGNEDPREKEY_MAX_SIZE = 149; // Some exports may have extra padding byte

// ─── 工具函数 ────────────────────────────────────────────────

function hexToBytes(hex: string): Uint8Array {
  const buf = Buffer.from(hex, 'hex');
  return new Uint8Array(buf);
}

function bytesToHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('hex');
}

// ─── 核心解析函数 ────────────────────────────────────────────

/**
 * 解析单个 PreKey（72 bytes）
 *
 * 格式（已验证）：
 *   [0x08] [3B counter] [0x21(len=33)] [0x05+32B pubkey] [0x1a] [0x20(len=32)] [32B privkey]
 *
 * 字节布局详解：
 *   byte[0]    = 0x08  (tag)
 *   bytes[1-3] = counter (big-endian, increments per preKey)
 *   byte[4]    = 0x21  (pubkey length = 33)
 *   bytes[5-37] = 33 bytes compressed public key (0x05 prefix + 32B x-coord)
 *   byte[38]   = 0x1a  (sub-type marker)
 *   byte[39]   = 0x20  (privkey length = 32)
 *   bytes[40-71] = 32 bytes private key material
 *
 * 总计: 1 + 3 + 1 + 33 + 1 + 1 + 32 = 72 bytes ✓
 */
export function parsePreKey(buf: Buffer, preKeyId: number, internalId: number): ParsedPreKey {
  if (buf.length !== PREKEY_TOTAL_SIZE) {
    throw new Error(
      `Invalid preKey length: expected ${PREKEY_TOTAL_SIZE}, got ${buf.length}`
    );
  }

  // Validate tag
  if (buf[0] !== PREKEY_TAG) {
    throw new Error(`Invalid preKey tag: expected 0x08, got 0x${buf[0].toString(16)}`);
  }

  // Parse counter (3 bytes big-endian at bytes 1-3)
  const counter = (buf[1] << 16) | (buf[2] << 8) | buf[3];

  // Validate pubkey length marker at byte[4]
  const pubkeyLenMarker = buf[4];
  if (pubkeyLenMarker !== PUBKEY_LEN) {
    throw new Error(`Invalid pubkey length marker: expected ${PUBKEY_LEN}, got ${pubkeyLenMarker}`);
  }

  // Extract compressed public key: bytes[5-37] = 33 bytes (0x05 prefix + 32B x-coord)
  const pubkey = buf.subarray(5, 5 + PUBKEY_LEN);

  // Validate pubkey format
  if (pubkey[0] !== 0x05 && pubkey[0] !== 0x02 && pubkey[0] !== 0x03) {
    throw new Error(`Invalid EC point format: 0x${pubkey[0].toString(16)}`);
  }

  // Validate privkey length marker at byte[39]
  const privkeyLenMarker = buf[39];
  if (privkeyLenMarker !== PRIVKEY_LEN) {
    throw new Error(`Invalid privkey length marker: expected ${PRIVKEY_LEN}, got ${privkeyLenMarker}`);
  }

  // Extract private key: bytes[40-71] = 32 bytes
  const privkey = buf.subarray(40, 40 + PRIVKEY_LEN);

  return {
    preKeyId,
    internalId,
    public: pubkey,
    private: privkey,
    timestamp: counter,
    uploadTime: 0,
  };
}

/**
 * 解析 SignedPreKey（支持 148 和 149 字节两种格式）
 *
 * 格式 1 (148 bytes, iOS 16.x):
 *   [0x08] [4B keyId] [0x21(len=33)] [0x05+32B pubkey] [105B sig] [0x00000000]
 *
 * 格式 2 (149 bytes, iOS 16.6+):
 *   [0x08] [4B keyId] [0x12] [0x21(len=33)] [0x05+32B pubkey] [105B sig] [0x00000000]
 *
 * 区别：格式 2 在 keyId 和 pubkeyLen 之间多了一个 0x12 字节
 */
export function parseSignedPreKey(buf: Buffer, jsonPreKeyId: number): ParsedSignedPreKey {
  if (buf.length !== SIGNEDPREKEY_TOTAL_SIZE && buf.length !== SIGNEDPREKEY_MAX_SIZE) {
    throw new Error(
      `Invalid signedPreKey length: expected ${SIGNEDPREKEY_TOTAL_SIZE} or ${SIGNEDPREKEY_MAX_SIZE}, got ${buf.length}`
    );
  }

  // Validate tag
  if (buf[0] !== SIGNEDPREKEY_TAG) {
    throw new Error(`Invalid signedPreKey tag: expected 0x08, got 0x${buf[0].toString(16)}`);
  }

  // Parse keyId (big-endian uint32 at bytes 1-4)
  const keyId = buf.readUInt32BE(1);

  // Detect format: check if byte[5] is pubkeyLen marker (0x21) or sub-marker (0x12)
  let pubkeyOffset: number;
  if (buf[5] === PUBKEY_LEN) {
    // Format 1: byte[5] = 0x21 (pubkeyLen)
    pubkeyOffset = 6;
  } else if (buf[6] === PUBKEY_LEN) {
    // Format 2: byte[5] = 0x12, byte[6] = 0x21 (pubkeyLen)
    pubkeyOffset = 7;
  } else {
    throw new Error(`Invalid pubkey length marker at offset: byte[5]=0x${buf[5].toString(16)}, byte[6]=0x${buf[6].toString(16)}`);
  }

  // Extract compressed public key
  const pubkey = buf.subarray(pubkeyOffset, pubkeyOffset + PUBKEY_LEN);

  // Validate pubkey format
  if (pubkey[0] !== 0x05 && pubkey[0] !== 0x02 && pubkey[0] !== 0x03) {
    throw new Error(`Invalid signedPreKey EC point format: 0x${pubkey[0].toString(16)}`);
  }

  // Signature starts right after pubkey
  const sigStart = pubkeyOffset + PUBKEY_LEN;
  // Signature end: before last 4 bytes (padding)
  const sigEnd = buf.length - 4;
  const signature = buf.subarray(sigStart, sigEnd);

  // Validate padding (last 4 bytes should be zero)
  const padding = buf.subarray(buf.length - 4);
  if (padding[0] !== 0x00 || padding[1] !== 0x00 || padding[2] !== 0x00 || padding[3] !== 0x00) {
    console.warn('SignedPreKey padding non-zero, may indicate corruption');
  }

  return {
    keyId,
    jsonPreKeyId,
    public: pubkey,
    signature,
  };
}

/**
 * 解析 Identity Key
 */
export function parseIdentityKey(identity: IdentityKey): ParsedIdentity {
  const priv = hexToBytes(identity.hexPrivate);
  const pub = hexToBytes(identity.hexPublic);

  if (priv.length !== 32) {
    throw new Error(`Invalid identity private key length: expected 32, got ${priv.length}`);
  }
  if (pub.length !== 33) {
    throw new Error(`Invalid identity public key length: expected 33, got ${pub.length}`);
  }
  if (pub[0] !== 0x05 && pub[0] !== 0x02 && pub[0] !== 0x03) {
    throw new Error(`Invalid identity EC point format: 0x${pub[0].toString(16)}`);
  }

  return {
    private: priv,
    public: pub,
    registrationId: identity.registration_id,
    nextPrekeyId: identity.next_prekey_id,
  };
}

/**
 * 解析 clientStaticKeypair（Noise 密钥）
 *
 * 这是一个独立的 32 字节 Curve25519 私钥，
 * 用于 Noise 协议握手，与 identity key 不同。
 */
export function parseNoiseKey(base64: string): KeyPair {
  const privBuf = Buffer.from(base64, 'base64');
  if (privBuf.length !== 32) {
    throw new Error(`Invalid noise key length: expected 32, got ${privBuf.length}`);
  }
  return {
    private: privBuf,
    // Public key will be derived at connection time
    public: Buffer.from(new Uint8Array(32)),
  };
}

/**
 * 主解析函数：从 WhatsApp 导出文件解析所有密钥
 */
export function parseWhatsAppExport(data: WhatsAppExportData): ParsedExport {
  const { identity, preKeys, signedPreKey } = data.data.phoneKeyStore;

  // Parse identity
  const parsedIdentity = parseIdentityKey(identity);

  // Parse noise key
  const noiseKey = parseNoiseKey(data.data.clientStaticKeypairBase64);

  // Parse signed pre-key
  const parsedSignedPreKey = parseSignedPreKey(
    Buffer.from(signedPreKey.hexKey, 'hex'),
    signedPreKey.prekey_id
  );

  // Parse all pre-keys
  const parsedPreKeys: ParsedPreKey[] = preKeys.map((pk) => {
    const buf = Buffer.from(pk.hexKey, 'hex');
    return parsePreKey(buf, pk.prekey_id, pk.id);
  });

  // Calculate pre-key range
  const preKeyIds = parsedPreKeys.map((pk) => pk.preKeyId);
  const minPreKeyId = Math.min(...preKeyIds);
  const maxPreKeyId = Math.max(...preKeyIds);

  return {
    account: data.account,
    channel: data.channel,
    nickname: data.data.nickname,
    deviceId: data.data.phoneId,
    serial: data.serial,
    ecid: data.ecid,
    identity: parsedIdentity,
    noiseKey,
    signedPreKey: parsedSignedPreKey,
    preKeys: parsedPreKeys,
    minPreKeyId,
    maxPreKeyId,
    missingServerStatic: data.data.serverStaticPublicBase64 === null,
    missingRoutingInfo: data.data.routingInfo === null,
  };
}

// ─── 导出 ────────────────────────────────────────────────────

export { hexToBytes, bytesToHex };
