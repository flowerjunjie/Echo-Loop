/// Web平台本地存储服务
///
/// 基于浏览器 [window.localStorage] 实现，接口与移动端 [StorageService] 对齐。
///
/// **条件导入策略**（[dart.library.html] 路由）：
/// - Flutter test / VM（无 HTML 环境）→ [web_storage_test_stub.dart]（内存Map，可测）
/// - Web 平台（有 HTML 环境）         → [web_storage_web_impl.dart]（真实localStorage）
///
/// 所有调用方统一导入本文件即可，无需感知平台差异。
library;

// ignore: unused_import
import 'web_storage_test_stub.dart'
    if (dart.library.html) 'web_storage_web_impl.dart';

export 'web_storage_test_stub.dart'
    if (dart.library.html) 'web_storage_web_impl.dart';
