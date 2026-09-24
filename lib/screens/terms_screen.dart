import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termsOfService),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.termsOfService,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(theme, l10n.termsLastUpdated, '2026年8月14日'),
            const SizedBox(height: 24),
            _buildContent(theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(date, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildContent(ThemeData theme, AppLocalizations l10n) {
    return Text(
      // ignore: dead_null_aware_expression
      l10n.termsOfServiceContent ?? '''
一、服务说明
灵犀AI英语听说是一款英语学习应用，提供语音识别和转录功能。

二、用户责任
1. 用户应合法使用本服务
2. 不得上传违法或侵权内容
3. 账号安全由用户自行负责

三、服务内容
- 语音转文字
- 字幕生成
- 学习笔记管理

四、服务变更
我们保留随时修改或终止服务的权利。

五、免责声明
我们不保证服务完全无中断或无误。

六、法律适用
本条款受中华人民共和国法律管辖。

七、联系我们
如有问题，请联系：flowerjunjie@163.com
      ''',
      style: theme.textTheme.bodyMedium,
    );
  }
}
