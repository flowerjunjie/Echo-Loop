/// 激活码数据统计看板
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../services/activation_stats_service.dart';

class ActivationStatsScreen extends ConsumerStatefulWidget {
  const ActivationStatsScreen({super.key});

  @override
  ConsumerState<ActivationStatsScreen> createState() =>
      _ActivationStatsScreenState();
}

class _ActivationStatsScreenState extends ConsumerState<ActivationStatsScreen> {
  ActivationStats? _stats;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(activationStatsServiceProvider);
      final stats = await service.getStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      AppLogger.log('ActivationStats', 'Load error: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_loading ? Icons.refresh : Icons.refresh),
            onPressed: _loading ? null : _loadStats,
            tooltip: l10n.statsRefresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(theme, l10n)
              : _stats == null
                  ? Center(child: Text(l10n.statsNoData))
                  : _buildBody(theme, l10n),
    );
  }

  Widget _buildErrorView(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadStats, child: Text(l10n.statsRefresh)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l10n) {
    final summary = _stats!.summary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricGrid(theme, l10n, summary),
          const SizedBox(height: 20),
          _buildPeriodBreakdown(theme, l10n),
          const SizedBox(height: 20),
          _buildDailyTrend(theme, l10n),
          const SizedBox(height: 20),
          _buildCreatorStats(theme, l10n),
          const SizedBox(height: 16),
          Text(
            '${l10n.statsLastUpdated} ${_stats!.generatedAt.toLocal().toString().split(' ')[0]}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(ThemeData theme, AppLocalizations l10n, ActivationStatsSummary summary) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(label: l10n.statsTotalCodes, value: '${summary.totalCodes}', subValue: '${summary.totalSeats} ${l10n.statsTotalSeats}', icon: Icons.qr_code, color: const Color(0xFF3B82F6), theme: theme),
        _buildMetricCard(label: l10n.statsUsedCodes, value: '${summary.usedCodes}', subValue: '${summary.usedSeats} ${l10n.statsUsedSeats}', icon: Icons.check_circle, color: const Color(0xFF10B981), theme: theme),
        _buildMetricCard(label: l10n.statsUnusedCodes, value: '${summary.unusedCodes}', subValue: '${summary.unusedSeats} ${l10n.statsUnusedCodes}', icon: Icons.pending, color: const Color(0xFFF59E0B), theme: theme),
        _buildMetricCard(label: l10n.statsRedemptionRate, value: '${summary.redemptionRate}%', subValue: '', icon: Icons.insights, color: const Color(0xFF8B5CF6), theme: theme),
      ],
    );
  }

  Widget _buildMetricCard({required String label, required String value, required String subValue, required IconData icon, required Color color, required ThemeData theme}) {
        return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            if (subValue.isNotEmpty) ...[const SizedBox(height: 4), Text(subValue, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))],
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodBreakdown(ThemeData theme, AppLocalizations l10n) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsPeriodBreakdown, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._stats!.byPeriod.map((p) => _buildPeriodRow(theme, p)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodRow(ThemeData theme, PeriodStats p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_periodLabel(p.period), style: theme.textTheme.bodyMedium),
          Text('${p.used}/${p.total}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildDailyTrend(ThemeData theme, AppLocalizations l10n) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsDailyTrend, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _stats!.dailyStats.length,
                itemBuilder: (context, i) {
                  final stat = _stats!.dailyStats[i];
                  final maxVal = _stats!.dailyStats.map((s) => s.generated + s.activated).reduce((a, b) => a > b ? a : b);
                  final height = maxVal > 0 ? (stat.generated + stat.activated) / maxVal * 100 : 0;
                  return Container(
                    width: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 32,
                          height: height.toDouble(),
                          decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                        ),
                        const SizedBox(height: 4),
                        Text(_formatDate(stat.date), style: theme.textTheme.labelSmall),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorStats(ThemeData theme, AppLocalizations l10n) {
    if (_stats!.byCreator.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsCreatorStats, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._stats!.byCreator.map((c) => ListTile(
              dense: true,
              leading: CircleAvatar(child: Text(c.createdBy[0].toUpperCase())),
              title: Text(c.createdBy),
              trailing: Text('${c.used}/${c.total}'),
            )),
          ],
        ),
      ),
    );
  }

  String _periodLabel(String period) => switch (period) {
    'monthly' => '月卡', 'quarterly' => '季卡', 'halfYearly' => '半年卡', 'yearly' => '年卡', _ => period,
  };

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}';
    } catch (_) {
      return dateStr.substring(5);
    }
  }
}
