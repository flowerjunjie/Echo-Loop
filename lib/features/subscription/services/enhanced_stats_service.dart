/// 增强版统计服务 - 提供更多数据分析维度
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../services/backend_dio.dart';
import '../../../services/app_logger.dart';

/// 增强版统计数据
class EnhancedStats {
  /// 基础统计
  final BasicStats basic;
  
  /// 收益分析
  final RevenueStats revenue;
  
  /// 用户活跃度
  final ActivityStats activity;
  
  /// 预警信息
  final Alerts alerts;
  
  /// 趋势预测
  final TrendStats trend;
  
  /// 生成时间
  final DateTime generatedAt;

  const EnhancedStats({
    required this.basic,
    required this.revenue,
    required this.activity,
    required this.alerts,
    required this.trend,
    required this.generatedAt,
  });

  factory EnhancedStats.fromJson(Map<String, dynamic> json) {
    return EnhancedStats(
      basic: BasicStats.fromJson(json['summary'] ?? {}),
      revenue: RevenueStats.fromJson(json['revenue'] ?? {}),
      activity: ActivityStats.fromJson(json['activationPattern'] ?? {}),
      alerts: Alerts.fromJson(json['alerts'] ?? {}),
      trend: TrendStats.fromJson(json['dailyStats'] ?? []),
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// 基础统计
class BasicStats {
  final int totalCodes;
  final int usedCodes;
  final int unusedCodes;
  final int redemptionRate;
  final int totalSeats;
  final int usedSeats;
  final int unusedSeats;

  const BasicStats({
    required this.totalCodes,
    required this.usedCodes,
    required this.unusedCodes,
    required this.redemptionRate,
    required this.totalSeats,
    required this.usedSeats,
    required this.unusedSeats,
  });

  factory BasicStats.fromJson(Map<String, dynamic> json) {
    return BasicStats(
      totalCodes: json['totalCodes'] as int? ?? 0,
      usedCodes: json['usedCodes'] as int? ?? 0,
      unusedCodes: json['unusedCodes'] as int? ?? 0,
      redemptionRate: json['redemptionRate'] as int? ?? 0,
      totalSeats: json['totalSeats'] as int? ?? 0,
      usedSeats: json['usedSeats'] as int? ?? 0,
      unusedSeats: json['unusedSeats'] as int? ?? 0,
    );
  }
}

/// 收益统计
class RevenueStats {
  final int total;
  final int potential;
  final String currency;

  const RevenueStats({
    required this.total,
    required this.potential,
    required this.currency,
  });

  factory RevenueStats.fromJson(Map<String, dynamic> json) {
    return RevenueStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      potential: (json['potential'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'CNY',
    );
  }
}

/// 活跃度统计
class ActivityStats {
  final List<int> byHour;
  final List<int> byDay;

  const ActivityStats({
    required this.byHour,
    required this.byDay,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    return ActivityStats(
      byHour: (json['byHour'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ?? [],
      byDay: (json['byDay'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ?? [],
    );
  }
}

/// 预警统计
class Alerts {
  final int expiringSoon;
  final int unusedExpiring;

  const Alerts({
    required this.expiringSoon,
    required this.unusedExpiring,
  });

  factory Alerts.fromJson(Map<String, dynamic> json) {
    return Alerts(
      expiringSoon: json['expiringSoon'] as int? ?? 0,
      unusedExpiring: json['unusedExpiring'] as int? ?? 0,
    );
  }
}

/// 趋势统计
class TrendStats {
  final List<DailyTrend> dailyData;

  const TrendStats({required this.dailyData});

  factory TrendStats.fromJson(List<dynamic> json) {
    return TrendStats(
      dailyData: json.map((e) => DailyTrend.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class DailyTrend {
  final String date;
  final int generated;
  final int activated;

  const DailyTrend({
    required this.date,
    required this.generated,
    required this.activated,
  });

  factory DailyTrend.fromJson(Map<String, dynamic> json) {
    return DailyTrend(
      date: json['date'] as String? ?? '',
      generated: json['generated'] as int? ?? 0,
      activated: json['activated'] as int? ?? 0,
    );
  }
}

/// 增强版统计服务
class EnhancedStatsService {
  EnhancedStatsService({required String baseUrl, String? appVersion})
      : _dio = createBackendDio(
          baseUrl: baseUrl,
          appVersion: appVersion,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          apiLogTag: 'ENHANCED_STATS',
        );

  EnhancedStatsService.withDio(this._dio);

  final Dio _dio;

  static const _adminKey = String.fromEnvironment(
      'ADMIN_KEY',
        defaultValue: 'echo-loop-admin-key-change-me-in-production',
    );

  Future<EnhancedStats> getEnhancedStats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/activate/stats',
        options: Options(headers: {'X-Admin-Key': _adminKey}),
      );
      final data = response.data;
      if (data?['success'] != true) {
        throw Exception(data?['error'] ?? '获取统计失败');
      }
      return EnhancedStats.fromJson(data!);
    } on DioException catch (e) {
      AppLogger.log('EnhancedStats', 'Error: ${e.type} ${e.response?.statusCode}');
      throw Exception(e.response?.data?['error'] ?? '网络错误');
    } catch (e) {
      AppLogger.log('EnhancedStats', 'Error: $e');
      throw Exception(e.toString());
    }
  }
}

final enhancedStatsServiceProvider = Provider<EnhancedStatsService>((ref) {
  return EnhancedStatsService(baseUrl: apiBaseUrl);
});
