// @ts-nocheck
/**
 * 联系人服务
 *
 * 获取和管理 WhatsApp 联系人列表
 */

import type { Contact } from '@whiskeysockets/baileys';

// 联系人存储: jid -> Contact
const contactsMap = new Map<string, Contact>();

/**
 * 更新联系人
 */
export function upsertContacts(contacts: Contact[]): void {
  for (const contact of contacts) {
    contactsMap.set(contact.id, contact);
  }
}

/**
 * 获取所有联系人
 */
export function getAllContacts(): Contact[] {
  return Array.from(contactsMap.values());
}

/**
 * 搜索联系人
 */
export function searchContacts(query: string): Contact[] {
  const q = query.toLowerCase();
  return Array.from(contactsMap.values()).filter(c =>
    (c.title?.toLowerCase().includes(q) || c.id.includes(q))
  );
}

/**
 * 获取联系人数量
 */
export function getContactCount(): number {
  return contactsMap.size;
}

/**
 * 清空联系人
 */
export function clearContacts(): void {
  contactsMap.clear();
}
