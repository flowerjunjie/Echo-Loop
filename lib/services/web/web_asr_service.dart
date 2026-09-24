/// Web平台ASR服务
///
/// 调用echo-transcribe后端API进行语音转录。
/// 接收Base64编码的音频数据，返回转录文本和句段。
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../app_logger.dart';
import '../../config/api_config.dart';

/// Web ASR结果（含句段信息）
class WebAsrResult {
  /// 完整转录文本
  final String text;

  /// 转录时长（毫秒）
  final int durationMs;

  /// 句段列表（仅Web版本返回）
  final List<Map<String, dynamic>> sentences;

  const WebAsrResult({
    required this.text,
    required this.durationMs,
    this.sentences = const [],
  });

  factory WebAsrResult.fromJson(Map<String, dynamic> json) {
    final sentencesJson = json['sentences'] as List<dynamic>? ?? [];
    final sentences = sentencesJson
        .map((s) => s as Map<String, dynamic>)
        .toList();
    return WebAsrResult(
      text: json['text'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? 0,
      sentences: sentences,
    );
  }
}

/// Web ASR异常
class WebAsrException implements Exception {
  final String message;
  const WebAsrException(this.message);

  @override
  String toString() => 'WebAsrException: $message';
}

/// Web平台ASR服务
///
/// 通过HTTP POST将Base64编码音频发送到echo-transcribe后端进行转录。
/// 支持webm/ogg格式音频（来自MediaRecorder）。
///
/// 支持认证：通过 [token] 参数传入用户登录后的 accessToken，
/// 会自动在请求头中添加 `Authorization: Bearer <token>`。
class WebAsrService {
  final Dio _dio;

  /// 创建 WebASR 服务实例
  ///
  /// [dio] 可选的 Dio 实例，用于测试注入
  /// [token] 可选的认证 token，已登录用户的 accessToken
  WebAsrService({Dio? dio, String? token})
      : _dio = (dio ??
            Dio(BaseOptions(
              baseUrl: apiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 120),
            )))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                // 注入认证 token（如果有的话）
                if (token != null && token.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
                return handler.next(options);
              },
            ),
          );

  /// 转录音频数据
  ///
  /// [audioBase64] Base64编码的音频数据（不含data URI前缀）
  /// [format] 音频格式（'webm'或'ogg'）
  /// [language] 语言代码（'en'或'zh'）
  ///
  /// 返回[WebAsrResult]，包含完整文本和句段信息。
  Future<WebAsrResult> transcribe({
    required String audioBase64,
    String format = 'webm',
    String language = 'en',
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('WebAsrService仅在Web平台可用');
    }

    try {
      AppLogger.log('WebASR', '开始转录，格式: $format, 语言: $language');

      // 发送Base64音频到echo-transcribe后端
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/transcribe',
        data: {
          'audio': 'data:audio/$format;base64,$audioBase64',
          'format': format,
          'language': language,
        },
        options: Options(
          contentType: 'application/json',
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.data == null) {
        throw const WebAsrException('转录失败：无返回数据');
      }

      final result = WebAsrResult.fromJson(response.data!);
      AppLogger.log('WebASR', '转录完成，文本长度: ${result.text.length}, 句段数: ${result.sentences.length}');

      return result;
    } on DioException catch (e) {
      AppLogger.log('WebASR', '转录失败: ${e.message}');
      throw WebAsrException('转录失败: ${e.response?.data?['error'] ?? e.message}');
    } catch (e) {
      AppLogger.log('WebASR', '转录异常: $e');
      throw WebAsrException('转录异常: $e');
    }
  }

  /// 检查ASR服务是否可用
  Future<bool> isAvailable() async {
    if (!kIsWeb) return false;
    try {
      final response = await _dio.get('/api/v1/invite/info');
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.log('WebASR', '健康检查失败: $e');
      return false;
    }
  }
}
