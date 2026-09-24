/// Web平台离线ASR Provider（stub）
///
/// 使用条件导入隔离FFI依赖：Web端返回默认值，避免编译时引入sherpa-onnx。
library;


// 条件导入：Web使用stub，其他平台使用真实实现
import 'offline_asr_settings_provider.dart'
    if (dart.library.html) 'web_offline_asr_stub_provider.dart';

export 'offline_asr_settings_provider.dart'
    if (dart.library.html) 'web_offline_asr_stub_provider.dart';
