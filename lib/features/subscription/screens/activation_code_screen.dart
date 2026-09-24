/// 激活码兑换页
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/sign_in_required_dialog.dart' show ensureSignedInForAction;
import '../models/entitlement.dart';
import '../models/subscription_plan.dart';
import '../providers/subscription_controller.dart';
import '../services/activation_code_service.dart';

/// 激活码兑换页面。
class ActivationCodeScreen extends ConsumerStatefulWidget {
  const ActivationCodeScreen({super.key});

  @override
  ConsumerState<ActivationCodeScreen> createState() =>
      _ActivationCodeScreenState();
}

class _ActivationCodeScreenState extends ConsumerState<ActivationCodeScreen> {
  final _codeController = TextEditingController();
  bool _activating = false;
  String? _lastResult;
  String? _lastErrorKey;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    if (code.length != 8) {
      setState(() => _lastErrorKey = 'activationCodeLengthError');
      return;
    }
    final identity = ref.read(authSessionProvider);
    if (identity == null) {
      final l10n = AppLocalizations.of(context)!;
      await ensureSignedInForAction(
        context: context,
        ref: ref,
        title: l10n.activationCodeRequired,
        message: l10n.activationSubtitle,
      );
      return;
    }
    setState(() {
      _activating = true;
      _lastResult = null;
      _lastErrorKey = null;
    });
    final service = ref.read(activationCodeServiceProvider);
    final result = await service.activate(
      code: code,
      accessToken: identity.accessToken ?? '',
      userId: identity.userId ?? '',
    );
    setState(() {
      _activating = false;
      if (result.success) {
        _lastResult = result.message;
        _lastErrorKey = null;
        unawaited(ref.read(subscriptionControllerProvider.notifier).refresh());
      } else {
        _lastErrorKey = result.errorMessage;
        _lastResult = null;
      }
    });
    AppLogger.log('Activation', 'activate: success=${result.success} code=$code');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subState = ref.watch(subscriptionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activationTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.activationTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.activationSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              if (subState.isActive && subState.entitlement != null) ...[
                _MemberStatusCard(entitlement: subState.entitlement!),
                const SizedBox(height: 20),
              ],

              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: l10n.activationCodePlaceholder,
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _activate(),
              ),
              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: _activating ? null : _activate,
                icon: _activating
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _activating ? l10n.activationActivating : l10n.activationButton,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_lastResult != null)
                _ResultChip(
                  icon: Icons.check_circle_outline,
                  color: cs.primary,
                  text: l10n.activationSuccess,
                ),
              if (_lastErrorKey != null)
                _ResultChip(
                  icon: Icons.error_outline,
                  color: cs.error,
                  text: l10n.getString(_lastErrorKey!),
                ),
              const SizedBox(height: 28),

              _EnterpriseCard(l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }
}

extension on AppLocalizations {
  String getString(String key) => switch (key) {
    'activationErrorInvalid' => activationErrorInvalid,
    'activationErrorUsed' => activationErrorUsed,
    'activationErrorExpired' => activationErrorExpired,
    'activationErrorNetwork' => activationErrorNetwork,
    'activationCodeLengthError' => activationCodeLengthError,
    _ => key,
  };
}

class _MemberStatusCard extends StatelessWidget {
  const _MemberStatusCard({required this.entitlement});
  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final periodLabel = switch (entitlement.period) {
      SubscriptionPeriod.monthly => '月度会员',
      SubscriptionPeriod.yearly => '年度会员',
      SubscriptionPeriod.lifetime => '终身会员',
      null => '会员',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primaryContainer),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary, shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '兑换成功',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onPrimaryContainer, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$periodLabel · ${entitlement.expiresAt != null ? '至 ${entitlement.expiresAt!.toLocal().toString().split(' ')[0]}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterpriseCard extends StatelessWidget {
  const _EnterpriseCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return OutlinedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l10n.activationEnterpriseBanner),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.activationEnterpriseDesc),
                const SizedBox(height: 12),
                Text('📧 flowerjunjie@163.com', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('💬 微信：15318856182', style: theme.textTheme.bodyMedium),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.activationLearnMore),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.activationEnterpriseContact),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.business),
      label: Text(l10n.activationEnterpriseBanner),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: cs.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
