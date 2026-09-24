/// Web 平台 PiperSynthesizer 占位实现
///
/// Web 端不支持离线 TTS（无 FFI），所有方法抛出 UnsupportedError。
library;

import 'tts_engine.dart';

/// Web 平台抽象接口占位
abstract interface class PiperNativeSynthesizer {
  Future<void> init({int numThreads});
  Future<int?> synthesize({required dynamic paths, required String voiceId, required String text, required double speed, required String outputPath});
  Future<void> dispose();
}

/// Web 平台 IsolatePiperSynthesizer 占位实现
class IsolatePiperSynthesizer implements PiperNativeSynthesizer {
  @override
  Future<void> init({int numThreads = 2}) async {
    throw UnsupportedError('Piper TTS not supported on Web platform');
  }
  @override
  Future<int?> synthesize({required dynamic paths, required String voiceId, required String text, required double speed, required String outputPath}) async => null;
  @override
  Future<void> dispose() async {}
}

/// Web 平台 PiperSynthesizer 占位实现
class PiperSynthesizer implements TtsEngine {
  String get name => 'piper-web-stub';
  @override
  Future<void> initialize() async => throw UnsupportedError('Piper TTS not supported on Web');
  @override
  Future<void> applyConfig(TtsSpeechConfig config) async => throw UnsupportedError('Piper TTS not supported on Web');
  @override
  Future<TtsSynthesisResult?> synthesize(String text, {required String outputDir, required String baseName, TtsSpeechConfig? config}) async => throw UnsupportedError('Piper TTS not supported on Web');
  @override
  Future<bool> speakLive(String text) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
