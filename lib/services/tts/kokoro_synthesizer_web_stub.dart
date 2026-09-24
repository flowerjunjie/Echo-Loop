/// Web 平台 KokoroSynthesizer 占位实现
///
/// Web 端不支持离线 TTS（无 FFI），所有方法抛出 UnsupportedError。
library;

import 'tts_engine.dart';

/// Web 平台抽象接口占位
abstract interface class KokoroNativeSynthesizer {
  Future<void> init(dynamic paths, {int numThreads});
  Future<int?> synthesize({required String text, required int sid, required double speed, required String outputPath});
  Future<void> dispose();
}

/// Web 平台 IsolateKokoroSynthesizer 占位实现
class IsolateKokoroSynthesizer implements KokoroNativeSynthesizer {
  @override
  Future<void> init(dynamic paths, {int numThreads = 2}) async {
    throw UnsupportedError('Kokoro TTS not supported on Web platform');
  }
  @override
  Future<int?> synthesize({required String text, required int sid, required double speed, required String outputPath}) async => null;
  @override
  Future<void> dispose() async {}
}

/// Web 平台 KokoroSynthesizer 占位实现
class KokoroSynthesizer implements TtsEngine {
  String get name => 'kokoro-web-stub';
  @override
  Future<void> initialize() async => throw UnsupportedError('Kokoro TTS not supported on Web');
  @override
  Future<void> applyConfig(TtsSpeechConfig config) async => throw UnsupportedError('Kokoro TTS not supported on Web');
  @override
  Future<TtsSynthesisResult?> synthesize(String text, {required String outputDir, required String baseName, TtsSpeechConfig? config}) async => throw UnsupportedError('Kokoro TTS not supported on Web');
  @override
  Future<bool> speakLive(String text) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
