/// 邀请裂变服务层
library;

import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../config/app_config.dart';
import '../../../services/backend_dio.dart';
import '../../../services/app_logger.dart';

/// 邀请记录（服务器返回）
class InviteRecord {
  final String inviteCode;
  final int friendsSignedUp;
  final int monthsEarned;

  const InviteRecord({
    required this.inviteCode,
    required this.friendsSignedUp,
    required this.monthsEarned,
  });

  factory InviteRecord.fromJson(Map<String, dynamic> json) {
    return InviteRecord(
      inviteCode: json['inviteCode'] as String? ?? '',
      friendsSignedUp: json['friendsSignedUp'] as int? ?? 0,
      monthsEarned: json['monthsEarned'] as int? ?? 0,
    );
  }
}

/// 邀请服务。
///
/// 通过后端 [/api/v1/invite] 获取邀请码、统计邀请进度，
/// 以及将第三方平台带来的新用户关联到邀请人。
class InviteService {
  InviteService({required String baseUrl, String? appVersion})
    : _dio = createBackendDio(
        baseUrl: baseUrl,
        appVersion: appVersion,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        apiLogTag: 'INVITE',
      );

  InviteService.withDio(this._dio);

  final Dio _dio;

  /// 构建当前用户的邀请分享链接（deep link）。
  ///
  /// 返回格式：
  ///   Android/iOS：`app.echoloop://invite?code=ABC12345`
  ///   Web：`https://灵犀.ai/invite?code=ABC12345`（fallback）
  String buildInviteLink(String inviteCode) {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return '';
    return 'app.echoloop://invite?code=$code';
  }

  /// 构建带邀请码的分享文案（供 [Share.share] 使用）。
  ///
  /// 统一使用 deep link，iOS/Android 均可通过链接唤起 App。
  String buildShareText(String inviteCode) {
    final code = inviteCode.trim().toUpperCase();
    // Web 邀请页链接（微信等场景不支持 deep link）
    final webUrl = inviteUrl(code);
    return '🎁 邀请好友，双方都得会员！\n\n用我的邀请码【$code】注册灵犀AI英语听说，我们各得7天会员。\n\n👉 点击注册：$webUrl\n\n#英语学习 #AI工具';
  }

  /// 获取当前用户的邀请信息（邀请码 + 统计数据）。
  Future<InviteRecord> getInviteInfo({
    required String accessToken,
  }) async {
    if (accessToken.isEmpty) {
      throw const InviteException('未登录');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/invite/info',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      if (data == null || data['success'] != true) {
        throw InviteException(data?['error'] ?? '获取邀请信息失败');
      }
      final info = data['inviteInfo'] as Map<String, dynamic>?;
      if (info == null) {
        throw const InviteException('服务器返回数据异常');
      }
      return InviteRecord.fromJson(info);
    } on DioException catch (e) {
      AppLogger.log('Invite', 'Dio error: ${e.type} ${e.response?.statusCode}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const InviteException('inviteErrorNetwork');
      }
      if (e.response?.statusCode == 401) {
        throw const InviteException('请先登录后使用邀请功能');
      }
      throw InviteException(e.response?.data?['error'] ?? '网络错误');
    } catch (e) {
      AppLogger.log('Invite', 'Error: $e');
      rethrow;
    }
  }

  /// 记录本次安装/注册来自哪个邀请码。
  ///
  /// [inviteCode] 来自 deep link 或分享链接参数。
  /// [platform] 当前平台，'ios' / 'android' / 'web'。
  Future<void> attribution({
    required String inviteCode,
    required String platform,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/invite/attribution',
        data: {'inviteCode': inviteCode.trim().toUpperCase(), 'platform': platform},
        options: Options(),
      );
      AppLogger.log('Invite', 'attribution: code=$inviteCode platform=$platform');
    } catch (e) {
      AppLogger.log('Invite', 'attribution error: $e');
      // 异步归因失败不影响主流程，静默忽略
    }
  }
}

/// 邀请相关异常。
class InviteException implements Exception {
  const InviteException(this.message);
  final String message;
  @override
  String toString() => 'InviteException: $message';
}

final inviteServiceProvider = Provider<InviteService>((ref) {
  return InviteService(baseUrl: apiBaseUrl);
});
