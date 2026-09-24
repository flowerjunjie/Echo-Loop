/// Web 平台合集 Provider
///
/// 使用 [WebDataService] 替代本地 Drift DB，为 Web 端提供合集数据。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/collection.dart';
import '../../services/web_data/web_data_service.dart';

/// Web 版合集列表状态
class WebCollectionState {
  final List<Collection> collections;
  final bool isLoading;
  final String? error;

  const WebCollectionState({
    this.collections = const [],
    this.isLoading = false,
    this.error,
  });

  WebCollectionState copyWith({
    List<Collection>? collections,
    bool? isLoading,
    String? error,
  }) {
    return WebCollectionState(
      collections: collections ?? this.collections,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Web 版合集 Provider
final webCollectionServiceProvider = Provider<WebDataService>((ref) {
  return WebDataService();
});

final webCollectionListProvider = StateNotifierProvider<WebCollectionNotifier, WebCollectionState>((ref) {
  return WebCollectionNotifier(ref);
});

class WebCollectionNotifier extends StateNotifier<WebCollectionState> {
  final Ref _ref;
  WebDataService get _service => _ref.read(webCollectionServiceProvider);

  WebCollectionNotifier(this._ref) : super(const WebCollectionState()) {
    loadCollections();
  }

  Future<void> loadCollections() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final collections = await _service.getCollections();
      state = state.copyWith(collections: collections, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createCollection(String name) async {
    try {
      await _service.createCollection(name: name);
      await loadCollections();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCollection(String collectionId) async {
    try {
      await _service.deleteCollection(collectionId);
      await loadCollections();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
