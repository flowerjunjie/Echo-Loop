/// Web本地存储测试Stub（VM环境）
///
/// 使用内存Map实现，供 [flutter_test] 运行时无需浏览器即可验证读写逻辑。
/// 由 [web_storage_service.dart] 在 VM 环境下通过条件导入加载。
library;

import 'dart:async';
import 'dart:convert';

/// VM测试用Web本地存储实现（内存map）
class WebStorageService {
  final Map<String, String> _store;

  /// 构造新实例，可选传入初始数据
  WebStorageService([Map<String, String>? initialStore])
      : _store = Map.from(initialStore ?? {});

  /// 保存数据到内存（测试环境无条件写入）
  Future<void> set(String key, dynamic value) async {
    try {
      final encoded = jsonEncode(value);
      _store[key] = encoded;
    } catch (e) {
      // 序列化失败静默忽略
    }
  }

  /// 从内存读取数据并反序列化
  T? get<T>(String key, [T? defaultValue]) {
    final raw = _store[key];
    if (raw == null) return defaultValue;
    try {
      return jsonDecode(raw) as T?;
    } catch (_) {
      return defaultValue;
    }
  }

  /// 删除数据
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  /// 清空所有数据
  Future<void> clear() async {
    _store.clear();
  }
}
