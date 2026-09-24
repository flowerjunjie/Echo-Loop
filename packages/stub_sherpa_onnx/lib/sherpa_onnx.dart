library sherpa_onnx;

import 'dart:typed_data';

// ── VAD Segment ──────────────────────────────────────────────────────────────
class VadSegment {
  final Float32List samples;
  VadSegment(this.samples);
}

// ── Config classes ───────────────────────────────────────────────────────────
class SileroVadModelConfig {
  const SileroVadModelConfig({
    this.model = '',
    this.threshold = 0.5,
    this.minSilenceDuration = 0.5,
    this.minSpeechDuration = 0.25,
    this.windowSize = 512,
    this.maxSpeechDuration = 5.0,
  });
  final String model;
  final double threshold;
  final double minSilenceDuration;
  final double minSpeechDuration;
  final int windowSize;
  final double maxSpeechDuration;
}

class VadModelConfig {
  VadModelConfig({
    this.sileroVad = const SileroVadModelConfig(),
    this.sampleRate = 16000,
    this.numThreads = 1,
    this.provider = 'cpu',
    this.debug = false,
  });
  final SileroVadModelConfig sileroVad;
  final int? sampleRate;
  final int? numThreads;
  final String? provider;
  final bool? debug;
}

// ── VoiceActivityDetector ────────────────────────────────────────────────────
/// Stub that matches the real sherpa_onnx VoiceActivityDetector API.
///
/// Real API:
///   - factory constructor: VoiceActivityDetector({required VadModelConfig config, required double bufferSizeInSeconds})
///   - void acceptWaveform(Float32List samples)
///   - bool isEmpty()        ← method, not getter!
///   - VadSegment front()    ← method returning non-null
///   - void pop(), flush(), reset(), free()
class VoiceActivityDetector {
  VoiceActivityDetector({required this.config, required double bufferSizeInSeconds});

  final VadModelConfig config;

  void acceptWaveform(Float32List samples) {}
  bool isEmpty() => false;
  VadSegment front() => VadSegment(Float32List(0));
  void pop() {}
  void flush() {}
  void reset() {}
  void free() {}
  void destroy() {}
}

// ── OfflineStream ────────────────────────────────────────────────────────────
class OfflineStream {
  OfflineStream({this.ptr});
  dynamic ptr;
  void acceptWaveform({required Float32List samples, required int sampleRate}) {}
  void inputFinished() {}
  bool isReady() => false;
  dynamic read() => null;
  void reset() {}
  void free() {}
  void destroy() {}
  bool get isEmpty => false;
}

// ── OfflineRecognizer ────────────────────────────────────────────────────────
class OfflineRecognizerConfig {
  OfflineRecognizerConfig({required this.model});
  final OfflineModelConfig model;
}

class OfflineRecognizerResult {
  OfflineRecognizerResult({required this.text, this.tokens = const [], this.timestamps = const []});
  final String text;
  final List<String> tokens;
  final List<double> timestamps;
}

class OfflineRecognizer {
  OfflineRecognizer(OfflineRecognizerConfig config);
  OfflineStream createStream() => OfflineStream();
  void decode(OfflineStream stream) {}
  OfflineRecognizerResult getResult(OfflineStream stream) =>
      OfflineRecognizerResult(text: '');
  void destroy() {}
  void free() {}
}

// ── Model configs ────────────────────────────────────────────────────────────
class OfflineModelConfig {
  OfflineModelConfig({
    this.moonshine,
    this.tokens = '',
    this.modelType = 'transducer',
    this.numThreads = 1,
    this.debug = false,
    this.provider = 'cpu',
    this.preprocessor = '',
    this.encoder = '',
    this.uncachedDecoder = '',
    this.cachedDecoder = '',
    this.whisper,
    this.transducer,
  });
  final OfflineMoonshineModelConfig? moonshine;
  final String tokens;
  final String modelType;
  final int numThreads;
  final bool debug;
  final String provider;
  final String preprocessor;
  final String encoder;
  final String uncachedDecoder;
  final String cachedDecoder;
  final OfflineWhisperModelConfig? whisper;
  final dynamic transducer;
}

