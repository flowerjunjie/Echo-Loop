/// Web 平台入口点（最小化版本）
///
/// 条件导入隔离FFI依赖，提供完整的Web版本体验。
/// 包含 PostHog 埋点通道，与移动端保持一致的数据采集能力。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── 核心模块（无 FFI 依赖）─────────────────────────────────────────
import 'l10n/app_localizations.dart';
import 'utils/time_format.dart';
import 'router/web_router.dart';
import 'theme/app_theme.dart';
import 'providers/package_info_provider.dart';
import 'providers/privacy_consent_provider.dart';
import 'analytics/analytics_providers.dart';
import 'analytics/consent_manager.dart';
import 'screens/privacy_consent_screen.dart';

/// 生成匿名 userId（Web 端不登录，用随机 UUID 保持会话一致）
String _generateAnonymousUserId() {
  return 'web_anon_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000).toString().padLeft(4, '0')}';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
  ));

  initTimeago();

  final packageInfo = await PackageInfo.fromPlatform();
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = !(prefs.getBool('first_launch_done') ?? false);
  if (isFirstLaunch) {
    await prefs.setBool('first_launch_done', true);
  }

  // ── PostHog 埋点初始化 ────────────────────────────────────────
  // Web 端使用 PostHog JS SDK（通过 posthog_flutter web 支持自动加载）
  // 与移动端共用同一 Project API Key，事件可统一在 PostHog Dashboard 查看
  // ── 隐私同意检测（与移动端对齐）──────────────────────────────────
  // Web 端虽无 Supabase，但同样遵守 GDPR / 个保法，需用户明确同意后采集数据。
  final consentManager = ConsentManager(prefs);
  final needsConsent = !consentManager.hasConsented;

  final analyticsService = await initAnalyticsService(prefs, userId: _generateAnonymousUserId());
  initAnalytics(analyticsService);

  runApp(
    PostHogWidget(
      // Session Replay 对 Web 端到端追踪非常有用，必须包裹
      child: ProviderScope(
        overrides: [
          packageInfoProvider.overrideWithValue(packageInfo),
          needsConsentProvider.overrideWithValue(needsConsent),
        ],
        child: const EchoLoopWebApp(),
      ),
    ),
  );
}

/// Web 版主应用
class EchoLoopWebApp extends ConsumerStatefulWidget {
  const EchoLoopWebApp({super.key});

  @override
  ConsumerState<EchoLoopWebApp> createState() => _EchoLoopWebAppState();
}

class _EchoLoopWebAppState extends ConsumerState<EchoLoopWebApp> {
  @override
  void initState() {
    super.initState();
    // 未同意时展示隐私同意弹窗（barrierDismissible=false 强制选择）
    if (ref.read(needsConsentProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final allowed = await showPrivacyConsentDialog(context);
        final sp = await SharedPreferences.getInstance();
        if (allowed) {
          ConsentManager(sp).grantConsent();
        } else {
          ConsentManager(sp).revokeConsent();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(webAppRouterProvider);

    return MaterialApp.router(
      title: '灵犀AI英语听说',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      routerConfig: router,
    );
  }
}
