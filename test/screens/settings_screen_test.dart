/// SettingsScreen 测试
///
/// 测试设置页面的渲染和交互。
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/providers/app_update_provider.dart';
import 'package:echo_loop/providers/developer_options_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/screens/settings_screen.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';

import 'package:echo_loop/features/subscription/providers/subscription_availability.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/package_info_provider.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 可注入初始状态的 AuthSessionNotifier 替身。
class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(AuthResponse? initial) : super();
  @override
  Future<void> setSession(AuthResponse response) async {
    state = response;
  }
}

void main() {
  final testPackageInfo = PackageInfo(
    appName: '灵犀AI英语听说',
    packageName: 'top.echo-loop',
    version: '1.0.0',
    buildNumber: '1',
  );

  // 词典设置等同步读取 SharedPreferences 的 provider 需注入实例
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> buildOverrides({
    AppSettingsState settings = const AppSettingsState(),
    bool showDeveloperOptions = true,
    bool showOfflineAsrSection = false,
    OfflineAsrSettingsState? offlineAsrState,
    TtsSettings ttsSettings = const TtsSettings(),
    PackageInfo? packageInfo,
    // 测试宿主（macOS/无 key）默认不支持订阅，这里默认置 true 以覆盖订阅入口 UI。
    bool subscriptionAvailable = true,
    AuthResponse? authResponse,
  }) {
    const recommendedModel = AsrModelInfo(
      id: 'whisper-base-en-int8',
      displayName: 'Whisper Base.en',
      type: AsrModelType.whisper,
    );
    return [
      ...learningSettingsOverrides(prefs: prefs),
      appSettingsProvider.overrideWith(() => TestAppSettings(settings)),
      initialTtsSettingsProvider.overrideWithValue(ttsSettings),
      showDeveloperOptionsProvider.overrideWith(
        () => _TestDeveloperOptions(showDeveloperOptions),
      ),
      showOfflineAsrSectionProvider.overrideWithValue(showOfflineAsrSection),
      recommendedAsrModelProvider.overrideWithValue(recommendedModel),
      initialOfflineAsrSettingsStateProvider.overrideWithValue(
        offlineAsrState ??
            OfflineAsrSettingsState(recommendedModel: recommendedModel),
      ),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      packageInfoProvider.overrideWithValue(packageInfo ?? testPackageInfo),
      appUpdateProvider.overrideWith(() => TestAppUpdate()),
      subscriptionAvailabilityProvider.overrideWithValue(subscriptionAvailable),
      analyticsOverride(),
      if (authResponse != null)
        authSessionProvider.overrideWith((ref) => _FakeAuthSessionNotifier(authResponse)),
    ];
  }

  group('SettingsScreen', () {
    group('渲染', () {
      testWidgets('显示主题设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Theme'), findsOneWidget);
        // 默认 system 模式（主题和语言都显示"Follow System"）
        expect(find.text('Follow System'), findsAtLeast(1));
      });

      testWidgets('显示语言设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Interface Language'), findsOneWidget);
        // 默认跟随系统
        expect(find.text('Follow System'), findsAtLeast(1));
      });

      testWidgets('显示关于信息区域', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('About'), findsOneWidget);
        expect(find.text('Terms of Service'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Write Feedback'), findsOneWidget);
        // 版本标签在页面底部，需要滚动到可见
        await tester.scrollUntilVisible(find.textContaining('Version'), 200);
        await tester.pumpAndSettle();
        expect(find.text('Version 1.0.0 (Debug)'), findsOneWidget);
      });

      testWidgets('iOS 显示评价我们入口', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await tester.pumpWidget(
            createTestScreen(
              const SettingsScreen(),
              overrides: buildOverrides(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Rate Us'), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('非 iOS 不显示评价我们入口', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await tester.pumpWidget(
            createTestScreen(
              const SettingsScreen(),
              overrides: buildOverrides(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Rate Us'), findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('已登录时账号区显示登录邮箱', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(authResponse: AuthResponse(
              userId: 'user-1',
              email: 'user@example.com',
              accessToken: 'token',
              refreshToken: 'refresh',
            )),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('user@example.com'), findsOneWidget);
      });

      testWidgets('Apple 登录在账号入口显示邮箱地址', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(authResponse: AuthResponse(
              userId: 'user-1',
              email: 'mbfpw8sdy7@privaterelay.appleid.com',
              accessToken: 'token',
              refreshToken: 'refresh',
            )),
          ),
        );
        await tester.pumpAndSettle();

        // 简化后统一显示邮箱，不再区分登录方式
        expect(find.text('mbfpw8sdy7@privaterelay.appleid.com'), findsOneWidget);
      });

      testWidgets('Google 登录在账号入口显示截断的邮箱地址', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(authResponse: AuthResponse(
              userId: 'user-1',
              email: 'long.google.account@example.com',
              accessToken: 'token',
              refreshToken: 'refresh',
            )),
          ),
        );
        await tester.pumpAndSettle();

        // 超长邮箱会被截断
        expect(find.text('long.google.accou...@example.com'), findsOneWidget);
      });

      testWidgets('邮箱登录账号区显示邮箱地址', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(authResponse: AuthResponse(
              userId: 'user-1',
              email: 'user@example.com',
              accessToken: 'token',
              refreshToken: 'refresh',
            )),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('user@example.com'), findsOneWidget);
      });

      testWidgets('Apple relay 邮箱正常显示', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(authResponse: AuthResponse(
              userId: 'user-1',
              email: 'mbfpw8sdy7@privaterelay.appleid.com',
              accessToken: 'token',
              refreshToken: 'refresh',
            )),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('mbfpw8sdy7@privaterelay.appleid.com'), findsOneWidget);
      });

      testWidgets('未订阅：账户分组内显示订阅入口与「升级」徽章，无顶部金卡', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              subscriptionControllerProvider.overrideWith(
                () =>
                    _TestSubscriptionController(const EntitlementState.free()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 订阅行标题（沿用 premiumEntryTitle）+ 未订阅高亮「升级」徽章
        expect(find.text('Subscription'), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
        final upgradeBadge = tester.widget<Text>(find.text('Upgrade'));
        expect(upgradeBadge.style?.color, const Color(0xFF111111));
        // 顶部不再有大金卡的「会员」状态徽章
        expect(find.text('Member'), findsNothing);
      });

      testWidgets('已订阅：显示「会员」徽章与套餐摘要', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              subscriptionControllerProvider.overrideWith(
                () => _TestSubscriptionController(
                  const EntitlementState(
                    status: EntitlementStatus.premium,
                    entitlement: Entitlement(
                      isPremium: true,
                      productId: 'pro_yearly',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 保持简洁：只有标题 + 「会员」徽章，无副标题详情
        expect(find.text('Subscription'), findsOneWidget);
        expect(find.text('Member'), findsOneWidget);
        expect(find.text('Upgrade'), findsNothing);
      });

      testWidgets('点击订阅入口跳转 Paywall', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              subscriptionControllerProvider.overrideWith(
                () =>
                    _TestSubscriptionController(const EntitlementState.free()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Subscription'));
        await tester.pumpAndSettle();

        expect(find.text('Paywall'), findsOneWidget);
      });

      testWidgets('平台未启用订阅：不显示订阅入口', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(subscriptionAvailable: false),
              subscriptionControllerProvider.overrideWith(
                () =>
                    _TestSubscriptionController(const EntitlementState.free()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Subscription'), findsNothing);
        expect(find.text('Upgrade'), findsNothing);
      });

      testWidgets('显示外观标题', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Appearance'), findsOneWidget);
      });

      testWidgets('Speech Recognition 入口仅在开关启用时显示', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(showOfflineAsrSection: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Learning'), findsOneWidget);
        expect(find.text('Speech Recognition'), findsOneWidget);
      });

      testWidgets('语音合成入口显示当前平台引擎，不显示口音', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        final expectedPlatformEngine = Platform.isIOS || Platform.isMacOS
            ? 'Apple AI'
            : 'System Speech';

        expect(find.text('Text-to-Speech'), findsOneWidget);
        expect(find.text(expectedPlatformEngine), findsOneWidget);
        expect(find.text('American'), findsNothing);
      });

      testWidgets('语音合成入口显示 灵犀AI英语听说 引擎', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              ttsSettings: const TtsSettings(engine: TtsEngineKind.echoLoop),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Text-to-Speech'), findsOneWidget);
        expect(find.text('灵犀AI英语听说 AI'), findsOneWidget);
      });

      testWidgets('开发者选项关闭时不显示开发者分组', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(showDeveloperOptions: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Developer'), findsNothing);
        expect(find.text('Time Machine'), findsNothing);
      });

      testWidgets('开发者选项开启且未设置时时显示系统时间文案', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 滚动到开发者区域
        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();

        expect(find.text('Developer'), findsOneWidget);
        expect(find.text('Time Machine'), findsOneWidget);
        expect(find.text('Using system time'), findsOneWidget);
      });

      testWidgets('开发者选项开启且已设置时时显示当前调试时间', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              settings: AppSettingsState(
                timeMachineDateTime: DateTime(2026, 3, 11, 22, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 滚动到开发者区域
        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();

        // 调试时间显示在 Time Machine 对话框中，先点击打开
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Debug time:'), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击主题设置弹出选择对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 点击主题设置项
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();

        // 应弹出对话框，显示三个选项
        expect(find.text('Light Mode'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
        // 对话框标题 + 列表中的 Follow System
        expect(find.text('Follow System'), findsAtLeast(1));
      });

      testWidgets('选择 Dark 主题后状态更新', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 打开主题选择对话框
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();

        // 选择 Dark Mode
        await tester.tap(find.text('Dark Mode'));
        await tester.pumpAndSettle();

        // 对话框关闭后，应显示 Dark Mode
        expect(find.text('Dark Mode'), findsOneWidget);
      });

      testWidgets('点击语言设置弹出选择对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 点击语言设置项
        await tester.tap(find.text('Interface Language'));
        await tester.pumpAndSettle();

        // 应弹出对话框，显示三个选项
        expect(find.text('Follow System'), findsAtLeast(1));
        expect(find.text('English'), findsAtLeast(1));
        expect(find.text('简体中文'), findsAtLeast(1));
      });

      testWidgets('点击时光机弹出设置对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        expect(find.text('Select date'), findsOneWidget);
        expect(find.text('Select time'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('点击恢复系统时间并保存后清除时光机', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              settings: AppSettingsState(
                timeMachineDateTime: DateTime(2026, 3, 11, 22, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Use system time'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Using system time'), findsOneWidget);
        expect(find.text('Debug time: 2026-03-11 22:15'), findsNothing);
      });
    });
  });
}

/// 测试用 SubscriptionController，固定返回指定权益状态，
/// 跳过真实对账（避免依赖 RevenueCat / 缓存 / 后端）。
class _TestSubscriptionController extends SubscriptionController {
  _TestSubscriptionController(this._state);
  final EntitlementState _state;

  @override
  EntitlementState build() => _state;
}

/// 测试用 DeveloperOptions Notifier，固定返回指定值。
class _TestDeveloperOptions extends DeveloperOptions {
  final bool _value;
  _TestDeveloperOptions(this._value);

  @override
  bool build() => _value;

  @override
  Future<void> setEnabled(bool value) async {
    state = value;
  }
}
