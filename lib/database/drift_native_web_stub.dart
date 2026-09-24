/// Web 平台 drift/native.dart Stub
///
/// 替代 drift/native.dart，避免 FFI 编译错误。
/// Web 平台不提供本地数据库功能，所有构造调用都会抛出 UnsupportedError。
library;

import 'package:drift/drift.dart';

/// Web 平台 NativeDatabase Stub
///
/// 所有构造都会抛出 UnsupportedError，因为 Web 平台不支持本地数据库。
class NativeDatabase implements QueryExecutor {
  /// 构造函数：Web 平台不支持，直接抛出异常
  NativeDatabase(dynamic path) {
    throw UnsupportedError(
        'Local database not supported on web platform.');
  }

  /// 工厂方法：Web 平台不支持，直接抛出异常
  static NativeDatabase createInBackground(dynamic path, {dynamic setup}) {
    throw UnsupportedError('Local database not supported on web platform');
  }

  // QueryExecutor 接口实现（Web 平台不可用）
  @override
  SqlDialect get dialect => throw UnsupportedError('Not available on web');

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => throw UnsupportedError('Not available on web');

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) async => throw UnsupportedError('Not available on web');

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => throw UnsupportedError('Not available on web');

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => throw UnsupportedError('Not available on web');

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => throw UnsupportedError('Not available on web');

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async => throw UnsupportedError('Not available on web');

  @override
  Future<void> runBatched(BatchedStatements statements) async => throw UnsupportedError('Not available on web');

  @override
  TransactionExecutor beginTransaction() => throw UnsupportedError('Not available on web');

  @override
  QueryExecutor beginExclusive() => throw UnsupportedError('Not available on web');

  @override
  Future<void> close() async => throw UnsupportedError('Not available on web');
}
