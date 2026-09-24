/// Web 平台数据库 Provider 实现
///
/// 在 Web 平台使用 localStorage 实现数据持久化，替代 Drift DAO。
/// 所有接口与 [providers.dart] 中的真实 DAO 保持兼容，
/// 确保上游 Provider 无需任何修改即可正常工作。
///
/// **存储策略**：
/// - 所有数据以 JSON 数组形式存储在 window.localStorage
/// - key 格式：`el_web_{entity}_v1`
/// - 通过 StreamController 模拟 Drift 的 watch 流式行为
///
/// **条件导入使用方式**：
/// ```dart
/// import 'providers.dart' if (dart.library.html) 'providers_web.dart';
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../models/audio_item.dart' show AudioItem;
import '../models/collection.dart' show Collection;
import '../services/app_logger.dart';
import '../services/web_data/web_data_service.dart' show WebDataService;

// ── 内部存储键名常量 ───────────────────────────────────────────────────────

const String _kBookmark = 'el_web_bookmark_v1';
const String _kTag = 'el_web_tag_v1';
const String _kCollection = 'el_web_collection_v1';
const String _kCollectionAudio = 'el_web_collection_audio_v1';
const String _kSavedWord = 'el_web_saved_word_v1';
const String _kSavedSenseGroup = 'el_web_saved_sense_group_v1';
const String _kStageCompletion = 'el_web_stage_completion_v1';
const String _kDailyStudyRecord = 'el_web_daily_study_record_v1';
const String _kLearningProgress = 'el_web_learning_progress_v1';
const String _kPlaybackState = 'el_web_playback_state_v1';
const String _kAudioItem = 'el_web_audio_items_v1';
const String _kTranscriptPrefix = 'el_web_transcript_';

// ── 最小模型类（无需 drift 依赖）─────────────────────────────────────────────

