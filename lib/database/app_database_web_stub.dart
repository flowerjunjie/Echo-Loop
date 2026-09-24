/// Web 平台数据库 Stub
///
/// 替代 app_database.dart，避免 drift/native.dart → sqlite3 → FFI。
/// Web 端不提供本地数据库功能。
///
/// 注意：[appDatabaseProvider] 及相关 DAO Provider 的 Web stub 定义已迁移至
/// [providers_web.dart]（通过 providers.dart 的条件导入使用）。
/// 本文件仅保留 [AppDatabaseStub] 类，供其他需要直接引用该类型的代码使用。
library;

/// Web 平台数据库 Stub（不可用）
class AppDatabaseStub {
  const AppDatabaseStub();

  /// Web 平台返回 false
  bool get isOpen => false;
}
