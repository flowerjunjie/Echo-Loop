/// VM/Web stub for flutter_local_notifications.
///
/// 提供最小接口满足编译，不执行实际通知操作。
/// 生产平台（iOS/Android）由真实 flutter_local_notifications 包提供实现。
library;

import 'package:timezone/timezone.dart' as tz;

// Re-export dart:ffi to satisfy Pointer/Utf8 dependencies from transitive win32
export 'dart:ffi';

// ── Platform-specific implementations ────────────────────────────────────────

/// Android 平台通知实现 stub。
class AndroidFlutterLocalNotificationsPlugin {
  /// 当前是否已启用系统通知（仅 Android）
  Future<bool?> areNotificationsEnabled() async => null;

  /// 请求通知权限（仅 Android）
  Future<bool?> requestNotificationsPermission() async => null;

  /// 请求通知策略访问权限
  Future<void> requestNotificationPolicyAccess() async {}
}

/// iOS 平台通知实现 stub。
class IOSFlutterLocalNotificationsPlugin {}

/// macOS 平台通知实现 stub。
class MacOSFlutterLocalNotificationsPlugin {}

// ── Main Plugin ───────────────────────────────────────────────────────────────

/// 通知响应类型 stub
enum NotificationResponseType {
  selectedNotification,
  selectedNotificationAction,
}

/// Notification response payload stub.
class NotificationResponse {
  const NotificationResponse({
    this.id,
    this.actionId,
    this.input,
    this.payload,
    this.notificationResponseType,
  });
  final String? id;
  final String? actionId;
  final String? input;
  final String? payload;
  final NotificationResponseType? notificationResponseType;
}

/// 通知详情 stub（Android/iOS/macOS/Windows/Linux）
class NotificationDetails {
  const NotificationDetails({
    this.android,
    this.iOS,
    this.macOS,
    this.windows,
    this.linux,
  });
  final AndroidNotificationDetails? android;
  final DarwinNotificationDetails? iOS;
  final DarwinNotificationDetails? macOS;
  final WindowsNotificationDetails? windows;
  final LinuxNotificationDetails? linux;
}

/// Android 通知详情 stub
class AndroidNotificationDetails {
  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.channelShowBadge = true,
    this.importance = Importance.defaultImportance,
    this.priority = Priority.defaultPriority,
    this.playSound = true,
    this.enableVibration = true,
    this.styleInformation,
  });
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final bool channelShowBadge;
  final Importance importance;
  final Priority priority;
  final bool playSound;
  final bool enableVibration;
  final dynamic styleInformation;
}

/// Darwin (iOS/macOS) 通知详情 stub
class DarwinNotificationDetails {
  const DarwinNotificationDetails({
    this.sound,
    this.badgeNumber,
    this.attachments,
    this.categoryIdentifier,
    this.interruptionLevel,
  });
  final String? sound;
  final int? badgeNumber;
  final List<dynamic>? attachments;
  final String? categoryIdentifier;
  final dynamic interruptionLevel;
}

/// Windows 通知详情 stub
class WindowsNotificationDetails {
  const WindowsNotificationDetails({this.toastContent, this.header});
  final dynamic toastContent;
  final dynamic header;
}

/// Linux 通知详情 stub
class LinuxNotificationDetails {
  const LinuxNotificationDetails({
    this.summary,
    this.body,
    this.appName,
    this.icon,
    this.importance,
    this.timeout,
  });
  final String? summary;
  final String? body;
  final String? appName;
  final dynamic icon;
  final dynamic importance;
  final Duration? timeout;
}

// ── Initialization Settings ──────────────────────────────────────────────────

/// 初始化设置 stub
class InitializationSettings {
  const InitializationSettings({
    this.android,
    this.iOS,
    this.macOS,
    this.web,
    this.windows,
    this.linux,
  });
  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;
  final DarwinInitializationSettings? macOS;
  final WebInitializationSettings? web;
  final WindowsInitializationSettings? windows;
  final LinuxInitializationSettings? linux;
}

/// Android 初始化设置 stub
class AndroidInitializationSettings {
  const AndroidInitializationSettings([this.defaultIcon = '@mipmap/ic_launcher']);
  final String defaultIcon;
}

/// Darwin (iOS/macOS) 初始化设置 stub
class DarwinInitializationSettings {
  const DarwinInitializationSettings({
    this.requestAlertPermission = true,
    this.requestBadgePermission = true,
    this.requestSoundPermission = true,
    this.canPresentAlert = true,
    this.canPresentBadge = true,
    this.canPresentSound = true,
    this.alertAction = 'View',
    this.notificationCategories = const [],
    this.threadDismissAction,
    this.threadInsertAction,
    this.muted,
  });
  final bool requestAlertPermission;
  final bool requestBadgePermission;
  final bool requestSoundPermission;
  final bool canPresentAlert;
  final bool canPresentBadge;
  final bool canPresentSound;
  final String alertAction;
  final List<dynamic> notificationCategories;
  final dynamic threadDismissAction;
  final dynamic threadInsertAction;
  final bool? muted;
}

/// Web 初始化设置 stub
class WebInitializationSettings {
  const WebInitializationSettings({this.popupPermission = true});
  final bool popupPermission;
}

