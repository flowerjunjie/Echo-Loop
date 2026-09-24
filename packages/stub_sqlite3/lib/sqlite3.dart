/// VM stub for sqlite3 - complete interface for drift compatibility.
library;

import 'common.dart';
import 'dart:convert';
import 'dart:typed_data';

/// 数据库打开模式
enum OpenMode { readOnly, readWrite, create }

/// Sqlite3 异常 - drift 要求
class SqliteException implements Exception {
  final String message;
  const SqliteException([this.message = 'sqlite error']);
  @override
  String toString() => 'SqliteException: $message';
}

/// Sqlite3 类型别名 - drift 要求
typedef Sqlite3 = Database;

/// PreparedStatement stub - 实现 CommonPreparedStatement
class PreparedStatement implements CommonPreparedStatement {
  final String sql;
  PreparedStatement._(this.sql);
  @override
  void execute([List<dynamic>? args]) {}
  List<dynamic> select([List<dynamic>? args]) => [];
  void close() {}
}

/// 数据库类 - 完整接口兼容 drift + CommonDatabase
class Database implements CommonDatabase {
  Database(String path, [OpenMode mode = OpenMode.readWrite]);

  @override
  void execute(String sql, [List<dynamic>? args]) {}
  @override
  List<dynamic> select(String sql, [List<dynamic>? args]) => [];
  @override
  void dispose() {}

  int get lastInsertRowId => 0;
  int get updatedRows => 0;
  PreparedStatement prepare(String sql) => PreparedStatement._(sql);
}

/// sqlite3 全局实例 - 实现 CommonDatabase + open/openInMemory
final sqlite3 = _Sqlite3();

/// _Sqlite3 实现 CommonDatabase 接口
class _Sqlite3 implements CommonDatabase {
  @override
  void execute(String sql, [List<dynamic>? args]) {}
  @override
  List<dynamic> select(String sql, [List<dynamic>? args]) => [];
  @override
  void dispose() {}

  Database open(String path, {OpenMode mode = OpenMode.readWrite}) =>
      Database(path, mode);
  Database openInMemory() => Database(':memory:');
}

/// Jsonb Codec - drift 要求
class JsonbCodec extends Codec<Object?, Uint8List> {
  const JsonbCodec();
  @override
  Converter<Object?, Uint8List> get encoder => const _JsonEncoder();
  @override
  Converter<Uint8List, Object?> get decoder => const _JsonDecoder();
}

class _JsonEncoder extends Converter<Object?, Uint8List> {
  const _JsonEncoder();
  @override
  Uint8List convert(Object? input) => Uint8List.fromList(utf8.encode(jsonEncode(input)));
}

class _JsonDecoder extends Converter<Uint8List, Object?> {
  const _JsonDecoder();
  @override
  Object? convert(Uint8List input) => jsonDecode(utf8.decode(input));
}

/// 顶层 jsonb 常量
const jsonb = JsonbCodec();
/// sqlite3.jsonb 别名
const sqlite3Jsonb = JsonbCodec();
