/// VM stub for dart:ffi - complete interface for win32/drift compatibility.
library;

/// NativeType 抽象基类（所有数值类型必须扩展）
abstract class NativeType {}

/// Utf16 / Utf8 扩展 NativeType（win32 + flutter_local_notifications 要求）
final class Utf16 extends NativeType {}
final class Utf8 extends NativeType {}

/// Opaque 基类（保留，供历史兼容）
@Deprecated('Use NativeType instead')
abstract class Opaque {}

/// Pointer<T> - T extends Object（兼容 win32 Struct 子类 + NativeType 子类）
class Pointer<T extends Object> {
  final int _address;
  const Pointer._(this._address);

  factory Pointer.fromAddress(int address) => Pointer._(address);
  int get address => _address;
  T get value => throw UnsupportedError('not supported');
  set value(T v) => throw UnsupportedError('not supported');
  Pointer<T> operator [](int index) => throw UnsupportedError('not supported');
  @override
  String toString() => 'Pointer<$T>(0x${_address.toRadixString(16)})';
}

/// NativeFunction
abstract class NativeFunction<T extends Function> {}

/// DynamicLibrary - lookupFunction<R,W>(name) 匹配 win32 签名
class DynamicLibrary {
  const DynamicLibrary._();
  static DynamicLibrary get process => const DynamicLibrary._();
  static DynamicLibrary open(String path) =>
      throw UnsupportedError('DynamicLibrary.open not supported: $path');
  NativeFunction lookupFunction<R, W>(String name) =>
      throw UnsupportedError('lookupFunction not supported: $name');
}

/// Arena
class Arena {
  final List<_Block> _blocks = [];
  Pointer<T> allocate<T extends Object>() {
    final b = _Block(); _blocks.add(b);
    return Pointer<T>._(b.addr);
  }
  void free(Pointer p) => _blocks.removeWhere((b) => b.addr == p.address);
  void clear() => _blocks.clear();
}
class _Block { static int _n = 0x1000; int get addr => _n++; }

/// Allocator interface
abstract class Allocator {
  Pointer<T> call<T extends Object>(int count);
}

/// Struct 基类（win32 COMObject 等扩展）
abstract class Struct {}
