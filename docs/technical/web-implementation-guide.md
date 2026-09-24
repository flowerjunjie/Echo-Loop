# Web版实现指南

## 一、关键集成点

### 1.1 在speech_practice_platform.dart中添加Web后端

```dart
// 在现有的speechPracticeBackendProvider中添加
final speechPracticeBackendProvider = Provider<SpeechPracticeBackend>((ref) {
  final s = ref.watch(offlineAsrSettingsProvider);
  final platform = SpeechPracticePlatform.instance;

  if (kIsWeb) {
    // Web平台使用Web后端
    final asrSettings = ref.read(offlineAsrSettingsProvider);
    return WebSpeechPracticeBackend(
      asrService: WebAsrService(),
      ttsService: WebTtsService.instance,
    );
  }

  if (s.isOfflineReady) {
    final engine = ref.read(offlineAsrEngineProvider);
    return OfflineAsrBackend(platform: platform, engine: engine);
  }

  return platform;
});
```

### 1.2 WebSpeechPracticeBackend实现

```dart
// lib/services/web/web_speech_practice_backend.dart
class WebSpeechPracticeBackend implements SpeechPracticeBackend {
  final WebAsrService _asrService;
  final WebTtsService _ttsService;
  WebAudioRecorder? _recorder;
  
  // 实现SpeechPracticeBackend接口方法
  @override
  Future<String> startSession({...}) async {
    // 启动录音
    await _recorder?.start();
    return 'web-recording-${DateTime.now().millisecondsSinceEpoch}';
  }
  
  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    // 停止录音并转录
    final audioBase64 = await _recorder?.stop();
    final result = await _asrService.transcribe(audioBase64: audioBase64!);
    return SpeechPracticeStopResult(filePath: 'web-audio', transcript: result.text);
  }
}
```

## 二、关键注意事项

### 2.1 音频格式
- Web端录音默认格式：WebM/Opus
- 需要转换为后端接受的格式（WAV/MP3）
- 建议使用wav.encode库进行格式转换

### 2.2 权限处理
- 需要用户交互（点击）才能触发录音
- 需要显式请求麦克风权限
- 失败时需要友好提示

### 2.3 浏览器兼容性
- Chrome：完整支持
- Firefox：支持（部分API可能有差异）
- Safari：支持有限（Speech API有webkit前缀）
- Edge：基于Chrome，完整支持

## 三、测试要点

### 3.1 功能测试
```bash
# 启动Web版
flutter run -d chrome

# 测试录音
1. 点击录音按钮
2. 说话
3. 停止录音
4. 验证转录结果

# 测试TTS
1. 点击播放按钮
2. 验证语音播放
```

### 3.2 性能测试
- 首屏加载时间
- 转录响应时间
- 内存使用

## 四、后续优化

### 4.1 PWA增强
- 添加Service Worker
- 实现离线缓存
- 添加安装提示

### 4.2 用户体验
- 添加加载动画
- 优化错误提示
- 添加键盘快捷键

