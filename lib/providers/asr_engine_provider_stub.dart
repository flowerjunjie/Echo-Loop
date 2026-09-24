/// Web 平台 ASR 引擎 Stub Provider
///
/// 替代 asr_engine_provider.dart，避免 FFI 编译错误。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web 平台 ASR 模型管理器（空实现）
class AsrModelManagerWebStub {
  Future<String> modelDir(String modelId) async => '';
  Future<int> modelLocalSize(String modelId) async => 0;
  Future<bool> isModelDownloaded(String modelId) async => false;
  Future<void> deleteModel(String modelId) async {}
  Future<void> downloadModel(String modelId, {Object? cancelToken}) async {}
  void dispose() {}
}

/// Web 平台离线 ASR 引擎（空实现）
class OfflineAsrEngineWebStub {
  Future<void> initialize(String modelId, {String? vadPath}) async {}
  Future<void> dispose() async {}
}

/// Web 平台 ASR 模型信息（空）
class AsrModelInfoWebStub {
  final String id;
  final String displayName;
  const AsrModelInfoWebStub({required this.id, required this.displayName});
}

/// Web 平台 Provider（返回 stub 实例）
final asrModelManagerProvider = Provider<AsrModelManagerWebStub>((ref) => AsrModelManagerWebStub());
final offlineAsrEngineProvider = Provider<OfflineAsrEngineWebStub?>((ref) => null);
final availableAsrModelsProvider = Provider<List<AsrModelInfoWebStub>>((ref) => const []);
