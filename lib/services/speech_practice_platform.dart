/// 录音识别平台桥接。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import '../features/auth/providers/auth_providers.dart';
import '../providers/asr_engine_provider.dart';
import '../providers/offline_asr_settings_provider.dart';
// 条件导入：Web 平台使用真实实现，非 Web 平台（含测试）使用 stub。
// 避免 dart:js_interop 被带入 VM 测试导致编译失败。
import '../services/web/web_audio_recorder_stub.dart'
    if (dart.library.html) '../services/web/web_audio_recorder.dart';
import '../services/web/web_asr_service_stub.dart'
    if (dart.library.html) '../services/web/web_asr_service.dart';
import 'app_logger.dart';
import 'asr/offline_asr_backend.dart';

/// 统一后端 provider。
///
/// 只负责选择后端实例，不调用副作用方法。
/// recognition 模式由 [RecordingService.startRecording] 在 warmup 前设置。
///
/// - ASR 关闭 → 平台后端（纯录音）
/// - Apple Speech → 平台后端（平台 ASR）
/// - Echo Loop AI + 引擎就绪 → OfflineAsrBackend（离线转录）
/// - Echo Loop AI + 引擎未就绪 → 平台后端（降级为纯录音）
final speechPracticeBackendProvider = Provider<SpeechPracticeBackend>((ref) {
  // Web平台使用Web后端
  if (kIsWeb) {
    final session = ref.watch(authSessionProvider);
    return WebSpeechPracticeBackend(token: session?.accessToken);
  }

  final s = ref.watch(offlineAsrSettingsProvider);
  final platform = SpeechPracticePlatform.instance;

  if (s.isOfflineReady) {
    final engine = ref.read(offlineAsrEngineProvider);
    return OfflineAsrBackend(platform: platform, engine: engine);
  }

  return platform;
});

/// 平台桥接异常。
class SpeechPracticePlatformException implements Exception {
  /// 平台错误码。
  final String code;

  /// 错误消息。
  final String message;

  const SpeechPracticePlatformException(this.code, this.message);

  @override
  String toString() => 'SpeechPracticePlatformException($code, $message)';
}

/// 统一的录音识别后端接口。
abstract class SpeechPracticeBackend {
  /// 当前平台是否支持该能力。
  bool get isSupported;

  /// 获取权限状态。
  Future<SpeechPracticePermissionState> getPermissionStatus();

  /// 请求权限。
  ///
  /// `onlyMic=true` 时只请求麦克风（关闭 ASR / Echo Loop 离线后端场景），
  /// 不触发平台原生语音识别系统弹窗，遵循最小权限原则。
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  });

  /// 录音识别事件流。
  Stream<SpeechPracticeEvent> get events;

  /// 获取设备物理 RAM（字节数）。
  Future<int> getDeviceRamBytes();

  /// 设置是否启用平台语音识别。
  ///
  /// `false`（默认）：纯录音 + VAD，stopSession 返回空 transcript。
  /// `true`：录音 + 平台 ASR（iOS/macOS SFSpeechRecognizer）。
  /// 必须在 [warmup] 之前调用。
  Future<void> setRecognitionEnabled(bool enabled);

  /// 预热引擎：页面进入时调用，提前初始化 AVAudioEngine + tap。
  Future<void> warmup({String locale = 'en-US'});

  /// 开始 live ASR 录音。
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  });

  /// 停止 live ASR 录音。
  Future<SpeechPracticeStopResult> stopSession();

  /// 取消当前录音识别会话。
  Future<void> cancelSession();

  /// 删除临时录音文件。
  Future<void> deleteRecording(String filePath);

  /// 释放引擎资源：页面退出时调用，销毁 AVAudioEngine + tap。
  Future<void> shutdown();
}

/// 原生录音识别桥接。
class SpeechPracticePlatform implements SpeechPracticeBackend {
  SpeechPracticePlatform();

  static SpeechPracticePlatform _instance = SpeechPracticePlatform();
  static const MethodChannel _channel = MethodChannel(
    'top.echo-loop/speech_practice',
  );
  static const EventChannel _eventChannel = EventChannel(
    'top.echo-loop/speech_practice/events',
  );

  Stream<SpeechPracticeEvent>? _events;

  /// 全局单例。
  static SpeechPracticePlatform get instance => _instance;

