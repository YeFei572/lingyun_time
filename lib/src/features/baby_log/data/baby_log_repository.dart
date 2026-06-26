import 'dart:convert';

import '../../../core/storage/local_json_store.dart';
import '../../../shared/models/baby_log_entry.dart';

class BabyLogRepository {
  BabyLogRepository(this.store);

  final LocalJsonStore store;

  Future<List<BabyLogEntry>> loadAll() async {
    final map = await store.readMap();
    final list = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map>()
        .map((e) => BabyLogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<void> saveAll(List<BabyLogEntry> items) async {
    await store.writeMap({
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> deleteById(String id) async {
    final items = await loadAll();
    final next = items.where((e) => e.id != id).toList();
    await saveAll(next);
  }

  Future<String> exportTxt(List<BabyLogEntry> items) async {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.writeln(jsonEncode(item.toJson()));
    }
    return buffer.toString();
  }

  Future<List<BabyLogEntry>> importTxt(String content) async {
    final result = <BabyLogEntry>[];
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      result.add(BabyLogEntry.fromJson(jsonDecode(trimmed) as Map<String, dynamic>));
    }
    return result;
  }
}
