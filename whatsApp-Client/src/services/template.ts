// @ts-nocheck
/**
 * 消息模板服务
 * 支持变量替换的消息模板
 */

import { logger } from '../logger';

interface MessageTemplate {
  id: string;
  name: string;
  content: string;
  variables: string[];
  createdAt: number;
}

const templates: Map<string, MessageTemplate> = new Map();

export function createTemplate(template: Omit<MessageTemplate, 'variables' | 'createdAt'>): MessageTemplate {
  const id = template.id || 'tmpl-' + Date.now();
  const variables = extractVariables(template.content);
  const fullTemplate: MessageTemplate = {
    ...template,
    id,
    variables,
    createdAt: Date.now(),
  };
  templates.set(id, fullTemplate);
  logger.info(`[Template] Created: ${template.name} (${variables.length} variables)`);
  return fullTemplate;
}

export function getTemplate(id: string): MessageTemplate | undefined {
  return templates.get(id);
}

export function listTemplates(): MessageTemplate[] {
  return Array.from(templates.values());
}

export function deleteTemplate(id: string): boolean {
  return templates.delete(id);
}

export function renderTemplate(id: string, variables: Record<string, string>): string {
  const tmpl = templates.get(id);
  if (!tmpl) throw new Error('Template not found: ' + id);
  let content = tmpl.content;
  for (const [key, value] of Object.entries(variables)) {
    content = content.replace(new RegExp('\\$\\{' + key + '\\}', 'g'), value);
  }
  return content;
}

function extractVariables(content: string): string[] {
  const matches = content.match(/\$\{(\w+)\}/g) || [];
  return [...new Set(matches.map(m => m.slice(2, -1)))];
}
