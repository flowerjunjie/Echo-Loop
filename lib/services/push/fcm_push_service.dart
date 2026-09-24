/// FCM 远程推送服务
///
/// 负责：
/// 1. 获取设备 FCM token 并上报后端
/// 2. 前后台消息接收与处理
/// 3. 通知权限请求
///
/// 使用 [firebase_messaging] 实现，依赖 [FirebaseCore] 已在 main.dart 初始化。
library;

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../services/app_logger.dart';
import 'package:dio/dio.dart';

/// 路由跳转桥接接口，允许 FCM 服务在不直接依赖 UI 的情况下导航。
/// 由 main.dart 提供全局实例，供 FCM 回调使用。
abstract class NavigationBridge {
  /// 跳转到指定路径（无参数）
  void goTo(String path);

  /// 跳转到指定路径并携带 extra 参数
  void goToPath(String path, Object? extra);
}

/// 全局路由跳转桥接单例，由 main.dart 在启动时设置。
NavigationBridge? _globalNavigationBridge;

/// 设置全局导航桥接（由 main.dart 调用一次）
void setNavigationBridge(NavigationBridge bridge) {
  _globalNavigationBridge = bridge;
}

/// 获取当前导航桥接实例
NavigationBridge? get navigationBridge => _globalNavigationBridge;

/// FCM 推送服务
///
/// 管理设备 token 与消息回调，供业务层订阅状态变化。
class FcmPushService {
  FcmPushService({required this.messaging, this.authToken});

  final FirebaseMessaging messaging;

  /// 用户认证 token，用于上报 FCM token 到后端。
  /// 由调用方（main.dart）在登录成功后设置。
  final String? authToken;

  /// 当前设备的 FCM token，null 表示未授权或未获取到
  String? _token;

  /// 是否已请求通知权限
  bool _permissionGranted = false;

  /// 获取当前 token（可能为 null）
  String? get token => _token;

  /// 是否已授权通知
  bool get permissionGranted => _permissionGranted;

  /// 初始化 FCM 推送服务
  ///
  /// 1. 请求通知权限（iOS/Android）
  /// 2. 监听 token 刷新
  /// 3. 注册前台/后台/终止消息处理器
  Future<void> initialize() async {
    if (kIsWeb) {
      AppLogger.log('FCM', 'Web 平台不支持 FCM，跳过初始化');
      return;
    }

    // 请求通知权限
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _permissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
    AppLogger.log('FCM', '通知权限: ${_permissionGranted ? "已授权" : "已拒绝"}');

    // 获取初始 token
    _token = await messaging.getToken();
    AppLogger.log('FCM', 'FCM token: ${_token?.substring(0, _token!.length.clamp(0, 20))}...');
    if (_token != null) _reportTokenToBackend(_token!);

    // 监听 token 刷新（设备更换 token 时更新）
    messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      AppLogger.log('FCM', 'Token 刷新: ${newToken.substring(0, newToken.length.clamp(0, 20))}...');
      _reportTokenToBackend(newToken);
    });

    // 前台消息处理
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 后台/终止消息处理
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // 应用从终止状态启动（点击通知打开 App）
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.log('FCM', '初始消息: ${initialMessage.data}');
      _handleBackgroundMessage(initialMessage);
    }
  }

  /// 处理前台收到的消息
  ///
  /// 前台时 App 已有 UI，仅记录通知内容日志，不自动路由。
  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '无标题';
    final body = message.notification?.body ?? '';
    final data = message.data;
    AppLogger.log('FCM', '前台消息: title=$title body=$body data=$data');
  }

  /// 处理后台/终止时点击通知打开 App
  ///
  /// 根据 [message.data] 中的 [type] 字段路由到对应页面：
  /// - 'reminder' → /study
  /// - 'review' → /flashcard
  /// - 其他/无 → /
  void _handleBackgroundMessage(RemoteMessage message) {
    final type = message.data['type'];
    final targetPath = switch (type) {
      'reminder' => '/study',
      'review' => '/flashcard',
      _ => '/',
    };
    AppLogger.log('FCM', '通知点击路由: type=$type → $targetPath');
    // 通过全局导航桥接跳转，避免直接依赖 GoRouter
    _globalNavigationBridge?.goTo(targetPath);
  }

  /// 将 FCM token 上报到后端 /api/v1/device/fcm-token。
  ///
  /// 使用 [dio] 发送 POST 请求，自动携带 Authorization Bearer token（由调用方注入）。
  /// 失败时仅记录日志，不抛出——token 上报是 best-effort 操作。
  Future<void> _reportTokenToBackend(String token) async {
    if (token.isEmpty) return;
    try {
      final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
      if (authToken != null && authToken!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $authToken';
      }
      await dio.post('/api/v1/device/fcm-token', data: {'fcmToken': token});
      AppLogger.log('FCM', 'Token 上报成功');
    } catch (e) {
      AppLogger.log('FCM', 'Token 上报失败: $e');
    }
  }

  /// 手动触发 token 上报（供外部在登录成功后调用）。
  void reportToken() {
    if (_token != null && _token!.isNotEmpty) {
      unawaited(_reportTokenToBackend(_token!));
    }
  }

  /// 检查当前通知权限状态
  Future<bool> checkPermission() async {
    if (kIsWeb) return false;
    final settings = await messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}

/// FCM 推送服务 Provider
///
/// 接受可选的 [dio] 和 [authToken] 参数，便于测试注入和登录后上报 token。
final fcmPushServiceProvider = Provider<FcmPushService>((ref) {
  return FcmPushService(messaging: FirebaseMessaging.instance);
});
