/// Web平台录音服务
///
/// 使用 `dart:js_interop` + `package:web` 调用浏览器 MediaRecorder API，
/// 将音频数据编码为 Base64 供 [WebAsrService] 转录。
///
/// **重要**：[start] 必须在用户手势（click/touch）上下文中调用，
/// 否则浏览器会拒绝麦克风权限。
library;

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../app_logger.dart';

/// Web录音服务接口
abstract class WebAudioRecorder {
  /// 是否正在录音
  bool get isRecording;

  /// 开始录音（需要用户手势触发）
  Future<void> start();

  /// 停止录音并返回音频数据（Base64编码）
  Future<String> stopAsBase64();

  /// 取消录音
  Future<void> cancel();

  /// 释放资源
  void dispose();
}

/// Web录音异常
class WebRecordingException implements Exception {
  final String message;
  const WebRecordingException(this.message);

  @override
  String toString() => 'WebRecordingException: $message';
}

/// Web录音服务实现（基于 dart:js_interop + package:web）
///
/// 流程：getUserMedia → MediaRecorder → ondataavailable收集Blob →
/// onstop时FileReaderSync同步转Base64。
class WebAudioRecorderImpl implements WebAudioRecorder {
  bool _isRecording = false;
  String? _audioBase64;
  web.MediaRecorder? _recorder;
  web.MediaStream? _stream;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> start() async {
    if (_isRecording) return;

    try {
      // 请求麦克风权限（必须在用户手势上下文中调用）
      final constraints = web.MediaStreamConstraints(
        audio: true.toJS,
        video: false.toJS,
      );
      _stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      AppLogger.log('WebAudio', '麦克风获取成功');

      // 创建 MediaRecorder，收集每一段数据
      _recorder = web.MediaRecorder(_stream!);
      final blobs = <web.Blob>[];

      // ondataavailable：每次采集到音频数据块时回调
      _recorder!.ondataavailable = ((web.Blob blob) {
        blobs.add(blob);
        AppLogger.log('WebAudio', '收到数据块, size=${blob.size}B');
      }).toJS;

      // onstop：录音结束时合并所有数据块并编码为 Base64
      _recorder!.onstop = ((JSAny _) {
        _recorder = null;
        if (blobs.isEmpty) {
          _audioBase64 = '';
          return;
        }
        // 合并所有 dataavailable 块为一个完整 blob
        final blobArray = JSArray<JSAny>.withLength(blobs.length);
        for (var i = 0; i < blobs.length; i++) {
          blobArray[i] = blobs[i].jsify()!;
        }
        final merged = web.Blob(
          blobArray,
          web.BlobPropertyBag(type: 'audio/webm'),
        );
        _audioBase64 = _blobToBase64(merged);
        AppLogger.log('WebAudio', '录音完成, base64长度=${_audioBase64?.length ?? 0}');
      }).toJS;

      _recorder!.start();
      _isRecording = true;
      _audioBase64 = null;
      AppLogger.log('WebAudio', '开始录音');
    } catch (e) {
      AppLogger.log('WebAudio', '启动录音失败: $e');
      throw WebRecordingException('无法获取麦克风: $e');
    }
  }

  @override
  Future<String> stopAsBase64() async {
    if (!_isRecording || _recorder == null) {
      throw const WebRecordingException('当前未录音');
    }

    _recorder!.stop();
    // onstop 回调在下一个微任务中执行，等待其完成
    _isRecording = false;
    _stopStream();

    // 最多等待 3 秒让 onstop 回调完成
    for (var i = 0; i < 30; i++) {
      if (_audioBase64 != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    AppLogger.log('WebAudio', '停止录音, base64长度=${_audioBase64?.length ?? 0}');
    return _audioBase64 ?? '';
  }

  @override
  Future<void> cancel() async {
    _isRecording = false;
    _audioBase64 = null;
    _stopStream();
    AppLogger.log('WebAudio', '取消录音');
  }

  @override
  void dispose() {
    cancel();
    AppLogger.log('WebAudio', '释放资源');
  }

  /// 停止所有媒体轨道并清理 Recorder
  void _stopStream() {
    if (_stream != null) {
      // getAudioTracks() 返回 JSArray<MediaStreamTrack>，迭代停止每条轨道
      for (final track in _stream!.getAudioTracks().toDart) {
        track.stop();
      }
      _stream = null;
      _recorder = null;
    }
  }

  /// 将 Blob 同步转换为 Base64 字符串
  ///
  /// 使用 FileReaderSync（仅限主线程，Chrome/Firefox/Safari 均支持）。
  String _blobToBase64(web.Blob blob) {
    final reader = web.FileReaderSync();
    final dataUrl = reader.readAsDataURL(blob);
    // 移除 data:...;base64, 前缀
    final idx = dataUrl.indexOf(';base64,');
    if (idx >= 0) {
      return dataUrl.substring(idx + 8);
    }
    return dataUrl;
  }
}
