/// Common interfaces for sqlite3 package - for drift compatibility.
library;

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
