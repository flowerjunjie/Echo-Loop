/// Web平台ASR Stub Providers
///
/// 完全隔离的stub实现，不导入任何FFI依赖。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web平台推荐ASR模型（返回null表示禁用）
final webRecommendedAsrModelProvider = Provider<String?>((ref) => null);

/// Web平台离线ASR设置State（禁用离线ASR）
final webOfflineAsrSettingsStateProvider = Provider<bool>((ref) => false);
