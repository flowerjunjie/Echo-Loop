/// Web 平台路由配置
///
/// 仅包含不依赖 sqlite3/sherpa_onnx/FFI 的页面。
/// 首页为 [WebHomeScreen]，提供录音、设置、日志三个入口。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/asr_settings_screen.dart';
import '../screens/asr_test_screen.dart';
import '../screens/dictionary_settings_screen.dart';
import '../screens/blind_listen_player_screen.dart';
import '../screens/collection_detail_screen.dart';
import '../screens/flashcard_screen.dart';
import '../screens/intensive_listen_player_screen.dart';
import '../screens/learning_plan_screen.dart';
import '../screens/listen_and_repeat_player_screen.dart';
import '../screens/player_screen.dart';
import '../screens/review_difficult_practice_screen.dart';
import '../screens/bookmark_review_screen.dart';
import '../screens/learning_settings_screen.dart';
import '../screens/log_viewer_screen.dart';
import '../screens/playback_settings_screen.dart';
import '../screens/preferences_viewer_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/reminder_settings_screen.dart';
import '../screens/sentence_detail_screen.dart';
import '../screens/study_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/tts_settings_screen.dart';
import '../screens/web_home_screen.dart';
import '../screens/web_settings_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/activity_calendar_screen.dart';
import '../features/auth/screens/account_screen.dart';
import '../features/auth/screens/check_email_screen.dart';
import '../features/auth/screens/email_sign_in_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/password_sign_in_screen.dart';
import '../features/onboarding_survey/screens/onboarding_survey_screen.dart';
import '../features/subscription/screens/paywall_screen.dart';
import '../features/official_collections/screens/discover_collections_screen.dart';
import '../features/official_collections/screens/official_collection_detail_screen.dart';
import '../features/subscription/screens/activation_code_screen.dart';
import '../features/subscription/screens/activation_stats_screen.dart';
import '../features/subscription/screens/enhanced_stats_screen.dart';
import '../features/subscription/screens/invite_screen.dart';
import '../screens/audio_detail_screen.dart';