/// Windows 初始化设置 stub
class WindowsInitializationSettings {
  const WindowsInitializationSettings();
}

/// Linux 初始化设置 stub
class LinuxInitializationSettings {
  const LinuxInitializationSettings({
    this.defaultActionName,
    this.defaultPackageName,
    this.defaultAppIcon,
  });
  final String? defaultActionName;
  final String? defaultPackageName;
  final dynamic defaultAppIcon;
}

// ── Enums ─────────────────────────────────────────────────────────────────────

/// 通知调度匹配组件 stub
class DateTimeComponents {
  const DateTimeComponents._();
  static const DateTimeComponents dateAndTime = _DateTimeComponentsDateAndTime();
  static const DateTimeComponents time = _DateTimeComponentsTime();
  static const DateTimeComponents date = _DateTimeComponentsDate();
}
class _DateTimeComponentsDateAndTime extends DateTimeComponents { const _DateTimeComponentsDateAndTime() : super._(); }
class _DateTimeComponentsTime extends DateTimeComponents { const _DateTimeComponentsTime() : super._(); }
class _DateTimeComponentsDate extends DateTimeComponents { const _DateTimeComponentsDate() : super._(); }

/// 通知重要性级别 stub
enum Importance {
  defaultImportance,
  noImportance,
  min,
  low,
  high,
  max,
}

/// 通知优先级 stub
enum Priority {
  defaultPriority,
  min,
  low,
  high,
  highOverFullScreen,
  max,
}

/// Android 调度模式 stub
enum AndroidScheduleMode {
  exactAllowWhileIdle,
  inexactAllowWhileIdle,
  exact,
  inexact,
}

// ── Scheduling ────────────────────────────────────────────────────────────────

/// Cron 表达式 stub
class CronExpression {
  const CronExpression(String expression);
}

/// 重复间隔 stub
class RepeatInterval {
  static const RepeatInterval daily = _DailyRepeatInterval();
  static const RepeatInterval hourly = _HourlyRepeatInterval();
  const RepeatInterval._();
}
class _DailyRepeatInterval extends RepeatInterval { const _DailyRepeatInterval() : super._(); }
class _HourlyRepeatInterval extends RepeatInterval { const _HourlyRepeatInterval() : super._(); }

/// 主插件 stub
class FlutterLocalNotificationsPlugin {
  /// 初始化通知插件
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  /// 查询平台特定实现
  T? resolvePlatformSpecificImplementation<T>() => null;

  /// 取消单条通知
  Future<void> cancel(int id) async {}

  /// 取消所有通知
  Future<void> cancelAll() async {}

  /// 显示通知
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {}

  /// 定时显示通知
  Future<void> schedule(
    int id,
    String? title,
    String? body,
    DateTime scheduledDate,
    NotificationDetails? notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    RepeatInterval? repeatInterval,
    String? payload,
  }) async {}

  /// 时区定时显示通知
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails? notificationDetails, {
    AndroidScheduleMode? androidScheduleMode,
    RepeatInterval? repeatInterval,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {}

  /// 获取应用启动时来自通知的详情
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async => null;

  /// 获取指定 ID 的通知详情
  Future<PendingNotificationRequest?> getPendingNotificationRequest(int id) async => null;

  /// 获取待处理通知列表
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async => [];

  /// 上报已处理的通知响应
  Future<void> acknowledgeNotificationResponseReceived(String actionId) async {}

  /// 上报已清除的通知
  Future<void> clearNotification(String actionId) async {}

  /// 查询通知权限状态
  Future<NotificationAuthorizationStatus> getNotificationAppAuthorizationStatus() async {
    return NotificationAuthorizationStatus.notDetermined;
  }

  /// 请求通知权限
  Future<NotificationAuthorizationStatus> requestPermissions({
    bool alert = true,
    bool badge = true,
    bool sound = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool announcement = false,
    bool soundAndInlineResponse = false,
  }) async {
    return NotificationAuthorizationStatus.authorized;
  }
}

/// 通知授权状态 stub
enum NotificationAuthorizationStatus {
  notDetermined,
  authorized,
  denied,
  provisional,
  ephemeral,
}

/// 通知响应回调类型 stub
typedef DidReceiveNotificationResponseCallback = void Function(NotificationResponse);

/// 后台通知响应回调类型 stub
typedef DidReceiveBackgroundNotificationResponseCallback = void Function(NotificationResponse);

/// 通知应用启动详情 stub
class NotificationAppLaunchDetails {
  const NotificationAppLaunchDetails(
    this.didNotificationLaunchApp, {
    this.notificationResponse,
  });
  final bool? didNotificationLaunchApp;
  final NotificationResponse? notificationResponse;
}

/// 待处理通知请求 stub
class PendingNotificationRequest {
  const PendingNotificationRequest({required this.id, required this.title, required this.body});
  final int id;
  final String? title;
  final String? body;
}

/// 通知权限 stub
class NotificationPermission {
  static Future<bool> isNotificationPolicyAccessGranted() async => false;
  static Future<void> requestNotificationPolicyAccess() async {}
}


