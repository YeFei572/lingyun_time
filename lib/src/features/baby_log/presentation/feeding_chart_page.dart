import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/baby_log_entry.dart';

class FeedingChartPage extends StatelessWidget {
  const FeedingChartPage({
    super.key,
    required this.dayLabel,
    required this.items,
  });

  final String dayLabel;
  final List<BabyLogEntry> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sortedItems = [...items]..sort((a, b) => a.time.compareTo(b.time));
    final totalAmount = sortedItems.fold<int>(0, (sum, item) => sum + item.amountMl);
    final maxAmount = sortedItems.fold<int>(0, (maxValue, item) => max(maxValue, item.amountMl));
    final avgAmount = sortedItems.isEmpty ? 0 : totalAmount / sortedItems.length;

    return Scaffold(
      appBar: AppBar(title: Text('$dayLabel 奶量曲线')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(label: '次数', value: '${sortedItems.length} 次')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(label: '总奶量', value: '$totalAmount ml')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(label: '平均', value: '${avgAmount.round()} ml')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 320,
            padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
            ),
            child: sortedItems.isEmpty
                ? Center(
                    child: Text(
                      '当天没有吃奶记录',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : LineChart(_buildChartData(context, sortedItems, maxAmount)),
          ),
          const SizedBox(height: 16),
          ...sortedItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecordTile(item: item),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(
    BuildContext context,
    List<BabyLogEntry> sortedItems,
    int maxAmount,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final spots = sortedItems.map((item) {
      final x = item.time.hour + item.time.minute / 60 + item.time.second / 3600;
      return FlSpot(x, item.amountMl.toDouble());
    }).toList();
    final maxY = max(60, ((maxAmount + 40) / 20).ceil() * 20).toDouble();

    return LineChartData(
      minX: 0,
      maxX: 24,
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final hour = spot.x.floor();
              final minute = ((spot.x - hour) * 60).round();
              return LineTooltipItem(
                '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}\n${spot.y.toInt()} ml',
                TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
              );
            }).toList();
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        horizontalInterval: max(20.0, maxY / 4),
        verticalInterval: 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (_) => FlLine(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.75)),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: max(20.0, maxY / 4),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 4,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              if (value < 0 || value > 24) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${value.toInt().toString().padLeft(2, '0')}:00',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: scheme.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: scheme.primary.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

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
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.item});

  final BabyLogEntry item;

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
          Icon(Icons.local_cafe, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              DateFormat('HH:mm').format(item.time),
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
          Text('${item.amountMl} ml', style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