  /// 测试时替换单例。
  @visibleForTesting
  static SpeechPracticePlatform replaceInstance(
    SpeechPracticePlatform platform,
  ) {
    final old = _instance;
    _instance = platform;
    return old;
  }

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS || Platform.isAndroid);

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    _ensureSupported();
    final result = await _invokeMap('getPermissionStatus');
    return SpeechPracticePermissionState(
      microphone: _parsePermissionStatus(result['microphoneStatus'] as String?),
      speech: _parsePermissionStatus(result['speechStatus'] as String?),
    );
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  }) async {
    _ensureSupported();
    final result = await _invokeMap('requestPermissions', {'onlyMic': onlyMic});
    return SpeechPracticePermissionState(
      microphone: _parsePermissionStatus(result['microphoneStatus'] as String?),
      speech: _parsePermissionStatus(result['speechStatus'] as String?),
    );
  }

  @override
  Stream<SpeechPracticeEvent> get events {
    _ensureSupported();
    return _events ??= _eventChannel
        .receiveBroadcastStream()
        .map(
          (event) => _parseEvent(
            (event as Map<Object?, Object?>?) ?? <Object?, Object?>{},
          ),
        )
        .handleError((error) {
          throw _parseException(error);
        })
        .asBroadcastStream();
  }

  @override
  Future<int> getDeviceRamBytes() async {
    _ensureSupported();
    final result = await _invokeMap('getDeviceInfo');
    return (result['ramBytes'] as int?) ?? 0;
  }

  @override
  Future<void> setRecognitionEnabled(bool enabled) async {
    _ensureSupported();
    AppLogger.log('SpeechPlatform', '● setRecognitionEnabled=$enabled');
    await _invokeMap('setRecognitionEnabled', {'enabled': enabled});
  }

  @override
  Future<void> warmup({String locale = 'en-US'}) async {
    _ensureSupported();
    AppLogger.log('SpeechPlatform', '┌ warmup locale=$locale');
    await _invokeMap('warmup', {'locale': locale});
    AppLogger.log('SpeechPlatform', '└ warmup done');
  }

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    _ensureSupported();
    AppLogger.log(
      'SpeechPlatform',
      '┌ startSession promptId=$promptId locale=$locale',
    );
    final result = await _invokeMap('startSession', {
      'promptId': promptId,
      'locale': locale,
    });
    final filePath = result['filePath'] as String?;
    if (filePath == null || filePath.isEmpty) {
      AppLogger.log(
        'SpeechPlatform',
        '└ startSession failed: missing filePath',
      );
      throw const SpeechPracticePlatformException(
        'invalidResult',
        'Missing recording file path',
      );
    }
    AppLogger.log('SpeechPlatform', '└ startSession filePath=$filePath');
    return filePath;
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    _ensureSupported();
    AppLogger.log('SpeechPlatform', '┌ stopSession');
    final result = await _invokeMap('stopSession');
    final stopResult = SpeechPracticeStopResult(
      filePath: result['filePath'] as String?,
    );
    AppLogger.log(
      'SpeechPlatform',
      '└ stopSession filePath=${stopResult.filePath ?? '(null)'}',
    );
    return stopResult;
  }

  @override
  Future<void> cancelSession() async {
    _ensureSupported();
    AppLogger.log('SpeechPlatform', '● cancelSession');
    await _invokeMap('cancelSession');
  }

  @override
  Future<void> deleteRecording(String filePath) async {
    _ensureSupported();
    AppLogger.log('SpeechPlatform', '● deleteRecording filePath=$filePath');
    await _invokeMap('deleteRecording', {'filePath': filePath});
  }

  @override
  Future<void> shutdown() async {
    _ensureSupported();
    AppLogger.log('SpeechPlatform', '● shutdown');
    await _invokeMap('shutdown');
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice is not supported on this platform',
      );
    }
  }

  Future<Map<Object?, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMethod<Object?>(method, arguments);
      return (result as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    } on MissingPluginException {
      throw const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice plugin is not registered on this platform',
      );
    } on PlatformException catch (error) {
      throw SpeechPracticePlatformException(
        error.code,
        error.message ?? 'Unknown platform error',
      );
    }
  }

  SpeechPracticeEvent _parseEvent(Map<Object?, Object?> event) {
    final type = switch (event['type'] as String?) {
      'partialTranscriptUpdated' =>
        SpeechPracticeEventType.partialTranscriptUpdated,
      'speechStarted' => SpeechPracticeEventType.speechStarted,
      'silenceProgress' => SpeechPracticeEventType.silenceProgress,
      'finalTranscriptReady' => SpeechPracticeEventType.finalTranscriptReady,
      _ => SpeechPracticeEventType.error,
    };
    return SpeechPracticeEvent(
      type: type,
      promptId: (event['promptId'] as String?) ?? '',
      transcript: event['transcript'] as String?,
      errorCode: event['errorCode'] as String?,
      errorMessage: event['errorMessage'] as String?,
      silenceDuration: switch (event['silenceMs']) {
        final int ms => Duration(milliseconds: ms),
        final num ms => Duration(milliseconds: ms.round()),
        _ => null,
      },
    );
  }

  Exception _parseException(Object error) {
    if (error is PlatformException) {
      return SpeechPracticePlatformException(
        error.code,
        error.message ?? 'Unknown platform error',
      );
    }
    if (error is MissingPluginException) {
      return const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice plugin is not registered on this platform',
      );
    }
    return SpeechPracticePlatformException('unknown', error.toString());
  }

  SpeechPracticePermissionStatus _parsePermissionStatus(String? value) {
    return switch (value) {
      'granted' => SpeechPracticePermissionStatus.granted,
      'denied' => SpeechPracticePermissionStatus.denied,
      'restricted' => SpeechPracticePermissionStatus.restricted,
      _ => SpeechPracticePermissionStatus.notDetermined,
    };
  }
}

