import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyPolicy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.privacyPolicy,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(theme, l10n.privacyPolicyLastUpdated, '2026年8月14日'),
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
      l10n.privacyPolicyContent ?? '''
一、信息收集
我们仅收集您自愿提供的信息，包括：
- 邮箱地址（用于登录）
- 音频文件（用于转录）
- 使用数据（用于改进服务）

二、信息使用
收集的信息仅用于：
- 提供和改进服务
- 发送验证码
- 统计分析

三、信息保护
我们采用加密传输和存储保护您的数据。

四、第三方服务
- Supabase：数据存储
- Firebase：崩溃报告
- RevenueCat：订阅管理

五、您的权利
您可以随时删除账号和数据。

六、联系我们
如有问题，请联系：flowerjunjie@163.com
      ''',
      style: theme.textTheme.bodyMedium,
    );
  }
}
