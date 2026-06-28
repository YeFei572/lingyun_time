import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/baby_log_entry.dart';
import '../../settings/presentation/baby_profile_controller.dart';
import 'baby_log_controller.dart';
import 'feeding_chart_page.dart';

class BabyLogPage extends ConsumerStatefulWidget {
  const BabyLogPage({super.key});

  @override
  ConsumerState<BabyLogPage> createState() => _BabyLogPageState();
}

class _BabyLogPageState extends ConsumerState<BabyLogPage> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(babyLogControllerProvider);
    final babyProfileState = ref.watch(babyProfileControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('婴儿行为记录'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF171F2A) : const Color(0xFFF4ECE7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark ? const Color(0xFF263242) : const Color(0xFFE5D6CD),
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF263447) : const Color(0xFFE8CFC3),
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: isDark ? const Color(0xFFF1F4F8) : const Color(0xFF5B392B),
                unselectedLabelColor: scheme.onSurfaceVariant,
                splashBorderRadius: BorderRadius.circular(999),
                tabs: const [
                  Tab(text: '吃奶'),
                  Tab(text: '小便'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: state.when(
        data: (items) {
          final feedItems = items.where((e) => e.isFeeding).toList();
          final urineItems = items.where((e) => e.isUrination).toList();
          final birthDate = babyProfileState.maybeWhen(
            data: (profile) => profile.birthDate,
            orElse: () => null,
          );

          return TabBarView(
            controller: _tabController,
            children: [
              _LogList(
                items: feedItems,
                recordKind: 'feeding',
                birthDate: birthDate,
                showChartButton: true,
              ),
              _LogList(
                items: urineItems,
                recordKind: 'urination',
                birthDate: birthDate,
                showChartButton: false,
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text('加载失败：$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final type = _tabController.index == 0 ? '吃奶' : '小便';
          _showEntrySheet(context, ref, defaultType: type);
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEntrySheet(
    BuildContext context,
    WidgetRef ref, {
    required String defaultType,
  }) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedType = defaultType;
    final now = DateTime.now();
    var selectedTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final sheetScheme = Theme.of(context).colorScheme;
        final sheetIsDark = Theme.of(context).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: sheetIsDark ? const Color(0xFF141A22) : sheetScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: sheetScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '新增记录',
                      style: TextStyle(
                        color: sheetScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('类型'),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('吃奶'),
                                selected: selectedType == '吃奶',
                                onSelected: (_) => setState(() => selectedType = '吃奶'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('小便'),
                                selected: selectedType == '小便',
                                onSelected: (_) => setState(() => selectedType = '小便'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('记录时间'),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return _TimePickerTile(
                          selectedTime: selectedTime,
                          onTap: () async {
                            final nextTime = await _pickRecordTime(context, selectedTime);
                            if (nextTime == null) {
                              return;
                            }
                            setState(() => selectedTime = nextTime);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(selectedType == '吃奶' ? '奶量（ml）' : '次数/描述'),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: selectedType == '吃奶' ? '例如 120' : '例如 正常',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('备注'),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '记录一些状态、情况或补充说明',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              ref.read(babyLogControllerProvider.notifier).addEntry(
                                    BabyLogEntry(
                                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                                      type: selectedType,
                                      time: selectedTime,
                                      amountMl: int.tryParse(amountController.text.trim()) ?? 0,
                                      note: noteController.text.trim(),
                                    ),
                                  );
                              Navigator.pop(context);
                            },
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<DateTime?> _pickRecordTime(BuildContext context, DateTime initialTime) async {
    var selectedHour = initialTime.hour;
    var selectedMinute = initialTime.minute;

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('选择记录时间'),
              content: Row(
                children: [
                  Expanded(
                    child: _TimePartDropdown(
                      label: '时',
                      value: selectedHour,
                      maxValue: 23,
                      onChanged: (value) => setState(() => selectedHour = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TimePartDropdown(
                      label: '分',
                      value: selectedMinute,
                      maxValue: 59,
                      onChanged: (value) => setState(() => selectedMinute = value),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      DateTime(
                        initialTime.year,
                        initialTime.month,
                        initialTime.day,
                        selectedHour,
                        selectedMinute,
                      ),
                    );
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimePartDropdown extends StatelessWidget {
  const _TimePartDropdown({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int maxValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      menuMaxHeight: 280,
      decoration: InputDecoration(labelText: label),
      items: List.generate(maxValue + 1, (index) {
        return DropdownMenuItem<int>(
          value: index,
          child: Text(index.toString().padLeft(2, '0')),
        );
      }),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        onChanged(value);
      },
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.selectedTime,
    required this.onTap,
  });

  final DateTime selectedTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('HH:mm').format(selectedTime),
                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.items,
    required this.recordKind,
    required this.birthDate,
    required this.showChartButton,
  });

  final List<BabyLogEntry> items;
  final String recordKind;
  final DateTime? birthDate;
  final bool showChartButton;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay(items);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (groups.isEmpty)
          const _EmptyHint()
        else
          ...groups.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DailyLogGroup(
                  group: group,
                  recordKind: recordKind,
                  birthDate: birthDate,
                  showChartButton: showChartButton,
                ),
              )),
        const SizedBox(height: 80),
      ],
    );
  }

  List<_DailyLogGroupData> _groupByDay(List<BabyLogEntry> sourceItems) {
    final sortedItems = [...sourceItems]..sort(_compareEntries);
    final groupMap = <String, List<BabyLogEntry>>{};

    for (final item in sortedItems) {
      final key = DateFormat('yyyy-MM-dd').format(item.time);
      groupMap.putIfAbsent(key, () => <BabyLogEntry>[]).add(item);
    }

    return groupMap.entries.map((entry) {
      return _DailyLogGroupData(
        dayKey: entry.key,
        label: _formatDayLabel(entry.value.first.time),
        items: entry.value,
      );
    }).toList();
  }

  String _formatDayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay = DateTime(time.year, time.month, time.day);
    if (recordDay == today) {
      return '今天';
    }
    if (recordDay == today.subtract(const Duration(days: 1))) {
      return '昨天';
    }
    return DateFormat('yyyy年MM月dd日').format(time);
  }

  int _compareEntries(BabyLogEntry a, BabyLogEntry b) {
    final dayCompare = _dateOnly(b.time).compareTo(_dateOnly(a.time));
    if (dayCompare != 0) {
      return dayCompare;
    }

    final sortCompare = b.sortOrder.compareTo(a.sortOrder);
    if (sortCompare != 0) {
      return sortCompare;
    }

    return b.time.compareTo(a.time);
  }

  DateTime _dateOnly(DateTime time) {
    return DateTime(time.year, time.month, time.day);
  }
}

class _DailyLogGroupData {
  const _DailyLogGroupData({
    required this.dayKey,
    required this.label,
    required this.items,
  });

  final String dayKey;
  final String label;
  final List<BabyLogEntry> items;
}

class _DailyLogGroup extends ConsumerStatefulWidget {
  const _DailyLogGroup({
    required this.group,
    required this.recordKind,
    required this.birthDate,
    required this.showChartButton,
  });

  final _DailyLogGroupData group;
  final String recordKind;
  final DateTime? birthDate;
  final bool showChartButton;

  @override
  ConsumerState<_DailyLogGroup> createState() => _DailyLogGroupState();
}

class _DailyLogGroupState extends ConsumerState<_DailyLogGroup> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // 内层拖拽列表不需要保存滚动位置；关闭 PageStorage 写入，避免和 ExpansionTile 的折叠状态冲突。
    _scrollController = ScrollController(keepScrollOffset: false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('${widget.recordKind}-${widget.group.dayKey}'),
          initiallyExpanded: true,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: scheme.onSurfaceVariant,
          collapsedIconColor: scheme.onSurfaceVariant,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _buildTitleText(),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.showChartButton)
                IconButton(
                  tooltip: '奶量曲线',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FeedingChartPage(
                          dayLabel: widget.group.label,
                          items: widget.group.items,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.show_chart, color: scheme.primary),
                ),
            ],
          ),
          backgroundColor: isDark ? const Color(0xFF171E27) : Colors.white,
          collapsedBackgroundColor: isDark ? const Color(0xFF171E27) : Colors.white,
          children: [
            ReorderableListView.builder(
              key: ValueKey('reorderable-${widget.recordKind}-${widget.group.dayKey}'),
              scrollController: _scrollController,
              primary: false,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.02).animate(animation),
                    child: child,
                  ),
                );
              },
              itemCount: widget.group.items.length,
              onReorder: (oldIndex, newIndex) {
                final reorderedItems = [...widget.group.items];
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = reorderedItems.removeAt(oldIndex);
                reorderedItems.insert(newIndex, item);
                ref.read(babyLogControllerProvider.notifier).reorderEntries(
                      reorderedItems.map((e) => e.id).toList(),
                    );
              },
              itemBuilder: (context, index) {
                final entry = widget.group.items[index];
                return Padding(
                  key: ValueKey(entry.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LogTile(entry: entry, dragIndex: index),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _buildTitleText() {
    final base = '${widget.group.label} · ${widget.group.items.length} 条';
    if (widget.recordKind != 'feeding') {
      return base;
    }

    final totalMl = widget.group.items
        .where((item) => item.isFeeding)
        .fold<int>(0, (sum, item) => sum + item.amountMl);
    if (totalMl <= 0) {
      return base;
    }

    return '$base · ${totalMl} ml';
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171F2A) : const Color(0xFFF4ECE7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF263242) : const Color(0xFFE5D6CD)),
      ),
      child: Text(
        '这里还没有记录，点右下角新增一条吧。',
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({
    required this.entry,
    required this.dragIndex,
  });

  final BabyLogEntry entry;
  final int dragIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2430) : const Color(0xFFFFFCFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF263242) : const Color(0xFFF0E2DA),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.isFeeding
              ? (isDark ? const Color(0xFF2B394A) : const Color(0xFFE8CFC3))
              : (isDark ? const Color(0xFF313342) : const Color(0xFFE7DCC6)),
          child: entry.isFeeding
              ? HugeIcon(
                  icon: HugeIcons.strokeRoundedBabyBottle,
                  color: isDark ? const Color(0xFFE7EAF0) : const Color(0xFF5B392B),
                  size: 23,
                )
              : Icon(
                  HugeIcons.strokeRoundedDiaper,
                  color: isDark ? const Color(0xFFE7EAF0) : const Color(0xFF5B392B),
                  size: 23,
                ),
        ),
        title: Text(entry.isFeeding ? '吃奶 · ${entry.amountMl} ml' : '小便'),
        subtitle: Text(
          _formatRelativeTime(entry.time),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: '拖拽排序',
              child: ReorderableDragStartListener(
                index: dragIndex,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(Icons.drag_handle, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => ref.read(babyLogControllerProvider.notifier).deleteEntry(entry.id),
              icon: const Icon(HugeIcons.strokeRoundedDelete03),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay = DateTime(time.year, time.month, time.day);
    if (recordDay != today) {
      return DateFormat('HH:mm').format(time);
    }

    final diff = now.difference(time);
    if (diff.isNegative) {
      return '刚刚';
    }
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours == 0 && minutes == 0) {
      return '刚刚';
    }
    if (hours == 0) {
      return '$minutes分钟前';
    }
    if (minutes == 0) {
      return '$hours小时前';
    }
    return '$hours小时$minutes分前';
  }
}