// ---------------------------------------------------------------------------
// Web平台录音识别后端
// ---------------------------------------------------------------------------

/// Web平台录音识别后端
///
/// 使用Web Audio API + MediaRecorder进行录音，
/// 通过echo-transcribe后端API进行转录。
/// Web 平台录音识别后端
///
/// 使用 [WebAudioRecorderImpl] 录音（MediaRecorder API），
/// 通过 [WebAsrService] 将 Base64 音频发送到 echo-transcribe 后端转录。
/// 转录结果通过 [SpeechPracticeStopResult.transcriptText] 直接返回，
/// 无需写本地文件。
class WebSpeechPracticeBackend implements SpeechPracticeBackend {
  WebSpeechPracticeBackend({String? token}) {
    _transcriber = WebAsrService();
  }

  late final WebAsrService _transcriber;
  final _recorder = WebAudioRecorderImpl();

  @override
  bool get isSupported => kIsWeb;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    return const SpeechPracticePermissionState();
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  }) async {
    return getPermissionStatus();
  }

  @override
  Stream<SpeechPracticeEvent> get events => const Stream.empty();

  @override
  Future<int> getDeviceRamBytes() async => 0;

  @override
  Future<void> setRecognitionEnabled(bool enabled) async {}

  @override
  Future<void> warmup({String locale = 'en-US'}) async {}

  /// 开始录音会话（必须在用户手势上下文中调用）
  ///
  /// 请求麦克风权限并启动 MediaRecorder。
  /// 返回固定 promptId 用于追踪会话。
  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    try {
      await _recorder.start();
      AppLogger.log('WebBackend', '● startSession promptId=$promptId');
    } catch (e) {
      AppLogger.log('WebBackend', '✗ startSession 失败: $e');
    }
    return promptId;
  }

  /// 停止录音并转录
  ///
  /// 停止 MediaRecorder → 获取 Base64 音频 → 调用 WebAsrService 转录。
  /// 转录文本通过 [SpeechPracticeStopResult.transcriptText] 返回，
  /// 绕过 filePath 依赖，让 _doTranscribe 不走空结果分支。
  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    try {
      final base64 = await _recorder.stopAsBase64();
      if (base64.isEmpty) {
        AppLogger.log('WebBackend', '⚠ stopSession 无音频数据');
        return const SpeechPracticeStopResult(filePath: null);
      }
      final result = await _transcriber.transcribe(audioBase64: base64);
      AppLogger.log(
        'WebBackend',
        '● stopSession text="${result.text}" duration=${result.durationMs}ms',
      );
      return SpeechPracticeStopResult(
        filePath: null,
        transcriptText: result.text,
      );
    } catch (e) {
      AppLogger.log('WebBackend', '✗ stopSession 转录失败: $e');
      return const SpeechPracticeStopResult(filePath: null);
    }
  }

  @override
  Future<void> cancelSession() async {
    await _recorder.cancel();
  }

  @override
  Future<void> deleteRecording(String filePath) async {}

  @override
  Future<void> shutdown() async {
    await _recorder.cancel();
  }
}
