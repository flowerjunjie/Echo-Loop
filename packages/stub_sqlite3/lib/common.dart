/// Common interfaces for sqlite3 package - for drift compatibility.
library;

/// Common database interface
abstract class CommonDatabase {
  void execute(String sql, [List<dynamic>? args]);
  List<dynamic> select(String sql, [List<dynamic>? args]);
  void dispose();
}

/// Common prepared statement interface
abstract class CommonPreparedStatement {
  void execute([List<dynamic>? args]);
}
