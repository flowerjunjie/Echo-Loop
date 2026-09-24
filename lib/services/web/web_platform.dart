/// Web平台检测与适配服务
library;

import 'package:flutter/foundation.dart';

/// Web平台检测
class WebPlatform {
  /// 是否运行在Web平台
  static bool get isWeb => kIsWeb;

  /// 是否支持录音（需要用户授权）
  static Future<bool> get isRecordingSupported async {
    if (!kIsWeb) return false;
    // Web端录音需要用户交互触发，此处返回true表示平台支持
    return true;
  }

  /// 是否支持Speech Recognition
  static bool get isSpeechRecognitionSupported => kIsWeb;

  /// 是否支持Speech Synthesis
  static bool get isSpeechSynthesisSupported => kIsWeb;
}