class OfflineMoonshineModelConfig {
  OfflineMoonshineModelConfig({
    this.preprocessor = '',
    this.encoder = '',
    this.uncachedDecoder = '',
    this.cachedDecoder = '',
    this.model = '',
  });
  final String preprocessor;
  final String encoder;
  final String uncachedDecoder;
  final String cachedDecoder;
  final String model;
}

class OfflineWhisperModelConfig {
  OfflineWhisperModelConfig({
    this.encoder = '',
    this.decoder = '',
    this.language = 'en',
    this.task = 'transcribe',
    this.enableSegmentTimestamps = false,
  });
  final String encoder;
  final String decoder;
  final String language;
  final String task;
  final bool enableSegmentTimestamps;
}

// ── TTS stubs ────────────────────────────────────────────────────────────────
class OfflineTtsResult {
  OfflineTtsResult({required this.samples, required this.sampleRate});
  final dynamic samples;
  final int sampleRate;
}

class OfflineTts {
  OfflineTts(OfflineTtsConfig config);
  OfflineTtsResult generate({required String text, required int sid, required double speed}) =>
      OfflineTtsResult(samples: Float32List(0), sampleRate: 24000);
  void free() {}
}
class OfflineTtsConfig {
  OfflineTtsConfig({
    this.model,
    this.voices,
    this.tokens,
    this.dataDir,
    this.numThreads,
    this.provider,
    this.debug,
  });
  final OfflineTtsModelConfig? model;
  final dynamic voices;
  final dynamic tokens;
  final String? dataDir;
  final int? numThreads;
  final String? provider;
  final bool? debug;
}
class OfflineTtsModelConfig {
  OfflineTtsModelConfig({
    this.vits,
    this.kokoro,
    this.numThreads,
    this.provider,
    this.debug,
  });
  final OfflineTtsVitsModelConfig? vits;
  final OfflineTtsKokoroModelConfig? kokoro;
  final int? numThreads;
  final String? provider;
  final bool? debug;
}
class OfflineTtsVitsModelConfig {
  OfflineTtsVitsModelConfig({this.model, this.tokens, this.dataDir});
  final String? model;
  final String? tokens;
  final String? dataDir;
}
class OfflineTtsKokoroModelConfig {
  OfflineTtsKokoroModelConfig({
    this.model = '',
    this.voices = '',
    this.tokens = '',
    this.dataDir = '',
    this.lengthScale = 1.0,
    this.dictDir = '',
    this.lexicon = '',
    this.lang = '',
  });
  final String model;
  final String voices;
  final String tokens;
  final String dataDir;
  final double lengthScale;
  final String dictDir;
  final String lexicon;
  final String lang;
}

// ── Entry point ──────────────────────────────────────────────────────────────
void initBindings([String? p]) {}
dynamic writeWave({required String filename, required dynamic samples, required int sampleRate}) => true;

// ── Bindings stub (required by engine) ──────────────────────────────────────
class SherpaOnnxBindings {
  // VAD
  static dynamic createVoiceActivityDetector;
  static dynamic destroyVoiceActivityDetector;
  static dynamic voiceActivityDetectorAcceptWaveform;
  static dynamic voiceActivityDetectorEmpty;
  static dynamic voiceActivityDetectorFront;
  static dynamic voiceActivityDetectorPop;
  static dynamic voiceActivityDetectorFlush;
  static dynamic voiceActivityDetectorReset;
  
  // Offline stream
  static dynamic destroyOfflineStream;
  static dynamic acceptWaveformOffline;
  static dynamic offlineStreamInputFinished;
  static dynamic offlineStreamIsReady;
  static dynamic offlineStreamRead;
  static dynamic offlineStreamReset;
  
  // Recognizer
  static dynamic createOfflineRecognizer;
  static dynamic destroyOfflineRecognizer;
  static dynamic offlineRecognizerCreateStream;
  static dynamic offlineRecognizerDecode;
  static dynamic offlineRecognizerGetResult;
  static dynamic getOfflineStreamResultAsJson;
  static dynamic destroyOfflineStreamResultJson;
  
  // TTS
  static dynamic createOfflineTts;
  static dynamic offlineTtsGenerate;
  static dynamic destroyOfflineTts;
}
