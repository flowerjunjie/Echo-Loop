/// Stub for sherpa_onnx_bindings.dart
/// Provides type-safe FFI function pointer stubs for web build.
/// Uses conditional import to avoid dart:ffi on VM/test platforms.
library;

import 'dart:ffi' if (dart.library.html) 'dart:js_interop';

/// Binding function pointer types.
typedef FFIPointerFn = dynamic Function(dynamic);
typedef FFIVoidPtrFn = void Function(dynamic);
typedef FFIUint8PtrFn = void Function(dynamic);
typedef FFIVoidPtrToUint8PtrFn = dynamic Function(dynamic);

/// Stub class mirroring real SherpaOnnxBindings with proper FFI types.
class SherpaOnnxBindings {
  // VAD
  static dynamic voiceActivityDetectorAcceptWaveform;
  static dynamic voiceActivityDetectorEmpty;
  static dynamic voiceActivityDetectorFront;
  static dynamic voiceActivityDetectorPop;
  static dynamic voiceActivityDetectorFlush;
  static dynamic voiceActivityDetectorReset;
  static dynamic createVoiceActivityDetector;
  static dynamic destroyVoiceActivityDetector;

  // Offline stream
  static dynamic destroyOfflineStream;
  static dynamic acceptWaveformOffline;

  // Recognizer
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
