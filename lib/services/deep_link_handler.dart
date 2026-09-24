/// Deep Link 处理器（冷启动 + 热启动）
library;

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'app_logger.dart';

/// 解析 deep link 返回的结果
class DeepLinkResult {
  final String? inviteCode;
  final Uri? uri;

  const DeepLinkResult({this.inviteCode, this.uri});
}

/// Deep Link 处理器。
///
/// 使用 [app_links] 处理 `app.echoloop://invite?code=XXX` 格式的 deep link。
/// - 热启动：监听 [appLinksUriStream]，解析每次收到的 URI。
/// - 冷启动：在 [handleInitialLink] 中获取首次启动链接，结果通过 [onLink] 回调。
class DeepLinkHandler {
  DeepLinkHandler({required this.onLink}) : _onLink = onLink;

  /// 收到 deep link 时的回调。
  final ValueChanged<DeepLinkResult> onLink;

  final ValueChanged<DeepLinkResult> _onLink;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// 开始监听 deep link 事件（热启动）。
  void listen() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (e) {
        AppLogger.log('DeepLink', 'stream error: $e');
      },
    );
  }

  /// 处理冷启动 deep link（在 main.dart initState 中调用一次）。
  ///
  /// 返回解析结果，调用方负责将其分发给 UI 层。
  static Future<DeepLinkResult> handleInitialLink() async {
    try {
      final initialLink = await AppLinks().getInitialLink();
      if (initialLink == null) return const DeepLinkResult();
      return _parseInviteUri(initialLink);
    } catch (e) {
      AppLogger.log('DeepLink', 'initialLink error: $e');
      return const DeepLinkResult();
    }
  }

  void _handleUri(Uri uri) {
    final result = _parseInviteUri(uri);
    _onLink(result);
  }

  static DeepLinkResult _parseInviteUri(Uri uri) {
    if (uri.host == 'invite' && uri.queryParameters.containsKey('code')) {
      final code = uri.queryParameters['code']!;
      AppLogger.log('DeepLink', 'invite code: $code');
      return DeepLinkResult(inviteCode: code, uri: uri);
    }
    return DeepLinkResult(uri: uri);
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
