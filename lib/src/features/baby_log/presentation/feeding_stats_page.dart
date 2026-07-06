import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/baby_log_entry.dart';

class FeedingStatsPage extends StatefulWidget {
  const FeedingStatsPage({super.key, required this.items});

  final List<BabyLogEntry> items;

  @override
  State<FeedingStatsPage> createState() => _FeedingStatsPageState();
}

class _FeedingStatsPageState extends State<FeedingStatsPage> {
  var _metric = _FeedingMetric.amount;

  @override
  Widget build(BuildContext context) {
    final stats = _buildDailyStats(widget.items);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('吃奶统计')),
      body: stats.isEmpty
          ? const _EmptyStatsHint()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryRow(stats: stats),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_FeedingMetric>(
                    segments: const [
                      ButtonSegment(
                        value: _FeedingMetric.amount,
                        icon: Icon(Icons.water_drop_outlined),
                        label: Text('总奶量'),
                      ),
                      ButtonSegment(
                        value: _FeedingMetric.count,
                        icon: Icon(Icons.format_list_numbered),
                        label: Text('次数'),
                      ),
                    ],
                    selected: {_metric},
                    onSelectionChanged: (value) {
                      setState(() => _metric = value.first);
                    },
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  child: _DailyBarChart(stats: stats, metric: _metric),
                ),
                const SizedBox(height: 16),
                ...stats.reversed.map(
                  (stat) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DailyStatTile(stat: stat),
                  ),
                ),
              ],
            ),
    );
  }

  List<_DailyFeedingStat> _buildDailyStats(List<BabyLogEntry> items) {
    final grouped = <DateTime, List<BabyLogEntry>>{};
    for (final item in items.where((e) => e.isFeeding)) {
      final day = DateTime(item.time.year, item.time.month, item.time.day);
      grouped.putIfAbsent(day, () => <BabyLogEntry>[]).add(item);
    }

    if (grouped.isEmpty) {
      return const [];
    }
    final sortedDays = grouped.keys.toList()..sort();
    final firstDay = sortedDays.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayCount = today.difference(firstDay).inDays + 1;
    final stats = List.generate(dayCount, (index) {
      final day = firstDay.add(Duration(days: index));
      final dayItems = grouped[day] ?? const <BabyLogEntry>[];
      return _DailyFeedingStat(
        day: day,
        totalAmount: dayItems.fold<int>(0, (sum, item) => sum + item.amountMl),
        count: dayItems.length,
      );
    });
    stats.sort((a, b) => a.day.compareTo(b.day));
    return stats;
  }
}

enum _FeedingMetric { amount, count }

class _DailyFeedingStat {
  const _DailyFeedingStat({
    required this.day,
    required this.totalAmount,
    required this.count,
  });

  final DateTime day;
  final int totalAmount;
  final int count;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});

  final List<_DailyFeedingStat> stats;

  @override
  Widget build(BuildContext context) {
    final totalAmount = stats.fold<int>(
      0,
      (sum, stat) => sum + stat.totalAmount,
    );
    final totalCount = stats.fold<int>(0, (sum, stat) => sum + stat.count);
    final avgAmount = stats.isEmpty ? 0 : totalAmount / stats.length;
    final avgCount = stats.isEmpty ? 0 : totalCount / stats.length;

    return Row(
      children: [
        Expanded(child: _StatCard(label: '统计天数', value: '${stats.length} 天')),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(label: '日均奶量', value: '${avgAmount.round()} ml'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: '日均次数',
            value: avgCount.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBarChart extends StatefulWidget {
  const _DailyBarChart({required this.stats, required this.metric});

  final List<_DailyFeedingStat> stats;
  final _FeedingMetric metric;

  @override
  State<_DailyBarChart> createState() => _DailyBarChartState();
}

class _DailyBarChartState extends State<_DailyBarChart> {
  static const _visibleDays = 7;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  @override
  void didUpdateWidget(covariant _DailyBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats.length != widget.stats.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _maxY();
    return SizedBox(
      height: 320,
      child: Row(
        children: [
          SizedBox(width: 46, child: _FixedYAxis(maxY: maxY)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth = constraints.maxWidth / _visibleDays;
                final chartWidth = max(
                  constraints.maxWidth,
                  widget.stats.length * dayWidth,
                );
                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: BarChart(_buildChartData(context, maxY)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  double _maxY() {
    final maxValue = widget.stats
        .map((stat) => _valueOf(stat))
        .fold<double>(0, (maxValue, value) => max(maxValue, value));
    return _niceMaxY(maxValue);
  }

  BarChartData _buildChartData(BuildContext context, double maxY) {
    final scheme = Theme.of(context).colorScheme;
    return BarChartData(
      minY: 0,
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => scheme.inverseSurface,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final stat = widget.stats[group.x.toInt()];
            return BarTooltipItem(
              '${DateFormat('M月d日').format(stat.day)}\n'
              '${_metricLabel(widget.metric)}：${_formatValue(stat)}',
              TextStyle(
                color: scheme.onInverseSurface,
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color: scheme.outlineVariant.withValues(alpha: 0.42),
          strokeWidth: 1,
        ),
        drawVerticalLine: false,
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
            reservedSize: 0,
            interval: maxY / 4,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= widget.stats.length || value != index) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('M/d').format(widget.stats[index].day),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: List.generate(widget.stats.length, (index) {
        final value = _valueOf(widget.stats[index]);
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              width: 18,
              color: scheme.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ],
        );
      }),
    );
  }

  double _valueOf(_DailyFeedingStat stat) {
    return switch (widget.metric) {
      _FeedingMetric.amount => stat.totalAmount.toDouble(),
      _FeedingMetric.count => stat.count.toDouble(),
    };
  }

  double _niceMaxY(double maxValue) {
    if (maxValue <= 0) {
      return widget.metric == _FeedingMetric.amount ? 100 : 4;
    }
    final step = widget.metric == _FeedingMetric.amount ? 100 : 1;
    return max(step * 4, ((maxValue + step) / step).ceil() * step).toDouble();
  }

  String _formatValue(_DailyFeedingStat stat) {
    return switch (widget.metric) {
      _FeedingMetric.amount => '${stat.totalAmount} ml',
      _FeedingMetric.count => '${stat.count} 次',
    };
  }

  String _metricLabel(_FeedingMetric metric) {
    return switch (metric) {
      _FeedingMetric.amount => '总奶量',
      _FeedingMetric.count => '吃奶次数',
    };
  }
}

class _FixedYAxis extends StatelessWidget {
  const _FixedYAxis({required this.maxY});

  final double maxY;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = List.generate(5, (index) => maxY * (4 - index) / 4);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 36, right: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((value) {
          return Text(
            value.toInt().toString(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          );
        }).toList(),
      ),
    );
  }
}

class _DailyStatTile extends StatelessWidget {
  const _DailyStatTile({required this.stat});

  final _DailyFeedingStat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('yyyy年M月d日').format(stat.day),
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${stat.totalAmount} ml',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 14),
          Text(
            '${stat.count} 次',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyStatsHint extends StatelessWidget {
  const _EmptyStatsHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              color: scheme.onSurfaceVariant,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              '还没有吃奶记录',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '新增吃奶记录后，这里会展示每日总奶量和每日吃奶次数。',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
