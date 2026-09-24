/// Web 版设置占位页面
///
/// Web 端 `/settings` 路径由登录流程等调用（如 [EmailSignInScreen._finishAuthAttempt]），
/// 但 Web 暂无独立设置页。此页面自动重定向到首页，避免 404。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


/// Web 版设置占位页面 — 自动跳转首页
class WebSettingsScreen extends StatefulWidget {
  const WebSettingsScreen({super.key});

  @override
  State<WebSettingsScreen> createState() => _WebSettingsScreenState();
}

class _WebSettingsScreenState extends State<WebSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟一帧后跳转，避免路由冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(WebRoutes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Web 路由常量，避免循环依赖
abstract class WebRoutes {
  static const home = '/';
  static const login = '/login';
  static const invite = '/invite/:code';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const playbackSettings = '/playback-settings';
  static const logViewer = '/log-viewer';
  static const asrTest = '/asr-test';
  static const settings = '/settings';
}
