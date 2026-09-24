/// Web 平台数据服务
///
/// 通过 HTTP API 替代本地 Drift 数据库，为 Web 端提供集合、音频、收藏、
/// 学习进度的 CRUD 能力。
///
/// 设计约束：
/// - 所有方法都是 async，调用方需处理网络失败
/// - 错误统一封装为 WebDataException
/// - Token 从 sharedPreferences 读取（由调用方注入）
library;

import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import '../../models/collection.dart';
import '../../models/audio_item.dart';
import '../../services/app_logger.dart';


/// Web 数据服务异常
class WebDataServiceException implements Exception {
  final String message;
  final int? statusCode;
  const WebDataServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'WebDataServiceException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Web 平台数据服务
///
/// 封装与后端 [apiBaseUrl] 的所有通信，提供集合、音频、收藏、学习进度的 CRUD。
class WebDataService {
  final Dio _dio;

  WebDataService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// 设置认证 token
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 清除认证 token
  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  // ─── 合集 API ────────────────────────────────────────────────────

  /// 获取所有合集列表
  Future<List<Collection>> getCollections() async {
    try {
      final resp = await _dio.get('/api/v1/collections');
      if (resp.data['success'] != true) throw WebDataServiceException('获取合集列表失败');
      final list = resp.data['collections'] as List? ?? [];
      return list.map((e) => _collectionFromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 创建合集
  Future<Collection> createCollection({
    required String name,
    String source = 'local',
    String? remoteId,
    String? coverUrl,
    String? description,
  }) async {
    try {
      final resp = await _dio.post('/api/v1/collections', data: {
        'name': name,
        'source': source,
        'remoteId': remoteId,
        'coverUrl': coverUrl,
        'description': description,
      });
      if (resp.data['success'] != true) throw WebDataServiceException('创建合集失败');
      return _collectionFromJson(resp.data['collection'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 删除合集
  Future<void> deleteCollection(String collectionId) async {
    try {
      final resp = await _dio.delete('/api/v1/collections/$collectionId');
      if (resp.data['success'] != true) throw WebDataServiceException('删除合集失败');
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 获取合集中的音频列表
  Future<List<AudioItem>> getCollectionAudios(String collectionId) async {
    try {
      final resp = await _dio.get('/api/v1/collections/$collectionId/audios');
      if (resp.data['success'] != true) throw WebDataServiceException('获取音频列表失败');
      final list = resp.data['audios'] as List? ?? [];
      return list.map((e) => _audioItemFromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 添加音频到合集
  Future<void> addAudioToCollection(String collectionId, String audioId) async {
    try {
      final resp = await _dio.post('/api/v1/collections/$collectionId/audios', data: {'audioId': audioId});
      if (resp.data['success'] != true) throw WebDataServiceException('添加音频失败');
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 从合集移除音频
  Future<void> removeAudioFromCollection(String collectionId, String audioId) async {
    try {
      final resp = await _dio.delete('/api/v1/collections/$collectionId/audios/$audioId');
      if (resp.data['success'] != true) throw WebDataServiceException('移除音频失败');
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  // ─── 音频 API ────────────────────────────────────────────────────

  /// 获取所有音频列表
  Future<List<AudioItem>> getAudios() async {
    try {
      final resp = await _dio.get('/api/v1/audios');
      if (resp.data['success'] != true) throw WebDataServiceException('获取音频列表失败');
      final list = resp.data['audios'] as List? ?? [];
      return list.map((e) => _audioItemFromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      // 降级：使用演示模式（无需认证）
      try {
        final demoResp = await _dio.get('/api/v1/demo/audios');
        if (demoResp.data['success'] == true) {
          final list = demoResp.data['audios'] as List? ?? [];
          return list.map((e) => _audioItemFromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
    AppLogger.log('Cleanup', '$e');
  }
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 创建音频
  Future<AudioItem> createAudio({
    required String name,
    String? audioUrl,
    String? transcript,
    String transcriptSource = 'ai',
    String transcriptLanguage = 'en',
  }) async {
    try {
      final resp = await _dio.post('/api/v1/audios', data: {
        'name': name,
        'audioUrl': audioUrl,
        'transcript': transcript,
        'transcriptSource': transcriptSource,
        'transcriptLanguage': transcriptLanguage,
      });
      if (resp.data['success'] != true) throw WebDataServiceException('创建音频失败');
      return _audioItemFromJson(resp.data['audio'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 获取音频详情
  Future<AudioItem?> getAudio(String audioId) async {
    try {
      final resp = await _dio.get('/api/v1/audios/$audioId');
      if (resp.data['success'] != true) return null;
      return _audioItemFromJson(resp.data['audio'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 删除音频
  Future<void> deleteAudio(String audioId) async {
    try {
      final resp = await _dio.delete('/api/v1/audios/$audioId');
      if (resp.data['success'] != true) throw WebDataServiceException('删除音频失败');
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 保存字幕内容
  Future<void> saveTranscript(String audioId, {required String srt, List<Map<String, dynamic>>? sentences}) async {
    try {
      final resp = await _dio.post('/api/v1/audios/$audioId/transcript', data: {
        'srt': srt,
        'sentences': sentences,
      });
      if (resp.data['success'] != true) throw WebDataServiceException('保存字幕失败');
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  // ─── 收藏 API ────────────────────────────────────────────────────

  /// 获取收藏列表
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    try {
      final resp = await _dio.get('/api/v1/bookmarks');
      if (resp.data['success'] != true) throw WebDataServiceException('获取收藏列表失败');
      return (resp.data['bookmarks'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 创建收藏
  Future<Map<String, dynamic>> createBookmark({
    required String audioId,
    required int sentenceIndex,
    required String sentenceText,
    double? startTime,
    double? endTime,
  }) async {
    try {
      final resp = await _dio.post('/api/v1/bookmarks', data: {
        'audioId': audioId,
        'sentenceIndex': sentenceIndex,
        'sentenceText': sentenceText,
        'startTime': startTime,
        'endTime': endTime,
      });
      if (resp.data['success'] != true) throw WebDataServiceException('创建收藏失败');
      return resp.data['bookmark'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 删除收藏
  Future<void> deleteBookmark(String bookmarkId) async {
    try {
      final resp = await _dio.delete('/api/v1/bookmarks/$bookmarkId');
      if (resp.data['success'] != true) throw WebDataServiceException('删除收藏失败');
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  // ─── 学习进度 API ────────────────────────────────────────────────

  /// 获取学习进度
  Future<Map<String, dynamic>?> getProgress(String audioId) async {
    try {
      final resp = await _dio.get('/api/v1/progress/$audioId');
      if (resp.data['success'] != true) return null;
      return resp.data['progress'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  /// 保存学习进度
  Future<void> saveProgress({
    required String audioId,
    required String stage,
    String? subStage,
    String? completedAt,
    int? durationMs,
  }) async {
    try {
      final resp = await _dio.post('/api/v1/progress', data: {
        'audioId': audioId,
        'stage': stage,
        'subStage': subStage,
        'completedAt': completedAt ?? DateTime.now().toIso8601String(),
        'durationMs': durationMs,
      });
      if (resp.data['success'] != true) throw WebDataServiceException('保存进度失败');
    } on DioException catch (e) {
      throw WebDataServiceException('网络请求失败: ${e.message}', statusCode: e.response?.statusCode);
    }
  }

  // ─── 私有解析方法 ────────────────────────────────────────────────

  Collection _collectionFromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'] as String)
          : DateTime.now(),
      isPinned: json['isPinned'] as bool? ?? false,
      source: CollectionSource.fromString(json['source'] as String?),
      remoteId: json['remoteId'] as String?,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      deprecatedAt: json['deprecatedAt'] != null
          ? DateTime.parse(json['deprecatedAt'] as String)
          : null,
    );
  }

  AudioItem _audioItemFromJson(Map<String, dynamic> json) {
    return AudioItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      audioPath: json['audioUrl'] as String?, // Web 端用 audioUrl 代替 audioPath
      transcriptPath: null, // Web 端字幕存 JSON
      addedDate: json['addedDate'] != null
          ? DateTime.parse(json['addedDate'] as String)
          : DateTime.now(),
      totalDuration: (json['totalDuration'] as num?)?.toInt() ?? 0,
      sentenceCount: (json['sentenceCount'] as num?)?.toInt() ?? 0,
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      transcriptSource: json['transcriptSource'] == 'ai'
          ? TranscriptSource.ai
          : TranscriptSource.local,
      transcriptLanguage: json['transcriptLanguage'] as String?,
      remoteAudioId: null,
    );
  }
}
