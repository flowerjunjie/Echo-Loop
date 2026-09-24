/// Web 平台 stub：非 Web 环境提供空操作接口。
/// 由 speech_practice_platform.dart 条件导入（if (dart.library.html)）。
library;

import 'dart:async';

/// Web 音频录制接口 stub。
///
/// 非 Web 平台下所有方法均为 no-op，防止编译失败。
abstract class WebAudioRecorder {
  bool get isSupported => false;
  Future<void> start() async {}
  Future<void> stop() async {}
  Future<String> stopAsBase64() async => '';
  Future<void> cancel() async {}
  void onCancel(void Function() callback) {}
  void onData(void Function(List<int>) callback) {}
}

/// WebAudioRecorder 的具体实现 stub。
///
/// 非 Web 平台使用时所有操作静默忽略，start/stop/cancel 均返回空。
class WebAudioRecorderImpl implements WebAudioRecorder {
  @override
  bool get isSupported => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<String> stopAsBase64() async => '';

  @override
  Future<void> cancel() async {}

  @override
  void onCancel(void Function() callback) {}

  @override
  void onData(void Function(List<int>) callback) {}
}