/// Web 端路由 Provider
final webAppRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      /// 资源库首页
      GoRoute(
        path: '/',
        builder: (context, state) => WebHomeScreen(),
      ),
      
      /// 登录页
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      
      /// 邀请码注册
      GoRoute(
        path: '/invite/:code',
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return InviteScreen(inviteCode: code);
        },
      ),
      
      /// 隐私政策
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      
      /// 服务条款
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsScreen(),
      ),
      // Web 专属页面（不依赖 drift/FFI）
      GoRoute(
        path: '/playback-settings',
        builder: (context, state) => const PlaybackSettingsScreen(),
      ),
      GoRoute(
        path: '/log-viewer',
        builder: (context, state) => const LogViewerScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const WebSettingsScreen(),
      ),
      // 官方合集发现页（纯 API/catalog，enroll 按钮在 Web 端隐藏）
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoverCollectionsScreen(),
      ),
      // 学习设置页（纯 SP 读写，无 drift）
      GoRoute(
        path: '/learning-settings',
        builder: (context, state) => const LearningSettingsScreen(),
      ),
      // ASR 设置页（纯 SP 读写，Platform 判断在 Web 安全）
      GoRoute(
        path: '/asr-settings',
        builder: (context, state) => const AsrSettingsScreen(),
      ),
      // 偏好设置查看页（纯 SP 读写，Web 可用）
      GoRoute(
        path: '/preferences-viewer',
        builder: (context, state) => const PreferencesViewerScreen(),
      ),
      // 提醒设置页（kIsWeb 守卫完善，Web 端自动跳过通知权限）
      GoRoute(
        path: '/reminder-settings',
        builder: (context, state) => const ReminderSettingsScreen(),
      ),
      // TTS 设置页（纯 SP 读写，Platform 判断在 Web 安全返回 false）
      GoRoute(
        path: '/tts-settings',
        builder: (context, state) => const TtsSettingsScreen(),
      ),
      // 词典设置页（纯 provider 读写，无 drift/FFI 依赖）
      GoRoute(
        path: '/dictionary-settings',
        builder: (context, state) => const DictionarySettingsScreen(),
      ),
      // 单词卡片复习页（flashcard_provider 的 drift 通过 providers_web.dart stub 覆盖）
      GoRoute(
        path: '/flashcard',
        builder: (context, state) => const FlashcardScreen(),
      ),
      // 播放器页（kIsWeb 守卫完善，collection/sentenceAI stub 可覆盖）
      GoRoute(
        path: '/player',
        builder: (context, state) => const PlayerScreen(),
      ),
      // 全文盲听页（无 drift 导入，provider stub 可覆盖）
      GoRoute(
        path: '/blind-listen',
        builder: (context, state) => const BlindListenPlayerScreen(audioItemId: ''),
      ),
      // 跟读练习页（无 drift 导入，provider stub 可覆盖）
      GoRoute(
        path: '/listen-and-repeat',
        builder: (context, state) => const ListenAndRepeatPlayerScreen(audioItemId: ''),
      ),
      // 难句补练页（无 drift 导入，provider stub 可覆盖）
      GoRoute(
        path: '/review-difficult',
        builder: (context, state) => const ReviewDifficultPracticeScreen(audioItemId: ''),
      ),
      // 官方合集详情页（纯 API，无 drift 依赖）
      GoRoute(
        path: '/discover/:collectionId',
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          return OfficialCollectionDetailScreen(remoteId: collectionId);
        },
      ),
      // 学习主页（audioLibrary + learningProgress + studyTask 等 provider 均已有 stub）
      GoRoute(
        path: '/study',
        builder: (context, state) => const StudyScreen(),
      ),
      // 用户合集详情页
      GoRoute(
        path: '/collection/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CollectionDetailScreen(collectionId: id);
        },
      ),
      // ASR 录音测试页面（Web 可用，通过 echo-transcribe API 转录）
      GoRoute(
        path: '/asr-test',
        builder: (context, state) => const AsrTestScreen(),
      ),
      // 收藏复习页（drift 通过 providers_web.dart stub 覆盖）
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      // 活动日历页（study stats provider stub 已覆盖）
      GoRoute(
        path: '/activity-calendar',
        builder: (context, state) => const ActivityCalendarScreen(),
      ),
      // 句子详情页（无 drift/FFI，provider stub 覆盖数据库依赖；通过 extra 传入参数）
      GoRoute(
        path: '/sentence-detail',
        builder: (context, state) {
          final args = state.extra! as SentenceDetailArgs;
          return SentenceDetailScreen(args: args);
        },
      ),
      // 收藏复习页（drift 通过 providers_web.dart stub 覆盖；专注盲听/跟读，无 FFI 直接依赖）
      GoRoute(
        path: '/bookmark-review',
        builder: (context, state) => const BookmarkReviewScreen(),
      ),
      // 逐句精听播放器（drift 通过 providers_web.dart stub 覆盖；AudioEngine 在 Web 用浏览器原生播放）
      GoRoute(
        path: '/intensive-listen/:audioId',
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          return IntensiveListenPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
          );
        },
      ),
      // 独立音频学习计划页（audioItemDao / collectionDao stub 已覆盖 drift 依赖）
      GoRoute(
        path: '/audio/:audioId/plan',
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final autoStart =
              state.uri.queryParameters['autoStart'] == 'true';
          return LearningPlanScreen(
            collectionId: null,
            audioItemId: audioId,
            autoStart: autoStart,
          );
        },
      ),
      // 音频详情页（从合集列表点击单个音频时进入，显示音频信息与操作按钮）
      GoRoute(
        path: '/audio/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AudioDetailScreen(audioId: id);
        },
      ),
      // 邮箱登录页（纯 API 调用，无 drift 依赖；Web 端初始邮箱为空字符串）
      GoRoute(
        path: '/login/email',
        builder: (context, state) => const EmailSignInScreen(initialEmail: ''),
      ),
      // 邮箱确认页（纯 API 调用，无 drift 依赖；Web 端初始邮箱为空字符串）
      GoRoute(
        path: '/login/check-email',
        builder: (context, state) => const CheckEmailScreen(email: ''),
      ),
      // 密码登录页（App Store 审核员专用隐藏入口，纯 API 调用）
      GoRoute(
        path: '/login/password',
        builder: (context, state) => const PasswordSignInScreen(),
      ),
      // 账户设置页（仅 SP 读写 + 订阅状态，无 drift 依赖）
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      // 订阅付费墙页（RevenueCat API，Web 端走托管结账流程）
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          final extra = state.extra;
          final source = extra is Map && extra['source'] != null
              ? extra['source'] as String
              : 'subscription_screen';
          return PaywallScreen(source: source);
        },
      ),
      // 激活码输入页（纯 API 调用，无 drift 依赖）
      GoRoute(
        path: '/activation-code',
        builder: (context, state) => const ActivationCodeScreen(),
      ),
      // 激活码统计页（纯 API 调用，无 drift 依赖）
      GoRoute(
        path: '/activation-stats',
        builder: (context, state) => const ActivationStatsScreen(),
      ),
      // 增强统计页（纯 API 调用，无 drift 依赖）
      GoRoute(
        path: '/enhanced-stats',
        builder: (context, state) => const EnhancedStatsScreen(),
      ),
      // 新用户引导问卷页（纯 SP 读写，无 drift 依赖）
      GoRoute(
        path: '/onboarding/survey',
        builder: (context, state) => const OnboardingSurveyScreen(),
      ),
    ],
  );
});
