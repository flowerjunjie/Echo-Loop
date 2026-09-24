/// VM stub for package:ffi - transparently re-exports dart:ffi.
/// This package overrides the real 'ffi' package in pubspec.yaml.
library;

import 'dart:ffi';

// Re-export ALL dart:ffi types
export 'dart:ffi';

/// Opaque base class (win32's Utf16 extends Opaque)
abstract class Opaque {}

/// Struct base class (used by win32)
abstract class Struct {}

/// Arena stub
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
