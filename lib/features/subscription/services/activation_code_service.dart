/// 激活码服务层
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../services/backend_dio.dart';
import '../../../services/app_logger.dart';

/// 激活码套餐类型
enum ActivationPeriod {
  monthly('monthly', 1),
  quarterly('quarterly', 3),
  halfYearly('halfYearly', 6),
  yearly('yearly', 12);

  const ActivationPeriod(this.apiName, this.months);
  final String apiName;
  final int months;
}

/// 激活码详情（服务端返回）
class ActivationCodeInfo {
  final String code;
  final int seats;
  final ActivationPeriod period;
  final String createdBy;
  final DateTime createdAt;
  final bool redeemed;
  final String? usedByUserId;
  final DateTime? usedAt;

  const ActivationCodeInfo({
    required this.code,
    required this.seats,
    required this.period,
    required this.createdBy,
    required this.createdAt,
    required this.redeemed,
    this.usedByUserId,
    this.usedAt,
  });

  factory ActivationCodeInfo.fromJson(Map<String, dynamic> json) {
    return ActivationCodeInfo(
      code: json['code'] as String? ?? '',
      seats: json['seats'] as int? ?? 1,
      period: ActivationPeriod.values.firstWhere(
        (e) => e.apiName == json['period'],
        orElse: () => ActivationPeriod.yearly,
      ),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      redeemed: json['redeemed'] == true,
      usedByUserId: json['usedByUserId'] as String?,
      usedAt: json['usedAt'] != null ? DateTime.tryParse(json['usedAt'] as String) : null,
    );
  }
}

/// 激活结果
class ActivationResult {
  final bool success;
  final bool isPremium;
  final ActivationPeriod period;
  final int months;
  final String message;

  ActivationResult({
    required this.success,
    required this.isPremium,
    required this.period,
    required this.months,
    required this.message,
  });

  factory ActivationResult.error(String error) {
    return ActivationResult(
      success: false,
      isPremium: false,
      period: ActivationPeriod.yearly,
      months: 0,
      message: 'error',
    ).._errorMessage = error;
  }

  String? _errorMessage;
  String get errorMessage => _errorMessage ?? '';
}

/// 激活码服务。
///
/// 负责向 /api/v1/activate/activate 发送请求并解析响应。
/// 调用前需确保用户已登录（accessToken 非空），否则抛 [StateError]。
class ActivationCodeService {
  ActivationCodeService({required String baseUrl, String? appVersion})
    : _dio = createBackendDio(
        baseUrl: baseUrl,
        appVersion: appVersion,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        apiLogTag: 'ACTIVATION',
      );

  ActivationCodeService.withDio(this._dio);

  final Dio _dio;

  /// 验证并激活一个激活码。
  ///
  /// [accessToken] 来自 [authSessionProvider]。
  Future<ActivationResult> activate({
    required String code,
    required String accessToken,
    required String userId,
  }) async {
    if (accessToken.isEmpty) {
      return ActivationResult.error('未登录，无法激活');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/activate/activate',
        data: {'code': code.trim().toUpperCase()},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      if (data == null) {
        return ActivationResult.error('服务器响应为空');
      }
      if (data['success'] != true) {
        final err = data['error'] as String?;
        if (err?.contains('已被使用') == true) {
          return ActivationResult.error('activationErrorUsed');
        }
        if (err?.contains('无效') == true || err?.contains('expired') == true) {
          return ActivationResult.error('activationErrorInvalid');
        }
        return ActivationResult.error(err ?? 'activationErrorInvalid');
      }
      final entitlement = data['entitlement'] as Map<String, dynamic>?;
      if (entitlement == null) {
        return ActivationResult.error('服务器返回数据异常');
      }
      final periodStr = entitlement['period'] as String? ?? 'yearly';
      final period = ActivationPeriod.values.firstWhere(
        (e) => e.apiName == periodStr,
        orElse: () => ActivationPeriod.yearly,
      );
      return ActivationResult(
        success: true,
        isPremium: entitlement['isPremium'] == true,
        period: period,
        months: period.months,
        message: data['message'] as String? ?? '激活成功',
      );
    } on DioException catch (e) {
      AppLogger.log('Activation', 'Dio error: ${e.type} ${e.response?.statusCode}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return ActivationResult.error('activationErrorNetwork');
      }
      if (e.response?.statusCode == 401) {
        return ActivationResult.error('未登录，请重新登录后再试');
      }
      return ActivationResult.error('activationErrorNetwork');
    } catch (e) {
      AppLogger.log('Activation', 'Error: $e');
      return ActivationResult.error('activationErrorNetwork');
    }
  }

  /// 管理员生成激活码（需要 X-Admin-Key header）。
  Future<List<String>> generateCodes({
    required String accessToken,
    required int seats,
    required ActivationPeriod period,
    required String createdBy,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/activate/generate',
        data: {
          'seats': seats,
          'period': period.apiName,
          'createdBy': createdBy,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'X-Admin-Key': _adminKey,
          },
        ),
      );
      final data = response.data;
      if (data?['success'] != true) {
        throw Exception(data?['error'] ?? '生成失败');
      }
      return List<String>.from(data?['codes'] ?? []);
    } on DioException catch (e) {
      AppLogger.log('Activation', 'Generate error: ${e.type}');
      throw Exception(e.response?.data?['error'] ?? '网络错误');
    }
  }

  /// 查询当前用户已使用的激活码列表。
  Future<List<ActivationCodeInfo>> getMyCodes(String accessToken) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/activate/my-codes',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      if (data?['success'] != true) return [];
      final rawCodes = data?['codes'] as List<dynamic>? ?? [];
      return rawCodes
          .whereType<Map<String, dynamic>>()
          .map((e) => ActivationCodeInfo.fromJson(e))
          .toList();
    } catch (e) {
      AppLogger.log('Activation', 'getMyCodes error: $e');
      return [];
    }
  }
}

/// 静态管理员密钥（生产环境应从环境变量注入）
const _adminKey = String.fromEnvironment(
  'ADMIN_KEY',
  defaultValue: 'echo-loop-admin-key-change-me-in-production',
);

final activationCodeServiceProvider = Provider<ActivationCodeService>((ref) {
  return ActivationCodeService(baseUrl: apiBaseUrl);
});
