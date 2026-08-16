// @ts-nocheck
/**
 * 翻译服务
 *
 * 支持：Google Translate（免费）、DeepL、OpenAI、DeepSeek
 * 可打开/关闭、选择翻译渠道和目标语言
 */

import axios from 'axios';
import type { TranslationProvider, TranslationConfig, ChatMessage } from '../types';
import { logger } from '../logger';

const DEFAULT_CONFIG: TranslationConfig = {
  enabled: false,
  provider: 'google',
  targetLang: 'zh',
  autoDetect: true,
  minMessageLength: 3,
  batchSize: 20,
};

let config: TranslationConfig = { ...DEFAULT_CONFIG };
let apiKeys: Record<string, string> = {};

// ─── 配置管理 ────────────────────────────────────────────────

export function setTranslationConfig(cfg: Partial<TranslationConfig>): void {
  config = { ...config, ...cfg };
  logger.info(`[Translation] Config updated: provider=${config.provider}, targetLang=${config.targetLang}, enabled=${config.enabled}`);
}

export function getTranslationConfig(): TranslationConfig {
  return { ...config };
}

export function setProviderApiKey(provider: TranslationProvider, key: string): void {
  apiKeys[provider] = key;
}

// ─── 翻译入口 ────────────────────────────────────────────────

export async function translateText(text: string, targetLang?: string): Promise<string> {
  if (!config.enabled || !text || text.length < (config.minMessageLength || 3)) {
    return text;
  }

  const lang = targetLang || config.targetLang;

  try {
    switch (config.provider) {
      case 'google': return await translateViaGoogle(text, lang);
      case 'deepl': return await translateViaDeepL(text, lang);
      case 'openai': return await translateViaOpenAI(text, lang);
      case 'deepseek': return await translateViaDeepSeek(text, lang);
      default: return await translateViaGoogle(text, lang);
    }
  } catch (err) {
    logger.error('[Translation] Translation failed:', err);
    return text; // 翻译失败返回原文
  }
}

export async function translateBatch(
  messages: ChatMessage[],
  targetLang?: string
): Promise<Map<string, string>> {
  const results = new Map<string, string>();
  const lang = targetLang || config.targetLang;
  const batchSize = config.batchSize || 20;

  for (let i = 0; i < messages.length; i += batchSize) {
    const batch = messages.slice(i, i + batchSize);
    const texts = batch.map(m => m.body).filter(t => t && t.length >= (config.minMessageLength || 3));

    if (texts.length === 0) continue;

    try {
      let translated: string[];
      switch (config.provider) {
        case 'google': translated = await batchTranslateGoogle(texts, lang); break;
        case 'deepl': translated = await batchTranslateDeepL(texts, lang); break;
        case 'openai': translated = await batchTranslateOpenAI(texts, lang); break;
        case 'deepseek': translated = await batchTranslateDeepSeek(texts, lang); break;
        default: translated = await batchTranslateGoogle(texts, lang);
      }

      batch.forEach((m, idx) => {
        if (translated[idx]) {
          results.set(m.id, translated[idx]);
        }
      });
    } catch (err) {
      logger.error('[Translation] Batch translation failed:', err);
    }

    // 批次间随机延迟，避免触发限流
    await sleep(200 + Math.random() * 500);
  }

  return results;
}

// ─── Google Translate（免费，无需 API Key）────────────────────

async function translateViaGoogle(text: string, lang: string): Promise<string> {
  const url = 'https://translate.googleapis.com/translate_a/single';
  const params = new URLSearchParams({
    client: 'gtx',
    sl: 'auto',
    tl: lang,
    dt: 't',
    q: text,
  });
  const res = await axios.get(`${url}?${params.toString()}`, { timeout: 10000 });
  const result = res.data as any[];
  if (Array.isArray(result) && result[0] && result[0][0]) {
    return result[0][0][0] as string;
  }
  return text;
}

async function batchTranslateGoogle(texts: string[], lang: string): Promise<string[]> {
  // Google Translate free API 不支持批量，逐条翻译
  return Promise.all(texts.map(t => translateViaGoogle(t, lang)));
}

// ─── DeepL（需 API Key）─────────────────────────────────────

async function translateViaDeepL(text: string, lang: string): Promise<string> {
  const key = apiKeys['deepl'];
  if (!key) throw new Error('DeepL API key not configured');

  const targetLang = lang === 'zh' ? 'zh-Hans' : lang;
  const res = await axios.post(
    'https://api.deepl.com/v2/translate',
    { text, target_lang: targetLang },
    { headers: { 'Authorization': `DeepL-Key ${key}` }, timeout: 10000 }
  );
  return res.data.translations?.[0]?.text || text;
}

async function batchTranslateDeepL(texts: string[], lang: string): Promise<string[]> {
  const key = apiKeys['deepl'];
  if (!key) throw new Error('DeepL API key not configured');
  const targetLang = lang === 'zh' ? 'zh-Hans' : lang;

  const res = await axios.post(
    'https://api.deepl.com/v2/translate',
    { texts, target_lang: targetLang },
    { headers: { 'Authorization': `DeepL-Key ${key}` }, timeout: 15000 }
  );
  return res.data.translations?.map((t: any) => t.text) || texts;
}

// ─── OpenAI（ChatGPT 翻译）───────────────────────────────────

async function translateViaOpenAI(text: string, lang: string): Promise<string> {
  const key = apiKeys['openai'];
  if (!key) throw new Error('OpenAI API key not configured');

  const langNames: Record<string, string> = {
    zh: 'Simplified Chinese', en: 'English', ja: 'Japanese', ko: 'Korean',
    es: 'Spanish', fr: 'French', de: 'German', ru: 'Russian', ar: 'Arabic',
  };
  const targetName = langNames[lang] || lang;

  const res = await axios.post(
    'https://api.openai.com/v1/chat/completions',
    {
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: `Translate the following text to ${targetName}. Only output the translation, nothing else.\n\n${text}` }],
      max_tokens: 500,
    },
    { headers: { Authorization: `Bearer ${key}` }, timeout: 15000 }
  );
  return res.data.choices?.[0]?.message?.content?.trim() || text;
}

async function batchTranslateOpenAI(texts: string[], lang: string): Promise<string[]> {
  // OpenAI 不原生支持批量翻译，逐条处理
  return Promise.all(texts.map(t => translateViaOpenAI(t, lang)));
}

// ─── DeepSeek（国内可用，性价比高）───────────────────────────

async function translateViaDeepSeek(text: string, lang: string): Promise<string> {
  const key = apiKeys['deepseek'];
  if (!key) throw new Error('DeepSeek API key not configured');

  const langNames: Record<string, string> = {
    zh: '中文', en: 'English', ja: '日本語', ko: '한국어',
    es: 'Español', fr: 'Français', de: 'Deutsch', ru: 'Русский',
  };
  const targetName = langNames[lang] || lang;

  const res = await axios.post(
    'https://api.deepseek.com/v1/chat/completions',
    {
      model: 'deepseek-chat',
      messages: [{ role: 'user', content: `将以下文字翻译成${targetName}，只输出翻译结果：\n\n${text}` }],
      max_tokens: 500,
    },
    { headers: { Authorization: `Bearer ${key}` }, timeout: 15000 }
  );
  return res.data.choices?.[0]?.message?.content?.trim() || text;
}

async function batchTranslateDeepSeek(texts: string[], lang: string): Promise<string[]> {
  return Promise.all(texts.map(t => translateViaDeepSeek(t, lang)));
}

// ─── 工具函数 ────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise(r => setTimeout(r, ms));
}
