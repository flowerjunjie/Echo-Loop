// 应用级 Web 资源配置
//
// 集中管理所有面向用户的 Web URL，避免硬编码 IP/域名散落各处。
// 通过 `--dart-define` 注入生产值，开发环境 fallback 到本地地址。
//
// 构建时注入示例：
//   --dart-define=APP_WEB_BASE_URL=https://echo-loop.top
//   --dart-define=PRIVACY_URL=https://echo-loop.top/privacy
//   --dart-define=SUPPORT_URL=https://echo-loop.top/support
library;

/// Web 端基础 URL（落地页 + 各子页面宿主）
///
/// 生产环境通过 `--dart-define=APP_WEB_BASE_URL=https://echo-loop.top` 注入。
/// 未注入时 fallback 到正式域名（DNS 生效后生效）；本地开发请通过 --dart-define 覆盖。
const appWebBaseUrl = String.fromEnvironment(
  'APP_WEB_BASE_URL',
  defaultValue: 'https://echo-loop.top',
);

/// 隐私政策页面 URL
///
/// 生产环境通过 `--dart-define=PRIVACY_URL=https://echo-loop.top/privacy` 注入。
const privacyUrl = String.fromEnvironment(
  'PRIVACY_URL',
  defaultValue: 'https://echo-loop.top/privacy',
);

/// 服务条款页面 URL
///
/// 生产环境通过 `--dart-define=TERMS_URL=https://echo-loop.top/terms` 注入。
const termsUrl = String.fromEnvironment(
  'TERMS_URL',
  defaultValue: 'https://echo-loop.top/terms',
);

/// 用户支持/帮助页面 URL
///
/// 生产环境通过 `--dart-define=SUPPORT_URL=https://echo-loop.top/support` 注入。
/// 未注入时 fallback 到落地页。
const supportUrl = String.fromEnvironment(
  'SUPPORT_URL',
  defaultValue: 'https://echo-loop.top',
);

/// 邀请活动落地页 URL 模板
///
/// [code] 为邀请码，拼接后得到完整链接。
/// 生产环境邀请链接应使用域名而非 IP，构建时确保 [appWebBaseUrl] 已注入域名。
String inviteUrl(String code) => '$appWebBaseUrl/invite/$code';

/// 动态路径拼接（用于通用页面跳转）
///
/// [path] 以 `/` 开头，例如 `/privacy`、`/terms`。
String webPath(String path) => '$appWebBaseUrl$path';
