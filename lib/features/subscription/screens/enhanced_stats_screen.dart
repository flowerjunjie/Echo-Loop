/// 增强版统计看板 - 带图表可视化
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../services/activation_stats_service.dart';
import '../services/enhanced_stats_service.dart';

class EnhancedStatsScreen extends ConsumerStatefulWidget {
  const EnhancedStatsScreen({super.key});

  @override
  ConsumerState<EnhancedStatsScreen> createState() =>
      _EnhancedStatsScreenState();
}

class _EnhancedStatsScreenState extends ConsumerState<EnhancedStatsScreen>
    with SingleTickerProviderStateMixin {
  var _basicStats;
  RevenueStats? _revenueStats;
  ActivityStats? _activityStats;
  List<DailyTrend>? _dailyTrends;
  bool _loading = false;
  String? _error;
  int _selectedTab = 0;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(activationStatsServiceProvider);
      final basicStats = await service.getStats();
      
      final enhancedService = ref.read(enhancedStatsServiceProvider);
      final enhancedStats = await enhancedService.getEnhancedStats();
      
      setState(() {
        _basicStats = basicStats.summary;
        _revenueStats = enhancedStats.revenue;
        _activityStats = enhancedStats.activity;
        _dailyTrends = enhancedStats.trend.dailyData;
        _loading = false;
        _controller.forward(from: 0);
      });
    } catch (e) {
      AppLogger.log('EnhancedStats', 'Load error: $e');
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
              : _basicStats == null
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
    return Column(
      children: [
        _buildTabBar(theme, l10n),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildOverviewPage(theme, l10n),
              _buildRevenuePage(theme, l10n),
              _buildTrendPage(theme, l10n),
              _buildActivityPage(theme, l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabItem(0, l10n.statsTitle, Icons.dashboard, theme),
          _buildTabItem(1, '收益分析', Icons.attach_money, theme),
          _buildTabItem(2, l10n.statsDailyTrend, Icons.timeline, theme),
          _buildTabItem(3, '活跃度', Icons.insights, theme),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon, ThemeData theme) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : null),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected ? Colors.white : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewPage(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricGrid(theme, l10n),
          const SizedBox(height: 20),
          if (_revenueStats != null) _buildRevenueOverview(theme, l10n),
          const SizedBox(height: 20),
          if (_dailyTrends != null && _dailyTrends!.isNotEmpty)
            _buildMiniTrendChart(theme, l10n),
          const SizedBox(height: 16),
          Text(
            '${l10n.statsLastUpdated} ${DateTime.now().toLocal().toString().split(' ')[0]}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(ThemeData theme, AppLocalizations l10n) {
    final s = _basicStats!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          label: l10n.statsTotalCodes,
          value: '${s.totalCodes}',
          subValue: '${s.totalSeats} ${l10n.statsTotalSeats}',
          icon: Icons.qr_code,
          color: const Color(0xFF3B82F6),
          theme: theme,
        ),
        _buildMetricCard(
          label: l10n.statsUsedCodes,
          value: '${s.usedCodes}',
          subValue: '${s.usedSeats} ${l10n.statsUsedSeats}',
          icon: Icons.check_circle,
          color: const Color(0xFF10B981),
          theme: theme,
        ),
        _buildMetricCard(
          label: l10n.statsUnusedCodes,
          value: '${s.unusedCodes}',
          subValue: '${s.unusedSeats} ${l10n.statsUnusedCodes}',
          icon: Icons.pending,
          color: const Color(0xFFF59E0B),
          theme: theme,
        ),
        _buildMetricCard(
          label: l10n.statsRedemptionRate,
          value: '${s.redemptionRate}%',
          subValue: '',
          icon: Icons.insights,
          color: const Color(0xFF8B5CF6),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subValue,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    final cs = theme.colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subValue.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subValue,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueOverview(ThemeData theme, AppLocalizations l10n) {
    final r = _revenueStats!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '收益分析',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRevenueItem(
                    theme: theme,
                    label: '已实现收益',
                    value: '¥${r.total}',
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRevenueItem(
                    theme: theme,
                    label: '潜在收益',
                    value: '¥${r.potential}',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: r.total + r.potential > 0
                  ? r.total / (r.total + r.potential)
                  : 0,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '转化率: ${r.total + r.potential > 0 ? ((r.total / (r.total + r.potential)) * 100).toStringAsFixed(1) : '0'}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueItem({
    required ThemeData theme,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTrendChart(ThemeData theme, AppLocalizations l10n) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statsDailyTrend,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _dailyTrends!
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                                e.key.toDouble(),
                                e.value.activated.toDouble(),
                              ))
                          .toList(),
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: _dailyTrends!
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                                e.key.toDouble(),
                                e.value.generated.toDouble(),
                              ))
                          .toList(),
                      isCurved: true,
                      color: const Color(0xFF3B82F6),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  color: const Color(0xFF10B981),
                  label: l10n.statsActivated,
                  theme: theme,
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  color: const Color(0xFF3B82F6),
                  label: l10n.statsGenerated,
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }

  Widget _buildRevenuePage(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_revenueStats != null) _buildRevenueChart(theme),
          const SizedBox(height: 20),
          _buildRevenueBreakdown(theme),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(ThemeData theme) {
    final r = _revenueStats!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '收益分布',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    if (r.total > 0)
                      PieChartSectionData(
                        value: r.total.toDouble(),
                        title: '已实现\n¥${r.total}',
                        color: const Color(0xFF10B981),
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (r.potential > 0)
                      PieChartSectionData(
                        value: r.potential.toDouble(),
                        title: '潜在\n¥${r.potential}',
                        color: const Color(0xFFF59E0B),
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueBreakdown(ThemeData theme) {
    final r = _revenueStats!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '收益明细',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildRevenueRow(
              theme: theme,
              label: '已实现收益',
              value: '¥${r.total}',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
            _buildRevenueRow(
              theme: theme,
              label: '潜在收益',
              value: '¥${r.potential}',
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 8),
            _buildRevenueRow(
              theme: theme,
              label: '总收益',
              value: '¥${r.total + r.potential}',
              color: const Color(0xFF3B82F6),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueRow({
    required ThemeData theme,
    required String label,
    required String value,
    required Color color,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isTotal ? color : null,
            fontWeight: isTotal ? FontWeight.bold : null,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: isTotal ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendPage(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.statsDailyTrend,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: _dailyTrends != null && _dailyTrends!.isNotEmpty
                    ? BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < (_dailyTrends?.length ?? 0)) {
                                    final date = _dailyTrends![index].date;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _formatDate(date),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: _dailyTrends!.asMap().entries.map((e) {
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.generated.toDouble(),
                                  color: const Color(0xFF3B82F6),
                                  width: 16,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                                BarChartRodData(
                                  toY: e.value.activated.toDouble(),
                                  color: const Color(0xFF10B981),
                                  width: 16,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }).toList(),
                          maxY: _dailyTrends != null
                              ? _dailyTrends!
                                  .map((d) => d.generated + d.activated)
                                  .reduce((a, b) => a > b ? a : b)
                                  .toDouble() * 1.2
                              : 10,
                        ),
                      )
                    : const Center(child: Text('暂无数据')),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(color: const Color(0xFF3B82F6), label: l10n.statsGenerated, theme: theme),
                  const SizedBox(width: 24),
                  _buildLegendItem(color: const Color(0xFF10B981), label: l10n.statsActivated, theme: theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityPage(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHourlyChart(theme),
          const SizedBox(height: 20),
          _buildWeeklyChart(theme),
          const SizedBox(height: 20),
          _buildPeakAnalysis(theme),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(ThemeData theme) {
    final activity = _activityStats;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '按小时分布',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: activity != null && activity.byHour.isNotEmpty
                  ? BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() % 4 == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text('${value.toInt()}h', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: activity.byHour.asMap().entries.map((e) {
                          return BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(toY: e.value.toDouble(), color: const Color(0xFF8B5CF6), width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                          ]);
                        }).toList(),
                        maxY: activity.byHour.isNotEmpty ? activity.byHour.reduce((a, b) => a > b ? a : b).toDouble() * 1.2 : 10,
                      ),
                    )
                  : const Center(child: Text('暂无数据')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(ThemeData theme) {
    final activity = _activityStats;
    final days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '按星期分布',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: activity != null && activity.byDay.isNotEmpty
                  ? BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < days.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(days[index], style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: activity.byDay.asMap().entries.map((e) {
                          return BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(toY: e.value.toDouble(), color: const Color(0xFFEC4899), width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                          ]);
                        }).toList(),
                        maxY: activity.byDay.isNotEmpty ? activity.byDay.reduce((a, b) => a > b ? a : b).toDouble() * 1.2 : 10,
                      ),
                    )
                  : const Center(child: Text('暂无数据')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakAnalysis(ThemeData theme) {
    final activity = _activityStats;
    if (activity == null || activity.byHour.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final maxHour = activity.byHour.asMap().entries.reduce((a, b) => a.value > b.value ? a : b);
    final minHour = activity.byHour.asMap().entries.reduce((a, b) => a.value < b.value ? a : b);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '高峰时段分析',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPeakRow(theme: theme, label: '高峰时段', value: '${maxHour.key}:00-${maxHour.key + 1}:00', count: maxHour.value, color: const Color(0xFFEF4444)),
            _buildPeakRow(theme: theme, label: '低谷时段', value: '${minHour.key}:00-${minHour.key + 1}:00', count: minHour.value, color: const Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakRow({
    required ThemeData theme,
    required String label,
    required String value,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
          Text('$value ($count次)', style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}';
    } catch (_) {
      return dateStr.substring(5);
    }
  }
}
