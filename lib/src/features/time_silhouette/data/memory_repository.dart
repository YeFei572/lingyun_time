import '../../../core/storage/local_json_store.dart';
import '../../../shared/models/memory_item.dart';

class MemoryRepository {
  MemoryRepository(this.store);

  final LocalJsonStore store;

  Future<List<MemoryItem>> loadAll() async {
    final map = await store.readMap();
    final list = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map>()
        .map((e) => MemoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<void> saveAll(List<MemoryItem> items) async {
    await store.writeMap({
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  String groupKeyFor(DateTime time) => '${time.year}-${time.month.toString().padLeft(2, '0')}';
}
