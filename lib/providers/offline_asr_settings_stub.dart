/// Web 平台离线 ASR Settings Stub
///
/// 替代 offline_asr_settings_provider.dart，避免 FFI 编译错误。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web 平台返回 false，禁用离线 ASR 设置
final webOfflineAsrSettingsStateProvider = Provider<bool>((ref) => false);
