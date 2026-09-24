/// 数据库工厂
///
/// Web 平台返回 null（不提供本地数据库）。
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web 平台数据库连接（null = 不可用）
final databaseConnectionProvider = Provider.autoDispose<dynamic>((ref) {
  if (kIsWeb) return null;
  // 非 Web 平台：返回 NativeDatabase
  // 实际实现由 app_database.dart 提供
  return null;
});
