/// Web 平台 stub：非 Web 环境提供空操作 localStorage 接口。
/// 由 auth_providers.dart 条件导入（if (dart.library.html)）。
/// 目的：避免 package:web 将 dart:js_interop 带入 VM 测试，导致编译失败。
library;

/// Stub window.localStorage —— 非 Web 平台下所有操作静默忽略。
final _stubLocalStorage = _StubLocalStorage();

/// 模拟 Window 对象的 stub，提供 localStorage 和 sessionStorage 访问。
class _StubWindow {
  _StubLocalStorage get localStorage => _stubLocalStorage;
  _StubSessionStorage get sessionStorage => _stubSessionStorage;
}

final _stubSessionStorage = _StubSessionStorage();

/// Stub localStorage，所有操作均为 no-op，getItem 始终返回 null。
class _StubLocalStorage {
  String? getItem(String key) => null;
  void setItem(String key, String value) {}
  void removeItem(String key) {}
  void clear() {}
}

/// Stub sessionStorage，所有操作均为 no-op，getItem 始终返回 null。
/// Web 端 auth session 改用 sessionStorage 存储，此 stub 为非 Web 平台的 no-op 等效。
class _StubSessionStorage {
  String? getItem(String key) => null;
  void setItem(String key, String value) {}
  void removeItem(String key) {}
  void clear() {}
}

/// 暴露 window 对象供 auth_providers.dart 的 web.window.* 调用。
// ignore: non_constant_identifier_names
final window = _StubWindow();
