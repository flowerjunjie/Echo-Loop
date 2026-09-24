/// Web版邀请码服务
///
/// 调用 echo-transcribe 后端 API 获取当前用户的邀请码信息。
/// 仅 Web 平台可用，移动端使用 [InviteService]。
library;

import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import '../app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 邀请码信息
class WebInviteInfo {
  final String inviteCode;
  final int friendsSignedUp;
  final int monthsEarned;

  const WebInviteInfo({
    required this.inviteCode,
    required this.friendsSignedUp,
    required this.monthsEarned,
  });

  factory WebInviteInfo.fromJson(Map<String, dynamic> json) {
    final info = json['inviteInfo'] as Map<String, dynamic>? ?? {};
    return WebInviteInfo(
      inviteCode: info['inviteCode'] as String? ?? '',
      friendsSignedUp: info['friendsSignedUp'] as int? ?? 0,
      monthsEarned: info['monthsEarned'] as int? ?? 0,
    );
  }
}

/// Web版邀请码服务
class WebInviteService {
  final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  /// 获取当前用户的邀请码信息
  Future<WebInviteInfo?> getInviteInfo({String? token}) async {
    try {
      final response = await _dio.get(
        '/api/v1/invite/info',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      if (response.data is Map) {
        return WebInviteInfo.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.log('WebInvite', 'getInviteInfo failed: $e');
      return null;
    }
  }
}

/// Web版邀请码服务 Provider
final webInviteServiceProvider = Provider<WebInviteService>((ref) {
  return WebInviteService();
});
