/// Web本地存储Web实现（浏览器环境）
///
/// 使用浏览器 window.localStorage API，通过 package:web 桥接。
/// 由 [web_storage_service.dart] 在 Web 平台通过条件导入加载。
library;

import 'dart:async';
import 'dart:convert';

import 'package:web/web.dart' as web;

import '../app_logger.dart';

/// 浏览器端Web本地存储实现
class WebStorageService {
  Future<void> set(String key, dynamic value) async {
    try {
      final encoded = jsonEncode(value);
      web.window.localStorage.setItem(key, encoded);
      AppLogger.log('WebStorage', '保存数据: $key (${encoded.length}B)');
    } catch (e) {
      AppLogger.log('WebStorage', '保存失败: $e');
    }
  }

  T? get<T>(String key, [T? defaultValue]) {
    try {
      final raw = web.window.localStorage.getItem(key);
      if (raw == null) return defaultValue;
      return jsonDecode(raw) as T?;
    } catch (e) {
      AppLogger.log('WebStorage', '读取失败: $e');
      return defaultValue;
    }
  }

  Future<void> remove(String key) async {
    try {
      web.window.localStorage.removeItem(key);
      AppLogger.log('WebStorage', '删除数据: $key');
    } catch (e) {
      AppLogger.log('WebStorage', '删除失败: $e');
    }
  }

  Future<void> clear() async {
    try {
      web.window.localStorage.clear();
      AppLogger.log('WebStorage', '清空所有数据');
    } catch (e) {
      AppLogger.log('WebStorage', '清空失败: $e');
    }
  }
}
