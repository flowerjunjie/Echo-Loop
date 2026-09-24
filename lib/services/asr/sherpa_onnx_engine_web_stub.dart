/// Web 平台 sherpa_onnx_engine 占位实现
///
/// Web 端不支持离线 ASR（无 FFI），所有方法抛出 UnsupportedError。
library;


import 'offline_asr_engine.dart';

/// Web 平台 SherpaOnnxEngine 占位实现
///
/// 所有方法均抛出 [UnsupportedError]，因为 Web 平台不支持 sherpa-onnx FFI。
class SherpaOnnxEngine implements OfflineAsrEngine {
  @override
  String get name => 'sherpa-onnx-web-stub';

  @override
  bool get isReady => false;

  @override
  AsrModelInfo? get currentModel => null;

  @override
  Future<void> initialize(AsrModelConfig config) async {
    throw UnsupportedError(
        'Offline ASR (sherpa-onnx) is not supported on Web platform. '
        'Use online transcription API instead.');
  }

  @override
  Future<AsrResult> transcribe(String wavPath) async {
    throw UnsupportedError(
        'Offline ASR (sherpa-onnx) is not supported on Web platform.');
  }

  @override
  Future<List<AsrSegment>> transcribeSegments(
    String wavPath, {
    void Function(double)? onProgress,
  }) async {
    throw UnsupportedError(
        'Offline ASR (sherpa-onnx) is not supported on Web platform.');
  }

  @override
  Future<void> dispose() async {
    // No-op on web
  }
}
