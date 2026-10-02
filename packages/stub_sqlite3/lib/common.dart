/// Common interfaces for sqlite3 package - for drift compatibility.
library;

// drift 2.28 经 `import 'package:sqlite3/common.dart' show jsonb` 取 Jsonb 编解码器。
// jsonb 常量定义在 sqlite3.dart，重导出到公共接口文件供 drift 直接引用。
export 'sqlite3.dart' show jsonb, sqlite3Jsonb;

/// Common database interface
abstract class CommonDatabase {
  void execute(String sql, [List<dynamic>? args]);
  List<dynamic> select(String sql, [List<dynamic>? args]);
  void dispose();
}

/// 预编译语句接口（drift 2.28 需要 dispose）
abstract class CommonPreparedStatement {
  void execute([List<dynamic>? args]);

  /// 释放预编译语句（drift 2.28 调用）
  void dispose();
}
