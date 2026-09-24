# 灵犀AI英语听说 Web版开发计划

> 版本：v1.0  
> 创建时间：2026-08-19  
> 预计周期：2-3周

---

## 一、技术选型

### 1.1 Web平台限制
- ❌ sherpa-onnx native FFI不可用
- ❌ Android/iOS原生录音插件不可用
- ✅ Web Audio API可用
- ✅ MediaRecorder API可用
- ✅ Web Speech Recognition API（Chrome）
- ✅ Web Speech Synthesis API
- ✅ IndexedDB本地存储

### 1.2 技术方案

| 功能 | 移动端 | Web端方案 |
|------|--------|-----------|
| 录音 | native plugin | MediaRecorder API |
| ASR | sherpa-onnx离线 | echo-transcribe在线API |
| TTS | kokoro/piper本地 | Web Speech Synthesis |
| 词典 | 多源切换 | WebDictionarySource（已有） |
| 播放 | just_audio | html5 audio + just_audio |
| 离线 | 完整支持 | PWA缓存（有限） |

---

## 二、架构设计

### 2.1 新增文件结构
```
lib/services/web/
├── web_platform.dart           # Web平台检测与适配
├── web_audio_recorder.dart     # Web录音服务
├── web_asr_service.dart        # Web ASR服务
├── web_tts_service.dart        # Web TTS服务
└── web_storage_service.dart    # Web本地存储

lib/widgets/web/
├── web_audio_player.dart       # Web音频播放器
└── web_recording_button.dart   # Web录音按钮
```

### 2.2 平台适配层
```
SpeechPracticeBackend (接口)
├── SpeechPracticePlatform (iOS/macOS)
├── OfflineAsrBackend (Android离线)
└── WebSpeechPracticeBackend (Web) ← 新增
```

---

## 三、开发任务清单

### Phase 1：核心功能（1周）

#### 1.1 Web录音服务
- [ ] `WebAudioRecorder` - 基于MediaRecorder API
- [ ] 支持MP3/WAV格式
- [ ] 音量可视化
- [ ] 静音检测

#### 1.2 Web ASR服务
- [ ] `WebAsrService` - 调用echo-transcribe API
- [ ] 流式转录（可选）
- [ ] 错误处理与重试

#### 1.3 Web TTS服务
- [ ] `WebTtsService` - 基于SpeechSynthesis API
- [ ] 多音色选择
- [ ] 播放控制

#### 1.4 平台适配
- [ ] `WebSpeechPracticeBackend` 实现
- [ ] 录音权限处理
- [ ] 音频上传流程

### Phase 2：UI适配（3-5天）

#### 2.1 响应式布局
- [ ] 桌面端优化（键盘快捷键）
- [ ] 移动端适配（已支持）
- [ ] 横竖屏适配

#### 2.2 Web特有组件
- [ ] Web音频播放器
- [ ] Web录音按钮
- [ ] 实时转录显示

### Phase 3：PWA增强（3-5天）

#### 3.1 PWA配置
- [ ] manifest.json完善
- [ ] Service Worker
- [ ] 离线缓存策略

#### 3.2 高级功能
- [ ] 安装提示
- [ ] 后台同步
- [ ] 推送通知（可选）

---

## 四、关键实现细节

### 4.1 Web录音实现
```dart
// lib/services/web/web_audio_recorder.dart
class WebAudioRecorder implements AudioRecorder {
  MediaRecorder? _recorder;
  Blob? _audioBlob;
  
  Future<void> start() async {
    final stream = await navigator.mediaDevices.getUserMedia(
      {'audio': true}
    );
    _recorder = MediaRecorder(stream);
    _recorder?.start();
  }
  
  Future<void> stop() async {
    _recorder?.stop();
    // 获取Blob并上传
  }
}
```

### 4.2 Web ASR实现
```dart
// lib/services/web/web_asr_service.dart
class WebAsrService implements AsrService {
  final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  
  Future<AsrResult> transcribe(String audioPath) async {
    final file = await File(audioPath).readAsBytes();
    final response = await _dio.post('/api/v1/transcribe', data: file);
    return AsrResult.fromJson(response.data);
  }
}
```

### 4.3 Web TTS实现
```dart
// lib/services/web/web_tts_service.dart
class WebTtsService implements TtsService {
  final speechSynthesis = window.speechSynthesis;
  
  Future<void> speak(String text, {String? voice}) async {
    final utterance = SpeechSynthesisUtterance(text);
    if (voice != null) {
      utterance.voice = speechSynthesis.getVoices()
          .firstWhere((v) => v.name.contains(voice));
    }
    speechSynthesis.speak(utterance);
  }
}
```

---

## 五、部署方案

### 5.1 构建命令
```bash
# 开发模式
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3006

# 生产构建
flutter build web --release --dart-define=API_BASE_URL=http://38.55.146.160:3017
```

### 5.2 部署位置
- 静态文件：`build/web/`
- 服务器：Nginx托管
- CDN：可选（提升访问速度）

---

## 六、风险与应对

| 风险 | 影响 | 应对方案 |
|------|------|----------|
| Chrome不支持某些API | 功能受限 | 降级到基础功能 |
| 网络依赖 | 无网不可用 | PWA缓存关键资源 |
| 录音权限 | 无法录音 | 引导用户授权 |
| 浏览器兼容性 | 部分功能异常 | 主流浏览器测试 |

---

## 七、验收标准

### 7.1 功能验收
- [ ] 网页可正常访问
- [ ] 录音功能正常（Chrome）
- [ ] 转录功能正常
- [ ] 跟读评分正常
- [ ] 词典查询正常
- [ ] TTS播放正常

### 7.2 性能验收
- [ ] 首屏加载 < 3秒
- [ ] 转录响应 < 5秒
- [ ] Lighthouse评分 > 80

### 7.3 兼容性验收
- [ ] Chrome最新版 ✅
- [ ] Safari最新版 ⚠️（Speech API支持有限）
- [ ] Firefox最新版 ✅
- [ ] Edge最新版 ✅