/// Bookmark 最小模型
class Bookmark {
  final int id;
  final String audioItemId;
  final int sentenceIndex;
  final String sentenceText;
  final double startTime;
  final double endTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncStatus;
  const Bookmark({
    required this.id,
    required this.audioItemId,
    required this.sentenceIndex,
    required this.sentenceText,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as int,
        audioItemId: json['audioItemId'] as String,
        sentenceIndex: json['sentenceIndex'] as int,
        sentenceText: json['sentenceText'] as String,
        startTime: (json['startTime'] as num).toDouble(),
        endTime: (json['endTime'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] != null
            ? DateTime.parse(json['deletedAt'] as String)
            : null,
        syncStatus: json['syncStatus'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioItemId': audioItemId,
        'sentenceIndex': sentenceIndex,
        'sentenceText': sentenceText,
        'startTime': startTime,
        'endTime': endTime,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'syncStatus': syncStatus,
      };
}

/// Tag 最小模型
class Tag {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdDate;
  const Tag({required this.id, required this.name, required this.colorValue, required this.createdDate});

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['colorValue'] as int,
        createdDate: DateTime.parse(json['createdDate'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'createdDate': createdDate.toIso8601String(),
      };
}

/// StageCompletion 最小模型
class StageCompletion {
  final int id;
  final String audioItemId;
  final String stage;
  final String subStage;
  final DateTime completedAt;
  final int durationMs;
  const StageCompletion({
    required this.id,
    required this.audioItemId,
    required this.stage,
    required this.subStage,
    required this.completedAt,
    required this.durationMs,
  });

  factory StageCompletion.fromJson(Map<String, dynamic> json) => StageCompletion(
        id: json['id'] as int,
        audioItemId: json['audioItemId'] as String,
        stage: json['stage'] as String,
        subStage: json['subStage'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        durationMs: json['durationMs'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioItemId': audioItemId,
        'stage': stage,
        'subStage': subStage,
        'completedAt': completedAt.toIso8601String(),
        'durationMs': durationMs,
      };
}

/// BookmarkWithAudio 组合模型
class BookmarkWithAudio {
  final Bookmark bookmark;
  final String audioName;
  const BookmarkWithAudio({required this.bookmark, required this.audioName});
}

/// SavedWord 最小模型
class SavedWord {
  final int id;
  final String word;
  final String? audioItemId;
  final int? sentenceIndex;
  final String? sentenceText;
  final int? sentenceStartMs;
  final int? sentenceEndMs;
  final int practiceCount;
  final int totalStudyMs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const SavedWord({
    required this.id,
    required this.word,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.practiceCount = 0,
    this.totalStudyMs = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory SavedWord.fromJson(Map<String, dynamic> json) => SavedWord(
        id: json['id'] as int,
        word: json['word'] as String,
        audioItemId: json['audioItemId'] as String?,
        sentenceIndex: json['sentenceIndex'] as int?,
        sentenceText: json['sentenceText'] as String?,
        sentenceStartMs: json['sentenceStartMs'] as int?,
        sentenceEndMs: json['sentenceEndMs'] as int?,
        practiceCount: json['practiceCount'] as int? ?? 0,
        totalStudyMs: json['totalStudyMs'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'audioItemId': audioItemId,
        'sentenceIndex': sentenceIndex,
        'sentenceText': sentenceText,
        'sentenceStartMs': sentenceStartMs,
        'sentenceEndMs': sentenceEndMs,
        'practiceCount': practiceCount,
        'totalStudyMs': totalStudyMs,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };
}

/// SavedSenseGroup 最小模型
class SavedSenseGroup {
  final int id;
  final String phraseText;
  final String displayText;
  final String? audioItemId;
  final int? sentenceIndex;
  final String? sentenceText;
  final int? sentenceStartMs;
  final int? sentenceEndMs;
  final int? groupStartMs;
  final int? groupEndMs;
  final int practiceCount;
  final int totalStudyMs;
  final bool viewedBack;
  final DateTime? lastPracticedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const SavedSenseGroup({
    required this.id,
    required this.phraseText,
    required this.displayText,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.groupStartMs,
    this.groupEndMs,
    this.practiceCount = 0,
    this.totalStudyMs = 0,
    this.viewedBack = false,
    this.lastPracticedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory SavedSenseGroup.fromJson(Map<String, dynamic> json) => SavedSenseGroup(
        id: json['id'] as int,
        phraseText: json['phraseText'] as String,
        displayText: json['displayText'] as String,
        audioItemId: json['audioItemId'] as String?,
        sentenceIndex: json['sentenceIndex'] as int?,
        sentenceText: json['sentenceText'] as String?,
        sentenceStartMs: json['sentenceStartMs'] as int?,
        sentenceEndMs: json['sentenceEndMs'] as int?,
        groupStartMs: json['groupStartMs'] as int?,
        groupEndMs: json['groupEndMs'] as int?,
        practiceCount: json['practiceCount'] as int? ?? 0,
        totalStudyMs: json['totalStudyMs'] as int? ?? 0,
        viewedBack: json['viewedBack'] as bool? ?? false,
        lastPracticedAt: json['lastPracticedAt'] != null ? DateTime.parse(json['lastPracticedAt'] as String) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phraseText': phraseText,
        'displayText': displayText,
        'audioItemId': audioItemId,
        'sentenceIndex': sentenceIndex,
        'sentenceText': sentenceText,
        'sentenceStartMs': sentenceStartMs,
        'sentenceEndMs': sentenceEndMs,
        'groupStartMs': groupStartMs,
        'groupEndMs': groupEndMs,
        'practiceCount': practiceCount,
        'totalStudyMs': totalStudyMs,
        'viewedBack': viewedBack,
        'lastPracticedAt': lastPracticedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };
}

/// DailyStudyRecord 最小模型
class DailyStudyRecord {
  final int id;
  final DateTime date;
  final int studyTimeSeconds;
  final int inputWords;
  final int outputWords;
  final int inputTimeSeconds;
  final int outputTimeSeconds;
  const DailyStudyRecord({
    required this.id,
    required this.date,
    required this.studyTimeSeconds,
    required this.inputWords,
    required this.outputWords,
    required this.inputTimeSeconds,
    required this.outputTimeSeconds,
  });

  factory DailyStudyRecord.fromJson(Map<String, dynamic> json) => DailyStudyRecord(
        id: json['id'] as int,
        date: DateTime.parse(json['date'] as String),
        studyTimeSeconds: json['studyTimeSeconds'] as int,
        inputWords: json['inputWords'] as int,
        outputWords: json['outputWords'] as int,
        inputTimeSeconds: json['inputTimeSeconds'] as int,
        outputTimeSeconds: json['outputTimeSeconds'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'studyTimeSeconds': studyTimeSeconds,
        'inputWords': inputWords,
        'outputWords': outputWords,
        'inputTimeSeconds': inputTimeSeconds,
        'outputTimeSeconds': outputTimeSeconds,
      };
}

/// LearningProgressesData 最小模型
class LearningProgressesData {
  final String audioItemId;
  final String currentStage;
  final String currentSubStage;
  final int difficulty;
  final DateTime? firstLearnCompletedAt;
  final DateTime? lastStageCompletedAt;
  final DateTime? currentStageStartedAt;
  final int totalStudyDurationMs;
  final int blindListenPassCount;
  final int? intensiveListenSentenceIndex;
  final int? intensiveListenDifficultCount;
  final int? intensiveListenPassCount;
  final int? shadowingPassCount;
  final int? shadowingSentenceIndex;
  final int? difficultPracticeSentenceIndex;
  final int? retellSentenceIndex;
  final int? retellPassCount;
  final int? blindListenSentenceIndex;
  const LearningProgressesData({
    required this.audioItemId,
    this.currentStage = 'firstLearn',
    this.currentSubStage = 'blindListen',
    this.difficulty = 2,
    this.firstLearnCompletedAt,
    this.lastStageCompletedAt,
    this.currentStageStartedAt,
    this.totalStudyDurationMs = 0,
    this.blindListenPassCount = 0,
    this.intensiveListenSentenceIndex,
    this.intensiveListenDifficultCount,
    this.intensiveListenPassCount,
    this.shadowingPassCount,
    this.shadowingSentenceIndex,
    this.difficultPracticeSentenceIndex,
    this.retellSentenceIndex,
    this.retellPassCount,
    this.blindListenSentenceIndex,
  });

  factory LearningProgressesData.fromJson(Map<String, dynamic> json) => LearningProgressesData(
        audioItemId: json['audioItemId'] as String,
        currentStage: json['currentStage'] as String? ?? 'firstLearn',
        currentSubStage: json['currentSubStage'] as String? ?? 'blindListen',
        difficulty: json['difficulty'] as int? ?? 2,
        firstLearnCompletedAt: json['firstLearnCompletedAt'] != null ? DateTime.parse(json['firstLearnCompletedAt'] as String) : null,
        lastStageCompletedAt: json['lastStageCompletedAt'] != null ? DateTime.parse(json['lastStageCompletedAt'] as String) : null,
        currentStageStartedAt: json['currentStageStartedAt'] != null ? DateTime.parse(json['currentStageStartedAt'] as String) : null,
        totalStudyDurationMs: json['totalStudyDurationMs'] as int? ?? 0,
        blindListenPassCount: json['blindListenPassCount'] as int? ?? 0,
        intensiveListenSentenceIndex: json['intensiveListenSentenceIndex'] as int?,
        intensiveListenDifficultCount: json['intensiveListenDifficultCount'] as int?,
        intensiveListenPassCount: json['intensiveListenPassCount'] as int?,
        shadowingPassCount: json['shadowingPassCount'] as int?,
        shadowingSentenceIndex: json['shadowingSentenceIndex'] as int?,
        difficultPracticeSentenceIndex: json['difficultPracticeSentenceIndex'] as int?,
        retellSentenceIndex: json['retellSentenceIndex'] as int?,
        retellPassCount: json['retellPassCount'] as int?,
        blindListenSentenceIndex: json['blindListenSentenceIndex'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'audioItemId': audioItemId,
        'currentStage': currentStage,
        'currentSubStage': currentSubStage,
        'difficulty': difficulty,
        'firstLearnCompletedAt': firstLearnCompletedAt?.toIso8601String(),
        'lastStageCompletedAt': lastStageCompletedAt?.toIso8601String(),
        'currentStageStartedAt': currentStageStartedAt?.toIso8601String(),
        'totalStudyDurationMs': totalStudyDurationMs,
        'blindListenPassCount': blindListenPassCount,
        'intensiveListenSentenceIndex': intensiveListenSentenceIndex,
        'intensiveListenDifficultCount': intensiveListenDifficultCount,
        'intensiveListenPassCount': intensiveListenPassCount,
        'shadowingPassCount': shadowingPassCount,
        'shadowingSentenceIndex': shadowingSentenceIndex,
        'difficultPracticeSentenceIndex': difficultPracticeSentenceIndex,
        'retellSentenceIndex': retellSentenceIndex,
        'retellPassCount': retellPassCount,
        'blindListenSentenceIndex': blindListenSentenceIndex,
      };
}

// ── 通用 localStorage 工具函数 ───────────────────────────────────────────────

/// 从 localStorage 读取 JSON 数组
List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
  try {
    final raw = web.window.localStorage.getItem(key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    AppLogger.log('WebDB', '读取 $key 失败: $e');
    return [];
  }
}

/// 写入 JSON 数组到 localStorage
void _writeList<T>(String key, List<T> items, Map<String, dynamic> Function(T) toJson) {
  try {
    final encoded = jsonEncode(items.map(toJson).toList());
    web.window.localStorage.setItem(key, encoded);
    AppLogger.log('WebDB', '保存 $key (${encoded.length}B)');
  } catch (e) {
    AppLogger.log('WebDB', '保存 $key 失败: $e');
  }
}

// ── 带 Stream 通知的 DAO 基类 ─────────────────────────────────────────────────

/// 提供流式更新能力的 DAO 基类
/// PlaybackState 最小模型（Web 端无需 drift，本地持久化）
class PlaybackState {
  final String audioItemId;
  final int positionMs;
  final int playlistMode;
  final DateTime savedAt;
  const PlaybackState({
    required this.audioItemId,
    required this.positionMs,
    required this.playlistMode,
    required this.savedAt,
  });
  Map<String, dynamic> toJson() => {
        'audioItemId': audioItemId,
        'positionMs': positionMs,
        'playlistMode': playlistMode,
        'savedAt': savedAt.toIso8601String(),
      };
  factory PlaybackState.fromJson(Map<String, dynamic> m) => PlaybackState(
        audioItemId: m['audioItemId'] as String,
        positionMs: m['positionMs'] as int,
        playlistMode: m['playlistMode'] as int,
        savedAt: DateTime.parse(m['savedAt'] as String),
      );
}

class _WebDaoBase {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// 触发所有监听者重新订阅
  void _notify() {
    try {
      _controller.add(null);
    } catch (e) {
      // controller 已关闭时忽略
    }
  }

  Stream<void> get _onChange => _controller.stream;
}

// ── RecycleBinSortMode（供 BookmarkDaoWebImpl 使用）──────────────────────────

/// 回收站排序方式
enum RecycleBinSortMode { timeDesc, timeAsc, alphaAsc, alphaDesc }

// ── 最近完成记录 ─────────────────────────────────────────────────────────────

/// 最近完成记录（含音频 ID 和名称）
class RecentCompletion {
  final String audioId;
  final String audioName;
  final String stage;
  final String subStage;
  final DateTime completedAt;
  final int durationMs;
  const RecentCompletion({
    required this.audioId,
    required this.audioName,
    required this.stage,
    required this.subStage,
    required this.completedAt,
    required this.durationMs,
  });
}

// ── BookmarkDao Web 实现 ─────────────────────────────────────────────────────

/// Web 平台书签 DAO 实现
///
/// 使用 localStorage 持久化书签数据，支持流式监听。
/// audioName 暂时填充占位符（Web 端无 audio_items 表），
/// 实际 audioName 需由调用方通过 audioItemId 补充。
class BookmarkDaoWebImpl extends _WebDaoBase {
  BookmarkDaoWebImpl();

  List<Bookmark> _getData() => _readList(_kBookmark, Bookmark.fromJson);
  void _saveData(List<Bookmark> data) {
    _writeList(_kBookmark, data, (b) => b.toJson());
    _notify();
  }

  int _nextId(List<Bookmark> data) =>
      data.isEmpty ? 1 : data.map((b) => b.id).reduce((a, b) => a > b ? a : b) + 1;

  Future<List<Bookmark>> getByAudioId(String audioItemId) async {
    return _getData()
        .where((b) => b.audioItemId == audioItemId && b.deletedAt == null)
        .toList();
  }

  Stream<List<Bookmark>> watchByAudioId(String audioItemId) async* {
    yield await getByAudioId(audioItemId);
    await for (var _ in _onChange) {
      yield await getByAudioId(audioItemId);
    }
  }

  Future<void> addBookmark(dynamic entry) async {
    final audioItemId = entry.audioItemId.value;
    final sentenceIndex = entry.sentenceIndex.value;
    final sentenceText = entry.sentenceText.value ?? '';
    final startTime = entry.startTime.value ?? 0.0;
    final endTime = entry.endTime.value ?? 0.0;
    final now = DateTime.now();
    final data = _getData();
    final existIdx = data.indexWhere(
        (b) => b.audioItemId == audioItemId && b.sentenceIndex == sentenceIndex);
    if (existIdx >= 0) {
      final old = data[existIdx];
      data[existIdx] = Bookmark(
        id: old.id,
        audioItemId: audioItemId,
        sentenceIndex: sentenceIndex,
        sentenceText: sentenceText,
        startTime: startTime,
        endTime: endTime,
        createdAt: old.createdAt,
        updatedAt: now,
        deletedAt: null,
        syncStatus: 0,
      );
    } else {
      data.add(Bookmark(
        id: _nextId(data),
        audioItemId: audioItemId,
        sentenceIndex: sentenceIndex,
        sentenceText: sentenceText,
        startTime: startTime,
        endTime: endTime,
        createdAt: now,
        updatedAt: now,
        syncStatus: 0,
      ));
    }
    _saveData(data);
  }

  Future<void> batchInsert(dynamic entries) async {
    final list = entries as List;
    final data = _getData();
    for (final entry in list) {
      final audioItemId = entry.audioItemId.value;
      final sentenceIndex = entry.sentenceIndex.value;
      final sentenceText = entry.sentenceText.value ?? '';
      final startTime = entry.startTime.value ?? 0.0;
      final endTime = entry.endTime.value ?? 0.0;
      final now = DateTime.now();
      final existIdx = data.indexWhere(
          (b) => b.audioItemId == audioItemId && b.sentenceIndex == sentenceIndex);
      if (existIdx >= 0) {
        final old = data[existIdx];
        data[existIdx] = Bookmark(
          id: old.id, audioItemId: audioItemId, sentenceIndex: sentenceIndex,
          sentenceText: sentenceText, startTime: startTime, endTime: endTime,
          createdAt: old.createdAt, updatedAt: now, deletedAt: null, syncStatus: 0,
        );
      } else {
        data.add(Bookmark(
          id: _nextId(data), audioItemId: audioItemId, sentenceIndex: sentenceIndex,
          sentenceText: sentenceText, startTime: startTime, endTime: endTime,
          createdAt: now, updatedAt: now, syncStatus: 0,
        ));
      }
    }
    _saveData(data);
  }

  Future<void> removeBookmark(String audioItemId, int sentenceIndex) async {
    final data = _getData();
    final now = DateTime.now();
    for (int i = 0; i < data.length; i++) {
      final b = data[i];
      if (b.audioItemId == audioItemId && b.sentenceIndex == sentenceIndex) {
        data[i] = Bookmark(
          id: b.id, audioItemId: b.audioItemId, sentenceIndex: b.sentenceIndex,
          sentenceText: b.sentenceText, startTime: b.startTime, endTime: b.endTime,
          createdAt: b.createdAt, updatedAt: now, deletedAt: now, syncStatus: b.syncStatus,
        );
        break;
      }
    }
    _saveData(data);
  }

  Future<void> removeBookmarks(String audioItemId, Set<int> sentenceIndices) async {
    final data = _getData();
    final now = DateTime.now();
    for (int i = 0; i < data.length; i++) {
      final b = data[i];
      if (b.audioItemId == audioItemId &&
          sentenceIndices.contains(b.sentenceIndex) &&
          b.deletedAt == null) {
        data[i] = Bookmark(
          id: b.id, audioItemId: b.audioItemId, sentenceIndex: b.sentenceIndex,
          sentenceText: b.sentenceText, startTime: b.startTime, endTime: b.endTime,
          createdAt: b.createdAt, updatedAt: now, deletedAt: now, syncStatus: b.syncStatus,
        );
      }
    }
    _saveData(data);
  }

  Future<void> removeAllForAudio(String audioItemId) async {
    final data = _getData();
    final now = DateTime.now();
    for (int i = 0; i < data.length; i++) {
      final b = data[i];
      if (b.audioItemId == audioItemId && b.deletedAt == null) {
        data[i] = Bookmark(
          id: b.id, audioItemId: b.audioItemId, sentenceIndex: b.sentenceIndex,
          sentenceText: b.sentenceText, startTime: b.startTime, endTime: b.endTime,
          createdAt: b.createdAt, updatedAt: now, deletedAt: now, syncStatus: b.syncStatus,
        );
      }
    }
    _saveData(data);
  }

  Future<Set<int>> getBookmarkedIndices(String audioItemId) async {
    return Set.from(_getData()
        .where((b) => b.audioItemId == audioItemId && b.deletedAt == null)
        .map((b) => b.sentenceIndex));
  }

  Future<int> countAll() async => _getData().where((b) => b.deletedAt == null).length;

  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() async* {
    yield _buildAllWithAudioName();
    await for (var _ in _onChange) {
      yield _buildAllWithAudioName();
    }
  }

  List<BookmarkWithAudio> _buildAllWithAudioName() {
    return _getData()
        .where((b) => b.deletedAt == null)
        .map((b) => BookmarkWithAudio(bookmark: b, audioName: '(Web版)'))
        .toList();
  }

  Future<List<BookmarkWithAudio>> getDeletedBookmarks({
    required dynamic sortMode,
  }) async {
    return _getData()
        .where((b) => b.deletedAt != null)
        .map((b) => BookmarkWithAudio(bookmark: b, audioName: '(已删除)'))
        .toList();
  }

  Future<void> restoreBookmark(String audioItemId, int sentenceIndex) async {
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      final b = data[i];
      if (b.audioItemId == audioItemId &&
          b.sentenceIndex == sentenceIndex &&
          b.deletedAt != null) {
        data[i] = Bookmark(
          id: b.id, audioItemId: b.audioItemId, sentenceIndex: b.sentenceIndex,
          sentenceText: b.sentenceText, startTime: b.startTime, endTime: b.endTime,
          createdAt: b.createdAt, updatedAt: DateTime.now(), deletedAt: null,
          syncStatus: b.syncStatus,
        );
        break;
      }
    }
    _saveData(data);
  }

  Future<void> permanentlyDeleteBookmark(String audioItemId, int sentenceIndex) async {
    final data = _getData();
    data.removeWhere((b) =>
        b.audioItemId == audioItemId &&
        b.sentenceIndex == sentenceIndex &&
        b.deletedAt != null);
    _saveData(data);
  }

  Future<void> permanentlyDeleteAllDeleted() async {
    final data = _getData().where((b) => b.deletedAt == null).toList();
    _saveData(data);
  }
}

// ── TagDao Web 实现 ──────────────────────────────────────────────────────────

/// Web 平台标签 DAO 实现
class TagDaoWebImpl extends _WebDaoBase {
  TagDaoWebImpl();

  List<Tag> _getData() => _readList(_kTag, Tag.fromJson);
  void _saveData(List<Tag> data) {
    _writeList(_kTag, data, (t) => t.toJson());
    _notify();
  }

  Future<List<Tag>> getAllActive() async => _getData();

  Future<Tag?> getById(String id) async {
    try {
      return _getData().firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> upsert(dynamic entry) async {
    final id = entry.id.value;
    final name = entry.name.value;
    final color = entry.color.value ?? 0;
    final now = DateTime.now();
    final data = _getData();
    final idx = data.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      data[idx] = Tag(id: id, name: name, colorValue: color, createdDate: data[idx].createdDate);
    } else {
      data.add(Tag(id: id, name: name, colorValue: color, createdDate: now));
    }
    _saveData(data);
  }

  Future<void> softDelete(String id) async {
    final data = _getData().where((t) => t.id != id).toList();
    _saveData(data);
  }

  Future<void> hardDelete(String id) async => softDelete(id);

  Future<List<String>> getAudioIds(String _) async => const [];

  Future<void> addAudio(String _, String __) async {}

  Future<void> removeAudio(String _, String __) async {}

  Future<void> removeAudioFromAll(String _) async {}
}

// ── CollectionDao Web 实现 ───────────────────────────────────────────────────

/// Web 平台合集 DAO 实现
class CollectionDaoWebImpl extends _WebDaoBase {
  CollectionDaoWebImpl();

  List<Map<String, dynamic>> _getCollections() =>
      _readList(_kCollection, (m) => m);
  void _saveCollections(List<Map<String, dynamic>> data) {
    _writeList(_kCollection, data, (m) => m);
    _notify();
  }

  List<String> _getAudioIds(String collectionId) =>
      _readList(_kCollectionAudio, (m) => m)
          .where((m) => m['collectionId'] == collectionId)
          .map((m) => m['audioItemId'] as String)
          .toList();

  void _saveAudioIds(String collectionId, List<String> ids) {
    final all = _readList(_kCollectionAudio, (m) => m);
    all.removeWhere((m) => m['collectionId'] == collectionId);
    for (final audioId in ids) {
      all.add({'collectionId': collectionId, 'audioItemId': audioId});
    }
    _writeList(_kCollectionAudio, all, (m) => m);
    _notify();
  }

  Future<List<Collection>> getAllActive() async {
    return _getCollections()
        .where((m) => m['deletedAt'] == null)
        .map((m) => Collection(
              id: m['id'] as String,
              name: m['name'] as String,
              createdDate: DateTime.parse(m['createdDate'] as String),
              isPinned: m['isPinned'] as bool? ?? false,
            ))
        .toList();
  }

  Stream<List<Collection>> watchAllActive() async* {
    yield await getAllActive();
    await for (var _ in _onChange) {
      yield await getAllActive();
    }
  }

  Future<Collection?> getById(String id) async {
    try {
      final m = _getCollections().firstWhere((m) => m['id'] == id);
      if (m['deletedAt'] != null) return null;
      return Collection(
        id: m['id'] as String,
        name: m['name'] as String,
        createdDate: DateTime.parse(m['createdDate'] as String),
        isPinned: m['isPinned'] as bool? ?? false,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Collection?> getByRemoteId(String _) async => null;

  Future<void> upsert(dynamic entry) async {
    final id = entry.id.value;
    final name = entry.name.value;
    final createdDate = entry.createdDate.value;
    final isPinned = entry.isPinned.value ?? false;
    final now = DateTime.now();
    final data = _getCollections();
    final idx = data.indexWhere((m) => m['id'] == id);
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'createdDate': createdDate.toIso8601String(),
      'isPinned': isPinned,
      'deletedAt': null,
      'updatedAt': now.toIso8601String(),
    };
    if (idx >= 0) {
      data[idx] = map;
    } else {
      data.add(map);
    }
    _saveCollections(data);
  }

  Future<void> softDelete(String id) async {
    final data = _getCollections();
    for (int i = 0; i < data.length; i++) {
      if (data[i]['id'] == id) {
        data[i]['deletedAt'] = DateTime.now().toIso8601String();
        break;
      }
    }
    _saveCollections(data);
  }

  Future<void> hardDelete(String id) async {
    final data = _getCollections().where((m) => m['id'] != id).toList();
    _saveCollections(data);
    // 同时清理关联的 audioIds
    final all = _readList(_kCollectionAudio, (m) => m);
    _writeList(_kCollectionAudio,
        all.where((m) => m['collectionId'] != id).toList(), (m) => m);
  }

  Future<List<String>> getAudioIds(String collectionId) async {
    return _getAudioIds(collectionId);
  }

  Stream<List<String>> watchAudioIds(String collectionId) async* {
    yield await getAudioIds(collectionId);
    await for (var _ in _onChange) {
      yield await getAudioIds(collectionId);
    }
  }

  Future<int> getAudioCount(String collectionId) async => _getAudioIds(collectionId).length;

  Future<void> addAudio(String collectionId, String audioItemId) async {
    final ids = _getAudioIds(collectionId);
    if (!ids.contains(audioItemId)) {
      ids.add(audioItemId);
      _saveAudioIds(collectionId, ids);
    }
  }

  Future<void> addAudios(String collectionId, List<String> audioItemIds) async {
    if (audioItemIds.isEmpty) return;
    final ids = _getAudioIds(collectionId);
    for (final aid in audioItemIds) {
      if (!ids.contains(aid)) ids.add(aid);
    }
    _saveAudioIds(collectionId, ids);
  }

  Future<void> removeAudio(String collectionId, String audioItemId) async {
    final ids = _getAudioIds(collectionId);
    ids.remove(audioItemId);
    _saveAudioIds(collectionId, ids);
  }

  Future<void> removeAudioFromAll(String audioItemId) async {
    final all = _readList(_kCollectionAudio, (m) => m);
    _writeList(
        _kCollectionAudio,
        all.where((m) => (m['audioItemId'] as String) != audioItemId).toList(),
        (m) => m);
    _notify();
  }

  Future<void> batchInsertJunctions(dynamic entries) async {
    final list = entries as List;
    for (final entry in list) {
      final collectionId = (entry as dynamic).collectionId?.value ?? '';
      final audioItemId = (entry as dynamic).audioItemId?.value ?? '';
      if (collectionId.isNotEmpty && audioItemId.isNotEmpty) {
        await addAudio(collectionId, audioItemId);
      }
    }
  }
}

// ── PlaybackStateDao Web 实现 ────────────────────────────────────────────────

/// PlaybackState DAO Web 实现
class PlaybackStateDaoWebImpl extends _WebDaoBase {
  PlaybackStateDaoWebImpl();

  PlaybackState? _state;

  /// 从 localStorage 读取播放状态（启动时调用）
  void _loadFromStorage() {
    try {
      final raw = web.window.localStorage.getItem(_kPlaybackState);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        if (list.isNotEmpty) {
          final map = list.first as Map<String, dynamic>;
          _state = PlaybackState(
            audioItemId: map['audioItemId'] as String,
            positionMs: map['positionMs'] as int,
            playlistMode: map['playlistMode'] as int,
            savedAt: DateTime.parse(map['savedAt'] as String),
          );
          AppLogger.log('WebDB', '播放状态从 localStorage 加载: $_state');
        }
      }
    } catch (e) {
      AppLogger.log('WebDB', '加载播放状态失败: $e');
    }
  }

  /// 将播放状态写入 localStorage
  void _saveToStorage() {
    if (_state == null) return;
    try {
      final encoded = jsonEncode([_state!.toJson()]);
      web.window.localStorage.setItem(_kPlaybackState, encoded);
      AppLogger.log('WebDB', '保存播放状态到 localStorage');
    } catch (e) {
      AppLogger.log('WebDB', '保存播放状态失败: $e');
    }
  }

  Future<PlaybackState?> getByAudioId(String audioItemId) async {
    _loadFromStorage();
    return _state?.audioItemId == audioItemId ? _state : null;
  }

  Future<void> saveState(dynamic entry) async {
    _state = PlaybackState(
      audioItemId: entry.audioItemId.value,
      positionMs: entry.positionMs.value,
      playlistMode: entry.playlistMode.value ?? 0,
      savedAt: entry.savedAt.value ?? DateTime.now(),
    );
    _saveToStorage();
    _notify();
  }

  Future<void> clearState(String audioItemId) async {
    if (_state?.audioItemId == audioItemId) {
      _state = null;
      web.window.localStorage.removeItem(_kPlaybackState);
    }
    _notify();
  }
}

// ── LearningProgressDao Web 实现 ─────────────────────────────────────────────

/// LearningProgress DAO Web 实现
class LearningProgressDaoWebImpl extends _WebDaoBase {
  LearningProgressDaoWebImpl();

  Map<String, LearningProgressesData> _cache = {};

  /// 从 localStorage 读取学习进度（启动时调用）
  void _loadFromStorage() {
    if (_cache.isNotEmpty) return;
    try {
      final raw = web.window.localStorage.getItem(_kLearningProgress);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final data = LearningProgressesData.fromJson(map);
          _cache[data.audioItemId] = data;
        }
        AppLogger.log('WebDB', '学习进度从 localStorage 加载: ${_cache.length} 条');
      }
    } catch (e) {
      AppLogger.log('WebDB', '加载学习进度失败: $e');
    }
  }

  /// 将学习进度写入 localStorage
  void _saveToStorage() {
    try {
      final list = _cache.values.toList();
      final encoded = jsonEncode(list.map((d) => d.toJson()).toList());
      web.window.localStorage.setItem(_kLearningProgress, encoded);
      AppLogger.log('WebDB', '保存学习进度到 localStorage');
    } catch (e) {
      AppLogger.log('WebDB', '保存学习进度失败: $e');
    }
  }

  Future<LearningProgressesData?> getByAudioId(String audioItemId) async {
    _loadFromStorage();
    return _cache[audioItemId];
  }

  Future<List<LearningProgressesData>> getAll() async {
    _loadFromStorage();
    return _cache.values.toList();
  }

  Future<void> upsert(dynamic entry) async {
    final audioItemId = entry.audioItemId.value;
    _cache[audioItemId] = LearningProgressesData(
      audioItemId: audioItemId,
      currentStage: entry.currentStage.value ?? 'firstLearn',
      currentSubStage: entry.currentSubStage.value ?? 'blindListen',
      difficulty: entry.difficulty.value ?? 2,
      firstLearnCompletedAt: entry.firstLearnCompletedAt.value,
      lastStageCompletedAt: entry.lastStageCompletedAt.value,
      currentStageStartedAt: entry.currentStageStartedAt.value,
      totalStudyDurationMs: entry.totalStudyDurationMs.value ?? 0,
      blindListenPassCount: entry.blindListenPassCount.value ?? 0,
    );
    _saveToStorage();
    _notify();
  }

  Future<void> deleteByAudioId(String audioItemId) async {
    _cache.remove(audioItemId);
    _saveToStorage();
    _notify();
  }

  Future<int> setPaused(String audioItemId, bool paused) async {
    _loadFromStorage();
    if (_cache.containsKey(audioItemId)) {
      _saveToStorage();
      _notify();
      return 1;
    }
    return 0;
  }
}

// ── StageCompletionDao Web 实现 ──────────────────────────────────────────────

/// StageCompletion DAO Web 实现
class StageCompletionDaoWebImpl extends _WebDaoBase {
  StageCompletionDaoWebImpl();

  List<StageCompletion> _getData() =>
      _readList(_kStageCompletion, StageCompletion.fromJson);
  void _saveData(List<StageCompletion> data) {
    _writeList(_kStageCompletion, data, (s) => s.toJson());
    _notify();
  }

  int _nextId(List<StageCompletion> data) =>
      data.isEmpty ? 1 : data.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> insertRecord(dynamic entry) async {
    // entry 是 StageCompletionsCompanion
    final audioItemId = entry.audioItemId.value;
    final stage = entry.stage.value;
    final subStage = entry.subStage.value;
    final completedAt = entry.completedAt.value;
    final durationMs = entry.durationMs.value ?? 0;
    final data = _getData();
    data.add(StageCompletion(
      id: _nextId(data),
      audioItemId: audioItemId,
      stage: stage,
      subStage: subStage,
      completedAt: completedAt,
      durationMs: durationMs,
    ));
    _saveData(data);
  }

  Future<List<StageCompletion>> getByAudioId(String audioItemId) async {
    return _getData().where((s) => s.audioItemId == audioItemId).toList();
  }

  Future<List<RecentCompletion>> getRecentCompletions(DateTime since) async {
    return _getData()
        .where((s) => s.completedAt.isAfter(since))
        .map((s) => RecentCompletion(
              audioId: s.audioItemId,
              audioName: '(Web版)',
              stage: s.stage,
              subStage: s.subStage,
              completedAt: s.completedAt,
              durationMs: s.durationMs,
            ))
        .toList();
  }

  Future<void> deleteByAudioId(String audioItemId) async {
    final data = _getData().where((s) => s.audioItemId != audioItemId).toList();
    _saveData(data);
  }

  Future<Map<String, Set<String>>> getCompletionKeysByAudio() async {
    final result = <String, Set<String>>{};
    for (final s in _getData()) {
      result.putIfAbsent(s.audioItemId, () => <String>{}).add('${s.stage}:${s.subStage}');
    }
    return result;
  }

  Future<Map<String, DateTime>> getStageCompletedAtByAudioId(String audioItemId) async {
    final result = <String, DateTime>{};
    for (final s in _getData().where((x) => x.audioItemId == audioItemId)) {
      result[s.stage] = s.completedAt;
    }
    return result;
  }

  Stream<Map<String, DateTime>> watchStageCompletedAtByAudioId(String audioItemId) async* {
    yield await getStageCompletedAtByAudioId(audioItemId);
    await for (var _ in _onChange) {
      yield await getStageCompletedAtByAudioId(audioItemId);
    }
  }

  Future<int> countCompletedSince(DateTime since) async {
    return _getData().where((s) => s.completedAt.isAfter(since)).length;
  }
}

// ── SavedWordDao Web 实现 ─────────────────────────────────────────────────────

/// SavedWord DAO Web 实现
class SavedWordDaoWebImpl extends _WebDaoBase {
  SavedWordDaoWebImpl();

  List<SavedWord> _getData() => _readList(_kSavedWord, SavedWord.fromJson);
  void _saveData(List<SavedWord> data) {
    _writeList(_kSavedWord, data, (w) => w.toJson());
    _notify();
  }

  int _nextId(List<SavedWord> data) =>
      data.isEmpty ? 1 : data.map((w) => w.id).reduce((a, b) => a > b ? a : b) + 1;

  Stream<List<SavedWord>> watchAll() async* {
    yield await getAll();
    await for (var _ in _onChange) {
      yield await getAll();
    }
  }

  Future<List<SavedWord>> getAll() async {
    return _getData().where((w) => w.deletedAt == null).toList();
  }

  Future<List<SavedWord>> getByAudioId(String audioItemId) async {
    return _getData()
        .where((w) => w.audioItemId == audioItemId && w.deletedAt == null)
        .toList();
  }

  Future<void> saveWord({
    required String word,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) async {
    final data = _getData();
    final now = DateTime.now();
    final idx = data.indexWhere((w) => w.word == word);
    if (idx >= 0) {
      final old = data[idx];
      data[idx] = SavedWord(
        id: old.id, word: word,
        audioItemId: audioItemId ?? old.audioItemId,
        sentenceIndex: sentenceIndex ?? old.sentenceIndex,
        sentenceText: sentenceText ?? old.sentenceText,
        sentenceStartMs: sentenceStartMs ?? old.sentenceStartMs,
        sentenceEndMs: sentenceEndMs ?? old.sentenceEndMs,
        practiceCount: old.practiceCount,
        totalStudyMs: old.totalStudyMs,
        createdAt: old.createdAt,
        updatedAt: now,
        deletedAt: null,
      );
    } else {
      data.add(SavedWord(
        id: _nextId(data), word: word,
        audioItemId: audioItemId, sentenceIndex: sentenceIndex,
        sentenceText: sentenceText, sentenceStartMs: sentenceStartMs,
        sentenceEndMs: sentenceEndMs,
        createdAt: now, updatedAt: now,
      ));
    }
    _saveData(data);
  }

  Future<void> removeWord(String word) async {
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (data[i].word == word) {
        final now = DateTime.now();
        data[i] = SavedWord(
          id: data[i].id, word: data[i].word,
          audioItemId: data[i].audioItemId, sentenceIndex: data[i].sentenceIndex,
          sentenceText: data[i].sentenceText, sentenceStartMs: data[i].sentenceStartMs,
          sentenceEndMs: data[i].sentenceEndMs, practiceCount: data[i].practiceCount,
          totalStudyMs: data[i].totalStudyMs, createdAt: data[i].createdAt,
          updatedAt: now, deletedAt: now,
        );
        break;
      }
    }
    _saveData(data);
  }

  Future<bool> isWordSaved(String word) async {
    return _getData().any((w) => w.word == word && w.deletedAt == null);
  }

  Future<void> clearContextForAudio(String audioItemId) async {
    return clearContextForAudios({audioItemId});
  }

  Future<void> clearContextForAudios(Set<String> audioItemIds) async {
    if (audioItemIds.isEmpty) return;
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (audioItemIds.contains(data[i].audioItemId)) {
        data[i] = SavedWord(
          id: data[i].id, word: data[i].word,
          audioItemId: null, sentenceIndex: null, sentenceText: null,
          sentenceStartMs: data[i].sentenceStartMs, sentenceEndMs: data[i].sentenceEndMs,
          practiceCount: data[i].practiceCount, totalStudyMs: data[i].totalStudyMs,
          createdAt: data[i].createdAt, updatedAt: DateTime.now(), deletedAt: data[i].deletedAt,
        );
      }
    }
    _saveData(data);
  }

  Future<void> updatePracticeStats({required String word, required int studyMs}) async {
    final clampedMs = studyMs.clamp(0, 60000);
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (data[i].word == word && data[i].deletedAt == null) {
        data[i] = SavedWord(
          id: data[i].id, word: data[i].word,
          audioItemId: data[i].audioItemId, sentenceIndex: data[i].sentenceIndex,
          sentenceText: data[i].sentenceText, sentenceStartMs: data[i].sentenceStartMs,
          sentenceEndMs: data[i].sentenceEndMs,
          practiceCount: data[i].practiceCount + 1,
          totalStudyMs: data[i].totalStudyMs + clampedMs,
          createdAt: data[i].createdAt, updatedAt: DateTime.now(), deletedAt: null,
        );
        break;
      }
    }
    _saveData(data);
  }

  Stream<List<SavedWord>> watchAllSorted({required dynamic timeOrder}) async* {
    yield await getAll();
    await for (var _ in _onChange) {
      yield await getAll();
    }
  }

  Stream<Set<String>> watchSavedWordTexts() async* {
    yield Set.from(_getData().where((w) => w.deletedAt == null).map((w) => w.word));
    await for (var _ in _onChange) {
      yield Set.from(_getData().where((w) => w.deletedAt == null).map((w) => w.word));
    }
  }

  Stream<bool> watchIsWordSaved(String word) async* {
    yield await isWordSaved(word);
    await for (var _ in _onChange) {
      yield await isWordSaved(word);
    }
  }

  Future<List<SavedWord>> getDeletedWords({required dynamic sortMode}) async {
    return _getData().where((w) => w.deletedAt != null).toList();
  }

  Future<void> restoreWord(String word) async {
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (data[i].word == word && data[i].deletedAt != null) {
        data[i] = SavedWord(
          id: data[i].id, word: data[i].word,
          audioItemId: data[i].audioItemId, sentenceIndex: data[i].sentenceIndex,
          sentenceText: data[i].sentenceText, sentenceStartMs: data[i].sentenceStartMs,
          sentenceEndMs: data[i].sentenceEndMs, practiceCount: data[i].practiceCount,
          totalStudyMs: data[i].totalStudyMs, createdAt: data[i].createdAt,
          updatedAt: DateTime.now(), deletedAt: null,
        );
        break;
      }
    }
    _saveData(data);
  }

  Future<void> permanentlyDeleteWord(String word) async {
    final data = _getData()
        .where((w) => !(w.word == word && w.deletedAt != null))
        .toList();
    _saveData(data);
  }

  Future<void> permanentlyDeleteAllDeleted() async {
    final data = _getData().where((w) => w.deletedAt == null).toList();
    _saveData(data);
  }
}

// ── SavedSenseGroupDao Web 实现 ───────────────────────────────────────────────

/// SavedSenseGroup DAO Web 实现
class SavedSenseGroupDaoWebImpl extends _WebDaoBase {
  SavedSenseGroupDaoWebImpl();

  List<SavedSenseGroup> _getData() =>
      _readList(_kSavedSenseGroup, SavedSenseGroup.fromJson);
  void _saveData(List<SavedSenseGroup> data) {
    _writeList(_kSavedSenseGroup, data, (s) => s.toJson());
    _notify();
  }

  int _nextId(List<SavedSenseGroup> data) =>
      data.isEmpty ? 1 : data.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;

  Stream<List<SavedSenseGroup>> watchAll() async* {
    yield await _getAll();
    await for (var _ in _onChange) {
      yield await _getAll();
    }
  }

  Future<List<SavedSenseGroup>> _getAll() async {
    return _getData().where((s) => s.deletedAt == null).toList();
  }

  Future<List<SavedSenseGroup>> getByAudioId(String audioItemId) async {
    return _getData()
        .where((s) => s.audioItemId == audioItemId && s.deletedAt == null)
        .toList();
  }

  Future<void> saveSenseGroup({
    required String phraseText,
    required String displayText,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
    int? groupStartMs,
    int? groupEndMs,
  }) async {
    final data = _getData();
    final now = DateTime.now();
    final idx = data.indexWhere((s) => s.phraseText == phraseText);
    if (idx >= 0) {
      final old = data[idx];
      data[idx] = SavedSenseGroup(
        id: old.id, phraseText: phraseText, displayText: displayText,
        audioItemId: old.audioItemId ?? audioItemId,
        sentenceIndex: old.sentenceIndex ?? sentenceIndex,
        sentenceText: old.sentenceText ?? sentenceText,
        sentenceStartMs: old.sentenceStartMs ?? sentenceStartMs,
        sentenceEndMs: old.sentenceEndMs ?? sentenceEndMs,
        groupStartMs: old.groupStartMs ?? groupStartMs,
        groupEndMs: old.groupEndMs ?? groupEndMs,
        practiceCount: old.practiceCount, totalStudyMs: old.totalStudyMs,
        viewedBack: old.viewedBack, lastPracticedAt: old.lastPracticedAt,
        createdAt: old.createdAt, updatedAt: now, deletedAt: null,
      );
    } else {
      data.add(SavedSenseGroup(
        id: _nextId(data), phraseText: phraseText, displayText: displayText,
        audioItemId: audioItemId, sentenceIndex: sentenceIndex,
        sentenceText: sentenceText, sentenceStartMs: sentenceStartMs,
        sentenceEndMs: sentenceEndMs, groupStartMs: groupStartMs,
        groupEndMs: groupEndMs,
        createdAt: now, updatedAt: now,
      ));
    }
    _saveData(data);
  }

  Future<void> removeSenseGroup(String phraseText) async {
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (data[i].phraseText == phraseText) {
        final now = DateTime.now();
        data[i] = SavedSenseGroup(
          id: data[i].id, phraseText: data[i].phraseText,
          displayText: data[i].displayText, audioItemId: data[i].audioItemId,
          sentenceIndex: data[i].sentenceIndex, sentenceText: data[i].sentenceText,
          sentenceStartMs: data[i].sentenceStartMs, sentenceEndMs: data[i].sentenceEndMs,
          groupStartMs: data[i].groupStartMs, groupEndMs: data[i].groupEndMs,
          practiceCount: data[i].practiceCount, totalStudyMs: data[i].totalStudyMs,
          viewedBack: data[i].viewedBack, lastPracticedAt: data[i].lastPracticedAt,
          createdAt: data[i].createdAt, updatedAt: now, deletedAt: now,
        );
        break;
      }
    }
    _saveData(data);
  }

  Future<bool> isSenseGroupSaved(String phraseText) async {
    return _getData().any((s) => s.phraseText == phraseText && s.deletedAt == null);
  }

  Stream<bool> watchIsSenseGroupSaved(String phraseText) async* {
    yield await isSenseGroupSaved(phraseText);
    await for (var _ in _onChange) {
      yield await isSenseGroupSaved(phraseText);
    }
  }

  Stream<Set<String>> watchSavedPhraseTexts() async* {
    yield Set.from(_getData().where((s) => s.deletedAt == null).map((s) => s.phraseText));
    await for (var _ in _onChange) {
      yield Set.from(_getData().where((s) => s.deletedAt == null).map((s) => s.phraseText));
    }
  }

  Future<void> updatePracticeStats({required String phraseText, required int studyMs}) async {
    final clampedMs = studyMs.clamp(0, 60000);
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (data[i].phraseText == phraseText && data[i].deletedAt == null) {
        data[i] = SavedSenseGroup(
          id: data[i].id, phraseText: data[i].phraseText,
          displayText: data[i].displayText, audioItemId: data[i].audioItemId,
          sentenceIndex: data[i].sentenceIndex, sentenceText: data[i].sentenceText,
          sentenceStartMs: data[i].sentenceStartMs, sentenceEndMs: data[i].sentenceEndMs,
          groupStartMs: data[i].groupStartMs, groupEndMs: data[i].groupEndMs,
          practiceCount: data[i].practiceCount + 1,
          totalStudyMs: data[i].totalStudyMs + clampedMs,
          viewedBack: true, lastPracticedAt: DateTime.now(),
          createdAt: data[i].createdAt, updatedAt: DateTime.now(), deletedAt: null,
        );
        break;
      }
    }
    _saveData(data);
  }

  Future<void> clearContextForAudio(String audioItemId) async =>
      clearContextForAudios({audioItemId});

  Future<void> clearContextForAudios(Set<String> audioItemIds) async {
    if (audioItemIds.isEmpty) return;
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (audioItemIds.contains(data[i].audioItemId)) {
        data[i] = SavedSenseGroup(
          id: data[i].id, phraseText: data[i].phraseText,
          displayText: data[i].displayText, audioItemId: null,
          sentenceIndex: null, sentenceText: null,
          sentenceStartMs: null, sentenceEndMs: null, groupStartMs: null,
          groupEndMs: null,
          practiceCount: data[i].practiceCount, totalStudyMs: data[i].totalStudyMs,
          viewedBack: data[i].viewedBack, lastPracticedAt: data[i].lastPracticedAt,
          createdAt: data[i].createdAt, updatedAt: DateTime.now(),
          deletedAt: data[i].deletedAt,
        );
      }
    }
    _saveData(data);
  }

  Future<List<SavedSenseGroup>> getDeletedSenseGroups({required dynamic sortMode}) async {
    return _getData().where((s) => s.deletedAt != null).toList();
  }

  Future<void> restoreSenseGroup(String phraseText) async {
    final data = _getData();
    for (int i = 0; i < data.length; i++) {
      if (data[i].phraseText == phraseText && data[i].deletedAt != null) {
        final now = DateTime.now();
        data[i] = SavedSenseGroup(
          id: data[i].id, phraseText: data[i].phraseText,
          displayText: data[i].displayText, audioItemId: data[i].audioItemId,
          sentenceIndex: data[i].sentenceIndex, sentenceText: data[i].sentenceText,
          sentenceStartMs: data[i].sentenceStartMs, sentenceEndMs: data[i].sentenceEndMs,
          groupStartMs: data[i].groupStartMs, groupEndMs: data[i].groupEndMs,
          practiceCount: data[i].practiceCount, totalStudyMs: data[i].totalStudyMs,
          viewedBack: data[i].viewedBack, lastPracticedAt: data[i].lastPracticedAt,
          createdAt: data[i].createdAt, updatedAt: now, deletedAt: null,
        );
        break;
      }
    }
    _saveData(data);
  }

  Future<void> permanentlyDeleteSenseGroup(String phraseText) async {
    final data = _getData()
        .where((s) => !(s.phraseText == phraseText && s.deletedAt != null))
        .toList();
    _saveData(data);
  }

  Future<void> permanentlyDeleteAllDeleted() async {
    final data = _getData().where((s) => s.deletedAt == null).toList();
    _saveData(data);
  }
}

// ── DailyStudyRecordDao Web 实现 ──────────────────────────────────────────────

/// DailyStudyRecord DAO Web 实现
class DailyStudyRecordDaoWebImpl extends _WebDaoBase {
  DailyStudyRecordDaoWebImpl();

  List<DailyStudyRecord> _getData() =>
      _readList(_kDailyStudyRecord, DailyStudyRecord.fromJson);
  void _saveData(List<DailyStudyRecord> data) {
    _writeList(_kDailyStudyRecord, data, (r) => r.toJson());
    _notify();
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> upsertAdd(DateTime date,
      {int studyTime = 0,
      int inputWords = 0,
      int outputWords = 0,
      int inputTime = 0,
      int outputTime = 0}) async {
    final dateOnly = _dateOnly(date);
    final data = _getData();
    final idx = data.indexWhere((r) => _dateOnly(r.date) == dateOnly);
    if (idx >= 0) {
      final r = data[idx];
      data[idx] = DailyStudyRecord(
        id: r.id, date: r.date,
        studyTimeSeconds: r.studyTimeSeconds + studyTime,
        inputWords: r.inputWords + inputWords,
        outputWords: r.outputWords + outputWords,
        inputTimeSeconds: r.inputTimeSeconds + inputTime,
        outputTimeSeconds: r.outputTimeSeconds + outputTime,
      );
    } else {
      data.add(DailyStudyRecord(
        id: data.isEmpty ? 1 : data.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1,
        date: dateOnly,
        studyTimeSeconds: studyTime,
        inputWords: inputWords,
        outputWords: outputWords,
        inputTimeSeconds: inputTime,
        outputTimeSeconds: outputTime,
      ));
    }
    _saveData(data);
  }

  Future<DailyStudyRecord?> getByDate(DateTime date) async {
    final dateOnly = _dateOnly(date);
    try {
      return _getData().firstWhere((r) => _dateOnly(r.date) == dateOnly);
    } catch (e) {
      return null;
    }
  }

  Future<List<DailyStudyRecord>> getBetween(DateTime start, DateTime end) async {
    final startOnly = _dateOnly(start);
    final endOnly = _dateOnly(end);
    return _getData()
        .where((r) {
          final d = _dateOnly(r.date);
          return !d.isBefore(startOnly) && !d.isAfter(endOnly);
        })
        .toList();
  }

  Future<int> getStreak({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final todayRecord = await getByDate(today);
    int streak = 0;
    if (todayRecord != null && todayRecord.studyTimeSeconds > 0) streak = 1;
    for (int i = 1; i <= 365; i++) {
      final record = await getByDate(today.subtract(Duration(days: i)));
      if (record == null || record.studyTimeSeconds <= 0) break;
      streak++;
    }
    return streak;
  }
}

// ── AudioItemDao Web 实现 ────────────────────────────────────────────────────

/// AudioItemDao Web 实现 — 基于 localStorage + 后端 API 的完整数据层
///
/// 存储策略：
/// - 所有本地数据（名称、时长、字幕、学习进度等）存储在 localStorage（key: `_kAudioItem`）
/// - 远端创建/删除等操作通过 [WebDataService] 同步到服务器
/// - 启动时先从服务器拉取最新数据，再合并本地缓存
///
/// 与真实 [AudioItemDao] 接口签名保持一致，供 [audioItemDaoProvider] 注入。
class AudioItemDaoWebImpl extends _WebDaoBase {
  AudioItemDaoWebImpl({this.webDataService});
  final WebDataService? webDataService;

  // ── localStorage 存取 ──────────────────────────────────────────────────

  /// 从 localStorage 读取所有音频条目
  List<AudioItem> _getAllItems() =>
      _readList(_kAudioItem, AudioItem.fromJson);

  /// 将所有音频条目写入 localStorage 并触发流通知
  void _saveAllItems(List<AudioItem> items) {
    _writeList(_kAudioItem, items, (item) => item.toJson());
    _notify();
  }

  /// 查找指定 ID 的条目，未找到返回 null
  AudioItem? _findById(String id) {
    try {
      return _getAllItems().firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── DAO 接口实现 ─────────────────────────────────────────────────────

  Future<List<AudioItem>> getAllActive() async {
    // 尝试从 WebDataService 获取服务器最新数据
    try {
      final apiItems = await webDataService?.getAudios() ?? const [];
      if (apiItems.isNotEmpty) {
        // 合并：保留本地缓存中不在服务器的条目（防止误删）
        final localItems = _getAllItems();
        final merged = <AudioItem>[];
        final seenIds = <String>{};
        // 先加入服务器存在的条目
        for (final item in apiItems) {
          if (item.id.isNotEmpty && !seenIds.contains(item.id)) {
            merged.add(item);
            seenIds.add(item.id);
          }
        }
        // 再加入本地有但服务器没有的条目（如已删除但未同步）
        for (final item in localItems) {
          if (!seenIds.contains(item.id)) {
            merged.add(item);
          }
        }
        AppLogger.log('WebDB', 'AudioItem getAllActive: api=${apiItems.length}, local=${localItems.length}, merged=${merged.length}');
        return merged;
      }
    } catch (e) {
      AppLogger.log('WebDB', 'getAudios API 失败，回退到本地缓存: $e');
    }
    // 回退：返回本地缓存
    return _getAllItems();
  }

  Stream<List<AudioItem>> watchAllActive() async* {
    yield await getAllActive();
    await for (var _ in _onChange) {
      yield await getAllActive();
    }
  }

  Future<AudioItem?> getById(String id) async {
    final item = _findById(id);
    if (item != null) return item;
    // 本地没有，尝试从 API 获取
    try {
      return await webDataService?.getAudio(id);
    } catch (e) {
      AppLogger.log('WebDB', 'getById API 失败: $e');
      return null;
    }
  }

  Future<AudioItem?> getByRemoteAudioId(String remoteAudioId) async {
    // 本地缓存按 id 索引，remoteAudioId 暂不支持
    return null;
  }

  /// 批量写入（upsert），将 AudioItem 列表合并到 localStorage
  ///
  /// Web 端不接受 Drift Companion 类型，直接接收 [AudioItem] 列表。
  Future<void> batchInsert(dynamic entries) async {
    List<AudioItem> items;
    if (entries is List<AudioItem>) {
      items = entries;
    } else if (entries is AudioItem) {
      items = [entries];
    } else {
      // 兼容 Drift Companion 类型（来自上层 provider 调用）
      AppLogger.log('WebDB', 'batchInsert 收到非 AudioItem 类型，忽略');
      return;
    }
    final existing = _getAllItems();
    final updated = <AudioItem>[];
    final newIds = <String>{...items.map((i) => i.id)};
    for (final item in existing) {
      if (newIds.contains(item.id)) {
        // 被新条目覆盖
        final idx = items.indexWhere((i) => i.id == item.id);
        if (idx != -1) {
          updated.add(items[idx]);
        }
      } else {
        updated.add(item);
      }
    }
    // 追加全新的条目
    for (final item in items) {
      if (!newIds.contains(item.id) || _findById(item.id) == null) {
        updated.add(item);
      }
    }
    _saveAllItems(updated);
  }

  Future<void> upsert(dynamic entry) async {
    if (entry is AudioItem) {
      await batchInsert([entry]);
    } else {
      // 兼容 Drift Companion 类型
      AppLogger.log('WebDB', 'upsert 收到非 AudioItem 类型，忽略');
    }
  }

  Future<void> hardDeleteMany(Set<String> ids) async {
    if (ids.isEmpty) return;
    final existing = _getAllItems();
    final filtered = existing.where((item) => !ids.contains(item.id)).toList();
    _saveAllItems(filtered);
    // 同步删除服务器数据（best-effort）
    for (final id in ids) {
      try {
        await webDataService?.deleteAudio(id);
      } catch (e) {
        AppLogger.log('WebDB', 'hardDeleteMany 同步删除失败 id=$id: $e');
      }
    }
  }

  Future<void> softDelete(String id) async {
    // Web 端无软删除概念，直接硬删除
    await hardDelete(id);
  }

  Future<void> hardDelete(String id) async {
    await hardDeleteMany({id});
  }

  /// 构建词级时间戳的 localStorage key
  static String _wordTimestampsKey(String audioItemId) =>
      '$_kTranscriptPrefix${audioItemId}_words';

  Future<String?> getWordTimestamps(String audioItemId) async {
    try {
      return web.window.localStorage.getItem(_wordTimestampsKey(audioItemId));
    } catch (e) {
      AppLogger.log('WebDB', 'getWordTimestamps 失败: $e');
      return null;
    }
  }

  Future<void> updateWordTimestamps(String audioItemId, String? json) async {
    try {
      web.window.localStorage.setItem(_wordTimestampsKey(audioItemId), json ?? '');
    } catch (e) {
      AppLogger.log('WebDB', 'updateWordTimestamps 失败: $e');
    }
  }

  Future<void> clearDownloadState(String audioItemId,
      {required bool keepAudioSha256}) async {
    final item = _findById(audioItemId);
    if (item == null) return;
    final updated = item.copyWith(
      audioPath: null,
      contentStatus: null,
      originalAudioSha256: null,
      audioSha256: keepAudioSha256 ? item.audioSha256 : null,
    );
    await batchInsert([updated]);
  }

  /// 构建字幕内容的 localStorage key
  static String _transcriptKey(String audioItemId) =>
      '$_kTranscriptPrefix$audioItemId';

  Future<String?> getTranscriptSrt(String audioItemId) async {
    try {
      final raw = web.window.localStorage.getItem(_transcriptKey(audioItemId));
      return raw;
    } catch (e) {
      AppLogger.log('WebDB', 'getTranscriptSrt 失败: $e');
      return null;
    }
  }

  Future<void> updateTranscriptSrt(String audioItemId, String? srt) async {
    await saveTranscriptContent(audioItemId, srt: srt ?? '');
  }

  Future<List<AudioItem>> getRowsNeedingSrtBackfill() async => const [];

  Future<Set<String>> getAllReferencedRelPaths() async {
    final paths = <String>{};
    for (final item in _getAllItems()) {
      if (item.audioPath != null && item.audioPath!.isNotEmpty) {
        paths.add(item.audioPath!);
      }
      if (item.transcriptPath != null && item.transcriptPath!.isNotEmpty) {
        paths.add(item.transcriptPath!);
      }
    }
    return paths;
  }

  Future<void> saveTranscriptContent(String audioItemId,
      {required String srt, String? wordTimestampsJson}) async {
    // Web 端无 transcriptSrt / wordTimestampsJson 列，字幕和词级时间戳
    // 各自存入独立的 localStorage key，避免覆盖 AudioItem 的 audioSha256 字段
    try {
      web.window.localStorage.setItem(_transcriptKey(audioItemId), srt);
      if (wordTimestampsJson != null) {
        web.window.localStorage.setItem(
            _wordTimestampsKey(audioItemId), wordTimestampsJson);
      }
      AppLogger.log('WebDB', 'saveTranscriptContent: id=$audioItemId, srtLen=${srt.length}');
    } catch (e) {
      AppLogger.log('WebDB', 'saveTranscriptContent 失败: $e');
    }
  }
}

/// SentenceAiCacheDao Web Stub
class SentenceAiCacheDaoStub {
  const SentenceAiCacheDaoStub();
}

/// TtsCacheDao Web Stub
class TtsCacheDaoStub {
  const TtsCacheDaoStub();
}

/// LearnedWordFormDao Web Stub
class LearnedWordFormDaoStub {
  const LearnedWordFormDaoStub();
}

const String _kDailyStageStudyRecord = 'el_web_daily_stage_study_record_v1';

/// 每日分阶段学习记录（Web 版最小模型）
class DailyStageStudyRecord {
  final int id;
  final DateTime date;
  final int stage;
  final int studyTimeSeconds;
  final int inputTimeSeconds;
  final int outputTimeSeconds;
  const DailyStageStudyRecord({
    required this.id,
    required this.date,
    required this.stage,
    required this.studyTimeSeconds,
    required this.inputTimeSeconds,
    required this.outputTimeSeconds,
  });
  factory DailyStageStudyRecord.fromJson(Map<String, dynamic> json) =>
      DailyStageStudyRecord(
        id: json['id'] as int,
        date: DateTime.parse(json['date'] as String),
        stage: json['stage'] as int,
        studyTimeSeconds: json['studyTimeSeconds'] as int,
        inputTimeSeconds: json['inputTimeSeconds'] as int,
        outputTimeSeconds: json['outputTimeSeconds'] as int,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'stage': stage,
        'studyTimeSeconds': studyTimeSeconds,
        'inputTimeSeconds': inputTimeSeconds,
        'outputTimeSeconds': outputTimeSeconds,
      };
}

/// DailyStageStudyRecordDao Web 实现（基于 localStorage）
class DailyStageStudyRecordDaoWebImpl extends _WebDaoBase {
  DailyStageStudyRecordDaoWebImpl();

  List<DailyStageStudyRecord> _getData() {
    try {
      final raw = web.window.localStorage.getItem(_kDailyStageStudyRecord);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .map((e) => DailyStageStudyRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.log('WebDB', '读取分阶段学习记录失败: $e');
      return [];
    }
  }

  void _saveData(List<DailyStageStudyRecord> data) {
    try {
      final encoded = jsonEncode(data.map((r) => r.toJson()).toList());
      web.window.localStorage.setItem(_kDailyStageStudyRecord, encoded);
    } catch (e) {
      AppLogger.log('WebDB', '保存分阶段学习记录失败: $e');
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int _nextId(List<DailyStageStudyRecord> data) =>
      data.isEmpty ? 1 : data.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;

  /// 按日期和阶段 UPSERT 累加学习统计
  Future<void> upsertAdd(
    DateTime date,
    int stage, {
    int studyTime = 0,
    int inputTime = 0,
    int outputTime = 0,
  }) async {
    final dateOnly = _dateOnly(date);
    final data = _getData();
    final idx = data.indexWhere(
      (r) => _dateOnly(r.date) == dateOnly && r.stage == stage,
    );
    if (idx >= 0) {
      final r = data[idx];
      data[idx] = DailyStageStudyRecord(
        id: r.id,
        date: r.date,
        stage: r.stage,
        studyTimeSeconds: r.studyTimeSeconds + studyTime,
        inputTimeSeconds: r.inputTimeSeconds + inputTime,
        outputTimeSeconds: r.outputTimeSeconds + outputTime,
      );
    } else {
      data.add(DailyStageStudyRecord(
        id: _nextId(data),
        date: dateOnly,
        stage: stage,
        studyTimeSeconds: studyTime,
        inputTimeSeconds: inputTime,
        outputTimeSeconds: outputTime,
      ));
    }
    _saveData(data);
    _notify();
  }

  Future<List<DailyStageStudyRecord>> getByDate(DateTime date) async {
    final dateOnly = _dateOnly(date);
    return _getData()
        .where((r) => _dateOnly(r.date) == dateOnly)
        .toList();
  }
}

// ── Provider 注册 ────────────────────────────────────────────────────────────

/// 当前活跃的数据库实例（Web 端为 null）
final appDatabaseProvider = Provider<Object?>((ref) => null);

final audioItemDaoProvider =
    Provider<AudioItemDaoWebImpl>((ref)  => AudioItemDaoWebImpl());
final collectionDaoProvider =
    Provider<CollectionDaoWebImpl>((ref)  => CollectionDaoWebImpl());
final bookmarkDaoProvider =
    Provider<BookmarkDaoWebImpl>((ref)  => BookmarkDaoWebImpl());
final playbackStateDaoProvider =
    Provider<PlaybackStateDaoWebImpl>((ref)  => PlaybackStateDaoWebImpl());
final learningProgressDaoProvider =
    Provider<LearningProgressDaoWebImpl>((ref)  => LearningProgressDaoWebImpl());
final stageCompletionDaoProvider =
    Provider<StageCompletionDaoWebImpl>((ref)  => StageCompletionDaoWebImpl());
final tagDaoProvider =
    Provider<TagDaoWebImpl>((ref)  => TagDaoWebImpl());
final sentenceAiCacheDaoProvider =
    Provider<SentenceAiCacheDaoStub>((ref) => const SentenceAiCacheDaoStub());
final savedWordDaoProvider =
    Provider<SavedWordDaoWebImpl>((ref)  => SavedWordDaoWebImpl());
final savedSenseGroupDaoProvider =
    Provider<SavedSenseGroupDaoWebImpl>((ref)  => SavedSenseGroupDaoWebImpl());
final learnedWordFormDaoProvider =
    Provider<LearnedWordFormDaoStub>((ref) => const LearnedWordFormDaoStub());
final dailyStudyRecordDaoProvider =
    Provider<DailyStudyRecordDaoWebImpl>((ref)  => DailyStudyRecordDaoWebImpl());
final dailyStageStudyRecordDaoProvider =
    Provider<DailyStageStudyRecordDaoWebImpl>((ref)  => DailyStageStudyRecordDaoWebImpl());
final ttsCacheDaoProvider =
    Provider<TtsCacheDaoStub>((ref) => const TtsCacheDaoStub());

// ── bookmarkListProvider ──────────────────────────────────────────────────────

final bookmarkListProvider =
    StreamProvider<List<BookmarkWithAudio>>((ref) async* {
  final dao = ref.watch(bookmarkDaoProvider);
  yield dao._buildAllWithAudioName();
  await for (final _ in dao._onChange) {
    yield dao._buildAllWithAudioName();
  }
});

// ── StudyTimeService Web 实现 ─────────────────────────────────────────────────

/// Web 端 StudyTimeService 实现（基于 localStorage 的 DailyStudyRecordDao）
///
/// 保留与移动端相同的公共接口，方便调用方无需条件编译。
class StudyTimeServiceWebImpl {
  final DailyStudyRecordDaoWebImpl _dao;
  final DailyStageStudyRecordDaoWebImpl _stageDao;

  StudyTimeServiceWebImpl(this._dao, this._stageDao);

  Future<int> getStudyTime(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.studyTimeSeconds ?? 0;
  }

  Future<int> getTodayStudyTime() => getStudyTime(DateTime.now());

  /// 注意：Web 端暂不支持阶段明细写入（stage 参数被忽略）
  Future<void> addStudyTime(
    int seconds, {
    DateTime? date,
    dynamic stage,
  }) async {
    if (seconds <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), studyTime: seconds);
  }

  Future<int> getStudyStreak({DateTime? now}) async => _dao.getStreak(now: now);

  Future<List<int>> getWeeklyStudyTimes({DateTime? now}) async {
    final today = DateTime((now ?? DateTime.now()).year,
        (now ?? DateTime.now()).month, (now ?? DateTime.now()).day);
    final start = today.subtract(const Duration(days: 6));
    final records = await _dao.getBetween(start, today);
    final Map<int, int> dayMap = {};
    for (final r in records) {
      final key = r.date.year * 10000 + r.date.month * 100 + r.date.day;
      dayMap[key] = r.studyTimeSeconds;
    }
    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final key = date.year * 10000 + date.month * 100 + date.day;
      result.add(dayMap[key] ?? 0);
    }
    return result;
  }

  Future<int> getWeekTotalStudyTime({DateTime? now}) async {
    final today = DateTime((now ?? DateTime.now()).year,
        (now ?? DateTime.now()).month, (now ?? DateTime.now()).day);
    final daysSinceMonday = today.weekday - 1;
    final monday = today.subtract(Duration(days: daysSinceMonday));
    final records = await _dao.getBetween(monday, today);
    return records.fold<int>(0, (sum, r) => sum + r.studyTimeSeconds);
  }

  Future<int> getInputWords(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.inputWords ?? 0;
  }

  Future<int> getTodayInputWords() => getInputWords(DateTime.now());

  Future<void> addInputWords(int count, {DateTime? date}) async {
    if (count <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), inputWords: count);
  }

  Future<int> getOutputWords(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.outputWords ?? 0;
  }

  Future<int> getTodayOutputWords() => getOutputWords(DateTime.now());

  Future<void> addOutputWords(int count, {DateTime? date}) async {
    if (count <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), outputWords: count);
  }

  Future<int> getInputTime(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.inputTimeSeconds ?? 0;
  }

  Future<int> getTodayInputTime() => getInputTime(DateTime.now());

  Future<void> addInputTime(int seconds,
      {DateTime? date, dynamic stage}) async {
    if (seconds <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), inputTime: seconds);
  }

  Future<int> getOutputTime(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.outputTimeSeconds ?? 0;
  }

  Future<int> getTodayOutputTime() => getOutputTime(DateTime.now());

  Future<void> addOutputTime(int seconds,
      {DateTime? date, dynamic stage}) async {
    if (seconds <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), outputTime: seconds);
  }
}

final studyTimeServiceProvider = Provider<StudyTimeServiceWebImpl>((ref) {
  return StudyTimeServiceWebImpl(
    ref.watch(dailyStudyRecordDaoProvider),
    ref.watch(dailyStageStudyRecordDaoProvider),
  );
});
