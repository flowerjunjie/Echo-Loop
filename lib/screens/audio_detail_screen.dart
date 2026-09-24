/// 音频详情页（Web 端专用）
///
/// 用户从合集详情页点击单个音频时进入此页面。
/// 展示音频基本信息、转录文本和操作按钮。
///
/// **Web 限制**：
/// - 字幕内容通过 `audioItemDaoProvider.getTranscriptSrt()` 加载，Web 端返回 null。
/// - 删除操作直接调用 `audioLibraryProvider` 的 `removeAudioItem`。
/// - 导航使用路由路径字符串，不依赖 `AppRoutes`（避免引入 drift 依赖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../providers/audio_library_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../database/providers.dart';

/// 音频详情页面
///
/// 显示单个音频的名称、时长、转录文本和操作按钮。
/// 从 URL 参数 `id` 获取音频 ID，通过 [audioLibraryProvider] 加载数据。
class AudioDetailScreen extends ConsumerWidget {
  /// 音频 ID，从路由路径参数中传入
  final String audioId;

  const AudioDetailScreen({super.key, required this.audioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 监听音频库变化，确保页面在库加载完成后自动刷新
    ref.watch(audioLibraryProvider);

    // 从内存状态中获取音频条目（Web 端无漂移数据库，直接读 provider）
    final item = ref.read(audioLibraryProvider.notifier).getItemById(audioId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.deleteAudio)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.audio_file_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.noTranscript,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 音频信息卡片 ─────────────────────────────────────────
              _AudioInfoCard(item: item, theme: theme, l10n: l10n),
              const SizedBox(height: AppSpacing.m),

              // ── 转录文本区 ───────────────────────────────────────────
              _TranscriptSection(
                item: item,
                l10n: l10n,
                theme: theme,
              ),
              const SizedBox(height: AppSpacing.m),

              // ── 操作按钮区 ───────────────────────────────────────────
              _ActionButtons(
                item: item,
                l10n: l10n,
                context: context,
                ref: ref,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 子组件 ────────────────────────────────────────────────────────────────────

/// 音频基本信息卡片
class _AudioInfoCard extends StatelessWidget {
  final AudioItem item;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _AudioInfoCard({required this.item, required this.theme, required this.l10n});

  /// 将秒数格式化为 "M:SS" 或 "H:MM:SS"
  static String _formatDurationSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '--:--';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '\$1:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.audio_file,
                    color: const Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.audioDuration(
                          _formatDurationSeconds(item.totalDuration),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 字幕状态徽章
                if (item.hasTranscript)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.sentenceCount} ${l10n.transcript}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
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

/// 转录文本展示区
///
/// Web 端字幕通过 `audioItemDaoProvider.getTranscriptSrt()` 加载，
/// 但由于 Web 数据库 stub 返回 null，此处只显示占位提示。
class _TranscriptSection extends ConsumerWidget {
  final AudioItem item;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _TranscriptSection({
    required this.item,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = theme.colorScheme;

    // 尝试从数据库加载字幕内容（Web 端返回 null）
    return FutureBuilder<String?>(
      future: item.hasTranscript
          ? ref.read(audioItemDaoProvider).getTranscriptSrt(item.id)
          : Future.value(null),
      builder: (context, snapshot) {
        final content = snapshot.data;
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.transcript,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                if (content != null && content.isNotEmpty)
                  SelectableText(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
                  )
                else
                  _TranscriptEmptyState(l10n: l10n, hasTranscript: item.hasTranscript),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 转录空状态
class _TranscriptEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final bool hasTranscript;

  const _TranscriptEmptyState({
    required this.l10n,
    required this.hasTranscript,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Text(
        hasTranscript
            ? l10n.noTranscript
            : l10n.noTranscriptWarning,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 操作按钮区域
class _ActionButtons extends StatelessWidget {
  final AudioItem item;
  final AppLocalizations l10n;
  final BuildContext context;
  final WidgetRef ref;

  const _ActionButtons({
    required this.item,
    required this.l10n,
    required this.context,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 开始学习按钮
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              // 跳转到学习计划页；autoStart=true 允许直接开始播放
              context.push('/audio/${item.id}/plan');
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startLearning),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF3B82F6),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        // 编辑字幕 + 删除按钮（一行两列）
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // 跳转到字幕编辑器
                  context.push('/audio/${item.id}/subtitles/edit');
                },
                icon: const Icon(Icons.edit_note, size: 18),
                label: Text(l10n.editSubtitles),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.deleteAudio),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 显示删除确认对话框，确认后调用 [audioLibraryProvider] 删除音频
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteAudio,
      message: l10n.deleteAudioConfirm(item.name),
      icon: Icons.warning_amber_rounded,
      isDestructive: true,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
    );
    if (confirmed == true) {
      ref.read(audioLibraryProvider.notifier).removeAudioItem(item.id);
      // 删除后返回上一页
      if (context.mounted) {
        context.pop();
      }
    }
  }
}
