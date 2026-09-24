/// 隐私数据收集同意弹窗。
///
/// 首次启动时展示，要求用户明确同意或拒绝数据采集。
/// 同意→ [ConsentManager.grantConsent] 并继续启动；
/// 拒绝→ [ConsentManager.revokeConsent] 并继续启动（AnalyticsService 自动跳过）。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../../../analytics/consent_manager.dart';
import 'privacy_screen.dart';

/// 显示隐私同意弹窗并等待用户选择。
///
/// 返回 true 表示用户同意，false 表示拒绝。
Future<bool> showPrivacyConsentDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _PrivacyConsentDialog(),
  );
  return result ?? false;
}

class _PrivacyConsentDialog extends StatefulWidget {
  const _PrivacyConsentDialog();

  @override
  State<_PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends State<_PrivacyConsentDialog> {
  bool _processing = false;

  Future<void> _handleAccept() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await ConsentManager(prefs).grantConsent();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _handleDeny() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.consentDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.consentDialogContent,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            ),
            icon: const Icon(Icons.privacy_tip, size: 18),
            label: Text(l10n.consentDialogPrivacyLink),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : _handleDeny,
          child: Text(l10n.consentDialogDeny),
        ),
        FilledButton(
          onPressed: _processing ? null : _handleAccept,
          child: _processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.consentDialogAccept),
        ),
      ],
    );
  }
}
