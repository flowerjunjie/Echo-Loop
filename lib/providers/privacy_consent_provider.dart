/// 隐私同意状态 Provider
///
/// 在 main() 中根据 SharedPreferences 读取的 consent 状态初始化，
/// 供根组件决定是否展示隐私同意弹窗。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 是否需要展示隐私同意弹窗
///
/// 由 [main] 中读取 ConsentManager 结果后注入。
final needsConsentProvider = Provider<bool>((ref) => throw UnimplementedError());
