/// 邀请裂变页面
library;

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/invite_provider.dart';
import '../services/invite_service.dart';

/// 邀请裂变页面。
///
/// 展示用户的专属邀请码、邀请进度、各级奖励阶梯，并提供一键分享按钮。
/// Deep link 中的 inviteCode 参数会在进入页面时自动上报归因。
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key, this.inviteCode});

  /// 来自 deep link 的邀请码（分享者携带），用于归因。
  final String? inviteCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final inviteState = ref.watch(inviteStateProvider);
    final identity = ref.watch(authSessionProvider);

    // 上报归因：首次进入时把 deep link 中的 inviteCode 发给后端
    if (inviteCode != null && inviteCode!.isNotEmpty && inviteState.hasData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(inviteServiceProvider).attribution(
          inviteCode: inviteCode!,
          platform: _platformString,
        );
        // 埋点：成功归因
        ref.read(analyticsServiceProvider).track(
          Events.inviteAttributionSuccess,
          {EventParams.referralSource: inviteCode!},
        );
      });
    }

    // 埋点：进入邀请页（区分 deep link 来源和手动进入）
    ref.read(analyticsServiceProvider).track(
      Events.invitePageViewed,
      {
        EventParams.referralSource:
            inviteCode != null && inviteCode!.isNotEmpty ? inviteCode! : 'manual',
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inviteTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: inviteState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, ref, theme, cs, l10n, inviteState, identity),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    AppLocalizations l10n,
    InviteState state,
    dynamic identity,
  ) {
    if (!state.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(state.errorMessage ?? l10n.inviteErrorNetwork,
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.read(inviteStateProvider.notifier).load(),
              child: Text(l10n.statsRefresh),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 邀请码卡片 ──
          _InviteCodeCard(
            code: state.inviteCode,
            l10n: l10n,
            cs: cs,
            theme: theme,
            onCopy: () => _copyCode(context, ref, state.inviteCode, l10n),
            onShare: () => _shareApp(context, ref, l10n, state.inviteCode),
            onCopyLink: () => _copyLink(context, ref, state.inviteCode, l10n),
          ),
          const SizedBox(height: 20),

          // ── 邀请进度（始终展示，0 好友时也显示空状态） ──
          if (state.friendsSignedUp > 0)
            _ProgressCard(
              friendsSignedUp: state.friendsSignedUp,
              monthsEarned: state.monthsEarned,
              l10n: l10n,
              cs: cs,
              theme: theme,
            )
          else
            _EmptyInviteState(l10n: l10n, cs: cs, theme: theme),

          const SizedBox(height: 20),

          // ── 奖励阶梯 ──
          _RewardSteps(l10n: l10n, cs: cs, theme: theme),
          const SizedBox(height: 24),

          // ── 底部操作 ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyCode(context, ref, state.inviteCode, l10n),
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.inviteCopyCode),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _shareApp(context, ref, l10n, state.inviteCode),
                  icon: const Icon(Icons.share),
                  label: Text(l10n.inviteShareApp),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyCode(BuildContext context, WidgetRef ref, String code, AppLocalizations l10n) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.inviteCopied)),
    );
    ref.read(analyticsServiceProvider).track(Events.inviteCopyCode);
    AppLogger.log('Invite', 'copyCode: $code');
  }

  void _copyLink(BuildContext context, WidgetRef ref, String code, AppLocalizations l10n) {
    if (code.isEmpty) return;
    final link = ref.read(inviteServiceProvider).buildInviteLink(code);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.inviteCopied)),
    );
    ref.read(analyticsServiceProvider).track(Events.inviteCopyLink);
    AppLogger.log('Invite', 'copyLink: $link');
  }

  Future<void> _shareApp(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String code,
  ) async {
    final text = ref.read(inviteServiceProvider).buildShareText(code);
    await Share.share(text, subject: '灵犀AI英语听说 - 邀请好友得会员');
    ref.read(analyticsServiceProvider).track(Events.inviteShareTapped);
    AppLogger.log('Invite', 'shareApp: code=$code platform=$_platformString');
  }

  static String get _platformString => Platform.isIOS ? 'ios' : 'android';

}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.code,
    required this.l10n,
    required this.cs,
    required this.theme,
    required this.onCopy,
    required this.onShare,
    required this.onCopyLink,
  });

  final String code;
  final AppLocalizations l10n;
  final ColorScheme cs;
  final ThemeData theme;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A237E), const Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.inviteYourCode,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.onPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    code.isNotEmpty ? code : '---',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                l10n.inviteSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onPrimary.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onCopyLink,
                icon: const Icon(Icons.link, size: 16),
                label: Text(l10n.inviteShareLink,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.9))),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyInviteState extends StatelessWidget {
  const _EmptyInviteState({
    required this.l10n,
    required this.cs,
    required this.theme,
  });

  final AppLocalizations l10n;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            l10n.inviteEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.friendsSignedUp,
    required this.monthsEarned,
    required this.l10n,
    required this.cs,
    required this.theme,
  });

  final int friendsSignedUp;
  final int monthsEarned;
  final AppLocalizations l10n;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary, shape: BoxShape.circle,
            ),
            child: Icon(Icons.people, color: cs.onPrimary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inviteFriendsCount(friendsSignedUp.toString()),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onPrimaryContainer, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (monthsEarned > 0)
                  Text(
                    l10n.inviteMyRewardDetail(monthsEarned.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (monthsEarned > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$monthsEarned月',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onPrimary, fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardSteps extends StatelessWidget {
  const _RewardSteps({required this.l10n, required this.cs, required this.theme});

  final AppLocalizations l10n;
  final ColorScheme cs;
  final ThemeData theme;

  static const _steps = [
    _RewardStep(label: '1人', months: 7, desc: 'inviteRewardMonthly'),
    _RewardStep(label: '3人', months: 30, desc: 'inviteRewardQuarterly'),
    _RewardStep(label: '5人', months: 90, desc: 'inviteRewardHalfYearly'),
    _RewardStep(label: '10人', months: 180, desc: 'inviteRewardYearly'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.inviteMyReward,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._steps.map((step) => _RewardRow(step: step, l10n: l10n, theme: theme)),
      ],
    );
  }
}

class _RewardStep {
  const _RewardStep({
    required this.label,
    required this.months,
    required this.desc,
  });
  final String label;
  final int months;
  final String desc;
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.step, required this.l10n, required this.theme});

  final _RewardStep step;
  final AppLocalizations l10n;
  final ThemeData theme;

  String _getDesc() => switch (step.desc) {
    'inviteRewardMonthly' => l10n.inviteRewardMonthly,
    'inviteRewardQuarterly' => l10n.inviteRewardQuarterly,
    'inviteRewardHalfYearly' => l10n.inviteRewardHalfYearly,
    'inviteRewardYearly' => l10n.inviteRewardYearly,
    _ => step.desc,
  };

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  step.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_getDesc(),
                  style: theme.textTheme.bodyMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${step.months}天',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onPrimary, fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
