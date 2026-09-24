/// Web 版首页
///
/// 替代原 LibraryScreen 作为 Web 端初始路由。
/// 在本地数据库不可用时，展示 Web 专属能力入口（跟读、精听、词典），
/// 并保留跳转到已有页面的链接。
///
/// **依赖隔离**：不导入任何 drift/database 符号，仅使用 Web 可用服务。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_providers.dart';
import '../services/web/web_invite_service.dart';
import '../l10n/app_localizations.dart';

/// Web 专属功能卡片数据
class _WebFeatureCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  /// 点击后跳转路由，null 时按钮不可点击
  final String? route;
  _WebFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.route,
  });
}

/// Web 版首页
///
/// 展示三大核心能力入口：
/// - 跟读练习：调用 WebAsrService 进行语音识别跟读
/// - 精听训练：基于播放器的精听模式（待后续接入）
/// - 词典查询：Web 端 AI 词典能力
class WebHomeScreen extends ConsumerWidget {
  WebHomeScreen({super.key});

  /// Web 专属能力卡片列表（按优先级排序）
  static List<_WebFeatureCard> _features = [
    _WebFeatureCard(
      title: '发现精选合集',
      subtitle: '播客 · 托福 · 雅思 · 专四专八，教材',
      icon: Icons.explore,
      accentColor: Color(0xFF22C55E),
      route: '/discover',
    ),
    _WebFeatureCard(
      title: '跟读练习',
      subtitle: '录音 → AI 转录 → 跟读评分',
      icon: Icons.mic,
      accentColor: Color(0xFF3B82F6),
    ),
    _WebFeatureCard(
      title: '精听训练',
      subtitle: '逐句精听 · 智能断句 · 重复巩固',
      icon: Icons.headphones,
      accentColor: Color(0xFF8B5CF6),
    ),
    _WebFeatureCard(
      title: '词典查询',
      subtitle: '选词查词 · AI 解析 · 收藏复习',
      icon: Icons.translate,
      accentColor: Color(0xFFEC4899),
    ),
    _WebFeatureCard(
      title: '收藏复习',
      subtitle: '复习收藏句子 · 单词闪卡',
      icon: Icons.favorite_border,
      accentColor: Color(0xFFFF6B35),
      route: '/favorites',
    ),
    _WebFeatureCard(
      title: '活动日历',
      subtitle: '查看学习统计 · 保持每日打卡',
      icon: Icons.calendar_month,
      accentColor: Color(0xFF06B6D4),
      route: '/activity-calendar',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8),
          child: _LogoTile(),
        ),
        title: Text(l10n.appTitle, style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          Builder(
            builder: (context) {
              final isAuth = ref.watch(isAuthenticatedProvider);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAuth)
                    Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: _UserAvatarChip(loginLabel: l10n.webLoginChip),
                    ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined),
                    tooltip: l10n.settings,
                    onPressed: () => context.push('/playback-settings'),
                  ),
                  IconButton(
                    icon: Icon(Icons.bug_report_outlined),
                    tooltip: l10n.webDevLogs,
                    onPressed: () => context.push('/log-viewer'),
                  ),
                  SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 欢迎区 ────────────────────────────────────────────────
              _WelcomeSection(l10n: l10n, theme: theme),
              SizedBox(height: 24),
              // ── 邀请码区 ──────────────────────────────────────────────
              _InviteSection(l10n: l10n, theme: theme),

              SizedBox(height: 24),

              // ── 功能卡片 ──────────────────────────────────────────────
              Text(
                l10n.webFeaturesTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 12),
              ..._features.map((card) => _FeatureCard(card: card, theme: theme)),

              SizedBox(height: 32),

              // ── 说明区 ────────────────────────────────────────────────
              _InfoSection(l10n: l10n, theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 子组件 ────────────────────────────────────────────────────────────────────

/// 顶部 Logo 小组件
class _LogoTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'L',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// 欢迎区：大标题 + 简短说明
class _WelcomeSection extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  _WelcomeSection({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.webWelcomeTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          l10n.webWelcomeSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 单个功能卡片
class _FeatureCard extends StatelessWidget {
  final _WebFeatureCard card;
  final ThemeData theme;

  _FeatureCard({required this.card, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: card.accentColor.withValues(alpha: 0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: card.route != null ? () => context.push(card.route!) : null,
          splashColor: card.accentColor.withValues(alpha: 0.08),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                // 图标圆角背景
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: card.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    card.icon,
                    color: card.accentColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                // 文字区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        card.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 用户头像芯片
///
/// 显示已登录状态，文本通过 [loginLabel] 注入（避免在无 l10n 上下文中访问）。
class _UserAvatarChip extends StatelessWidget {
  final String loginLabel;
  _UserAvatarChip({required this.loginLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 14, color: Color(0xFF3B82F6)),
          SizedBox(width: 4),
          Text(
            loginLabel,
            style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }
}

/// 底部说明区
class _InfoSection extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  _InfoSection({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Color(0xFFF0F4FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Color(0xFFDBEAFE), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.webInfoNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.warning_amber_outlined, color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.webOfflineAsrNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 邀请码展示区 ────────────────────────────────────────────────────

/// 邀请码展示组件
///
/// 已登录用户可见：展示邀请码 + 一键复制按钮。
/// 未登录用户隐藏此区域。
class _InviteSection extends ConsumerWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  _InviteSection({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(isAuthenticatedProvider);
    if (!isAuth) return SizedBox.shrink();

    final inviteAsync = ref.watch(
    FutureProvider<WebInviteInfo?>((ref) async {
      final service = ref.read(webInviteServiceProvider);
      return service.getInviteInfo();
    }),
  );

    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.webInviteTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 12),
          inviteAsync.when(
            data: (info) {
              if (info == null || info.inviteCode.isEmpty) {
                return _InviteEmptyCard(l10n: l10n, theme: theme);
              }
              return _InviteCodeCard(
                l10n: l10n,
                theme: theme,
                code: info.inviteCode,
                friends: info.friendsSignedUp,
                months: info.monthsEarned,
              );
            },
            loading: () => _InviteLoadingCard(),
            error: (_, __) => _InviteEmptyCard(l10n: l10n, theme: theme),
          ),
        ],
      ),
    );
  }
}

/// 邀请码卡片（已生成）
class _InviteCodeCard extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final String code;
  final int friends;
  final int months;

  _InviteCodeCard({
    required this.l10n,
    required this.theme,
    required this.code,
    required this.friends,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 1,
      color: Color(0xFFF0F4FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Color(0xFFDBEAFE), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${l10n.webInviteFriends(friends)} · ${l10n.webInviteMonths(months)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {},
                icon: Icon(Icons.copy, size: 18),
                label: Text(l10n.webInviteCopy),
                style: FilledButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 邀请码卡片（未生成/加载中）
class _InviteEmptyCard extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  _InviteEmptyCard({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Color(0xFFF8F9FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF6B7280), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.webInvitePending,
                style: theme.textTheme.bodyMedium?.copyWith(color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 邀请码加载骨架
class _InviteLoadingCard extends StatelessWidget {
  _InviteLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Color(0xFFF8F9FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
