/// Web 平台 stub：非 Web 环境提供空操作接口。
/// 由 speech_practice_platform.dart 条件导入（if (dart.library.html)）。
library;

/// Stub WebAsrResult —— 非 Web 平台返回空结果。
class WebAsrResult {
  final String text;
  final int durationMs;
  final List<Map<String, dynamic>> sentences;

  const WebAsrResult({this.text = '', this.durationMs = 0, this.sentences = const []});
}

/// Stub WebAsrService —— 非 Web 平台下所有方法返回空结果。
class WebAsrService {
  WebAsrService({dynamic dio, String? token}) {}

  /// 转录音频数据（stub：非 Web 平台不实现）
  Future<WebAsrResult> transcribe({
    required String audioBase64,
    String format = 'webm',
    String language = 'en',
  }) async =>
      const WebAsrResult();

  Future<void> cancel() async {}

  bool get isSupported => false;
}
