import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/baby_log_entry.dart';
import '../data/baby_log_repository_provider.dart';

final babyLogControllerProvider =
    AsyncNotifierProvider<BabyLogController, List<BabyLogEntry>>(BabyLogController.new);

class BabyLogController extends AsyncNotifier<List<BabyLogEntry>> {
  @override
  Future<List<BabyLogEntry>> build() async {
    final repo = await ref.watch(babyLogRepositoryProvider.future);
    final loadedItems = await repo.loadAll();
    final validItems = _retainRecentMonth(loadedItems);
    if (_hasListChanged(loadedItems, validItems)) {
      await repo.saveAll(validItems);
    }
    return validItems;
  }

  Future<void> addEntry(BabyLogEntry entry) async {
    final repo = await ref.read(babyLogRepositoryProvider.future);
    final current = [entry, ...(state.valueOrNull ?? <BabyLogEntry>[])];
    final validItems = _retainRecentMonth(current);
    await repo.saveAll(validItems);
    state = AsyncData(validItems);
  }

  Future<void> deleteEntry(String id) async {
    final repo = await ref.read(babyLogRepositoryProvider.future);
    final current = [...(state.valueOrNull ?? <BabyLogEntry>[])];
    current.removeWhere((e) => e.id == id);
    await repo.saveAll(current);
    state = AsyncData(current);
  }

  Future<void> reorderEntries(List<String> orderedIds) async {
    if (orderedIds.length < 2) {
      return;
    }

    // 拖拽排序只调整当前日期分组内传入记录的顺序，日期分组本身仍按真实记录时间排序。
    final repo = await ref.read(babyLogRepositoryProvider.future);
    final orderById = <String, int>{
      for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: orderedIds.length - i,
    };
    final updatedItems = (state.valueOrNull ?? <BabyLogEntry>[]).map((entry) {
      final sortOrder = orderById[entry.id];
      if (sortOrder == null) {
        return entry;
      }
      return entry.copyWith(sortOrder: sortOrder);
    }).toList();

    final validItems = _retainRecentMonth(updatedItems);
    await repo.saveAll(validItems);
    state = AsyncData(validItems);
  }

  Future<String> exportTxt() async {
    final repo = await ref.read(babyLogRepositoryProvider.future);
    return repo.exportTxt(state.valueOrNull ?? const []);
  }

  Future<void> importTxt(String content) async {
    final repo = await ref.read(babyLogRepositoryProvider.future);
    final imported = await repo.importTxt(content);
    final current = [...(state.valueOrNull ?? <BabyLogEntry>[]), ...imported];
    final validItems = _retainRecentMonth(current);
    await repo.saveAll(validItems);
    state = AsyncData(validItems);
  }

  List<BabyLogEntry> _retainRecentMonth(List<BabyLogEntry> items) {
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month - 1,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    final validItems = items.where((e) => !e.time.isBefore(cutoff)).toList();
    validItems.sort(_compareEntries);
    return validItems;
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

  bool _hasListChanged(List<BabyLogEntry> oldItems, List<BabyLogEntry> newItems) {
    if (oldItems.length != newItems.length) {
      return true;
    }
    for (var i = 0; i < oldItems.length; i++) {
      if (oldItems[i].id != newItems[i].id) {
        return true;
      }
    }
    return false;
  }
}
