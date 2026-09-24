/// Web 平台安全路由常量
///
/// 仅包含 Web 端可用的路由路径，避免 FFI 依赖。
library;

/// Web 端路由路径（与 AppRoutes 兼容的最小集合）
abstract class AppRoutes {
  // 已有
  static const activityCalendar = '/activity-calendar';
  static String audioLearningPlan(String audioId, {bool autoStart = false}) =>
      autoStart
          ? '/study/$audioId?autoStart=true'
          : '/study/$audioId';
  static const learningPlan = '/learning-plan';
  /// 直达播放器（Web 端无需经过学习计划页）
  static String audioPlayer(String audioId) => '/audio/$audioId/player';
  // 新增：Web 路由所需的导航常量
  static const study = '/study';
  static const sentenceDetail = '/sentence-detail';
  static const bookmarkReview = '/bookmark-review';
}
