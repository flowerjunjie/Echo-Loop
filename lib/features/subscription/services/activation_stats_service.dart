/// 激活码统计数据服务
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../services/backend_dio.dart';
import '../../../services/app_logger.dart';

/// 激活码统计摘要
class ActivationStatsSummary {
  final int totalCodes;
  final int usedCodes;
  final int unusedCodes;
  final int redemptionRate;
  final int totalSeats;
  final int usedSeats;
  final int unusedSeats;

  const ActivationStatsSummary({
    required this.totalCodes,
    required this.usedCodes,
    required this.unusedCodes,
    required this.redemptionRate,
    required this.totalSeats,
    required this.usedSeats,
    required this.unusedSeats,
  });

  factory ActivationStatsSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return ActivationStatsSummary(
      totalCodes: summary['totalCodes'] as int? ?? 0,
      usedCodes: summary['usedCodes'] as int? ?? 0,
      unusedCodes: summary['unusedCodes'] as int? ?? 0,
      redemptionRate: summary['redemptionRate'] as int? ?? 0,
      totalSeats: summary['totalSeats'] as int? ?? 0,
      usedSeats: summary['usedSeats'] as int? ?? 0,
      unusedSeats: summary['unusedSeats'] as int? ?? 0,
    );
  }
}

/// 按套餐类型的统计
class PeriodStats {
  final String period;
  final int total;
  final int used;

  const PeriodStats({required this.period, required this.total, required this.used});

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    return PeriodStats(
      period: json['period'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      used: json['used'] as int? ?? 0,
    );
  }
}

/// 每日统计数据
class DailyStat {
  final String date;
  final int generated;
  final int activated;

  const DailyStat({required this.date, required this.generated, required this.activated});

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    return DailyStat(
      date: json['date'] as String? ?? '',
      generated: json['generated'] as int? ?? 0,
      activated: json['activated'] as int? ?? 0,
    );
  }
}

/// 创建人统计
class CreatorStats {
  final String createdBy;
  final int total;
  final int used;

  const CreatorStats({required this.createdBy, required this.total, required this.used});

  factory CreatorStats.fromJson(Map<String, dynamic> json) {
    return CreatorStats(
      createdBy: json['createdBy'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 完整统计数据
class ActivationStats {
  final ActivationStatsSummary summary;
  final List<PeriodStats> byPeriod;
  final List<CreatorStats> byCreator;
  final List<DailyStat> dailyStats;
  final DateTime generatedAt;

  const ActivationStats({
    required this.summary,
    required this.byPeriod,
    required this.byCreator,
    required this.dailyStats,
    required this.generatedAt,
  });

  factory ActivationStats.fromJson(Map<String, dynamic> json) {
    final byPeriodRaw = json['byPeriod'] as Map<String, dynamic>? ?? {};
    final byPeriod = byPeriodRaw.entries
        .map((e) => PeriodStats(
              period: e.key,
              total: (e.value['total'] as num?)?.toInt() ?? 0,
              used: (e.value['used'] as num?)?.toInt() ?? 0,
            ))
        .toList();

    final byCreatorRaw = json['byCreator'] as Map<String, dynamic>? ?? {};
    final byCreator = byCreatorRaw.entries
        .map((e) => CreatorStats(
              createdBy: e.key,
              total: (e.value['total'] as num?)?.toInt() ?? 0,
              used: (e.value['used'] as num?)?.toInt() ?? 0,
            ))
        .toList();

    final dailyRaw = json['dailyStats'] as List<dynamic>? ?? [];
    final dailyStats = dailyRaw
        .whereType<Map<String, dynamic>>()
        .map((e) => DailyStat.fromJson(e))
        .toList();

    return ActivationStats(
      summary: ActivationStatsSummary.fromJson(json),
      byPeriod: byPeriod,
      byCreator: byCreator,
      dailyStats: dailyStats,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// 激活码统计服务
class ActivationStatsService {
  ActivationStatsService({required String baseUrl, String? appVersion})
      : _dio = createBackendDio(
          baseUrl: baseUrl,
          appVersion: appVersion,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          apiLogTag: 'ACTIVATION_STATS',
        );

  ActivationStatsService.withDio(this._dio);

  final Dio _dio;

  static const _adminKey = String.fromEnvironment(
      'ADMIN_KEY',
        defaultValue: 'echo-loop-admin-key-change-me-in-production',
    );

  /// 获取激活码统计数据
  Future<ActivationStats> getStats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/activate/stats',
        options: Options(
          headers: {'X-Admin-Key': _adminKey},
        ),
      );
      final data = response.data;
      if (data?['success'] != true) {
        throw Exception(data?['error'] ?? '获取统计失败');
      }
      return ActivationStats.fromJson(data!);
    } on DioException catch (e) {
      AppLogger.log('ActivationStats', 'Error: ${e.type} ${e.response?.statusCode}');
      throw Exception(e.response?.data?['error'] ?? '网络错误');
    } catch (e) {
      AppLogger.log('ActivationStats', 'Error: $e');
      throw Exception(e.toString());
    }
  }
}

final activationStatsServiceProvider = Provider<ActivationStatsService>((ref) {
  return ActivationStatsService(baseUrl: apiBaseUrl);
});
