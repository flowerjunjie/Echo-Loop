/// Web平台TTS服务（基于浏览器SpeechSynthesis API）
///
/// 使用 `dart:js_interop` + `package:web` 调用浏览器原生语音合成API，
/// 无需后端依赖，离线可用。
library;

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../app_logger.dart';

/// Web TTS服务接口
abstract class WebTtsService {
  /// 是否正在播放
  bool get isSpeaking;

  /// 播放文本
  Future<void> speak({
    required String text,
    int? voiceIndex,
    double rate = 1.0,
  });

  /// 停止播放
  void stop();
}

/// Web TTS异常
class WebTtsException implements Exception {
  final String message;
  const WebTtsException(this.message);

  @override
  String toString() => 'WebTtsException: $message';
}

/// Web平台TTS实现（基于浏览器SpeechSynthesis API）
///
/// 使用浏览器原生的Web Speech API进行文本转语音。
/// 支持多语言（通过voiceIndex选择不同音色）。
///
/// **注意**：浏览器语音合成质量因设备和浏览器而异。
class WebTtsServiceImpl implements WebTtsService {
  web.SpeechSynthesis? _synth;
  bool _isSpeaking = false;
  List<web.SpeechSynthesisVoice>? _cachedVoices;

  @override
  bool get isSpeaking => _isSpeaking;

  WebTtsServiceImpl() {
    _synth = web.window.speechSynthesis;
    _loadVoices();
    // Chrome会在voiceschanged事件时加载语音列表
    _synth!.onvoiceschanged = ((JSAny _) => _loadVoices()).toJS;
  }

  /// 加载可用语音列表
  void _loadVoices() {
    _cachedVoices = _synth!.getVoices().toDart;
    AppLogger.log('WebTTS', '加载语音数: ${_cachedVoices?.length ?? 0}');
  }

  @override
  Future<void> speak({
    required String text,
    int? voiceIndex,
    double rate = 1.0,
  }) async {
    if (_isSpeaking) {
      stop();
    }

    if (text.isEmpty) return;

    try {
      final utterance = web.SpeechSynthesisUtterance(text);
      utterance.rate = rate;

      // 选择语音
      if (voiceIndex != null && _cachedVoices != null && voiceIndex < _cachedVoices!.length) {
        utterance.voice = _cachedVoices![voiceIndex];
        AppLogger.log('WebTTS', '使用语音voiceIndex: ${utterance.voice?.name ?? 'unknown'}');
      }

      // 播放完成回调
      utterance.onend = ((JSAny _) {
        _isSpeaking = false;
        AppLogger.log('WebTTS', '播放完成');
      }).toJS;

      // 播放错误回调
      utterance.onerror = ((JSAny e) {
        _isSpeaking = false;
        AppLogger.log('WebTTS', '播放错误: $e');
      }).toJS;

      _synth!.speak(utterance);
      _isSpeaking = true;
      AppLogger.log('WebTTS', '开始播放: ${text.substring(0, text.length.clamp(0, 50))}...');
    } catch (e) {
      _isSpeaking = false;
      AppLogger.log('WebTTS', '播放失败: $e');
      throw WebTtsException('播放失败: $e');
    }
  }

  @override
  void stop() {
    _synth?.cancel();
    _isSpeaking = false;
    AppLogger.log('WebTTS', '已停止播放');
  }
}
