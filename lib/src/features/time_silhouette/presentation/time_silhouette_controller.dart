import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';
import '../../../shared/models/memory_item.dart';
import '../data/memory_repository_provider.dart';

final timeSilhouetteControllerProvider =
    AsyncNotifierProvider<TimeSilhouetteController, List<MemoryItem>>(
      TimeSilhouetteController.new,
    );

class TimeSilhouetteController extends AsyncNotifier<List<MemoryItem>> {
  @override
  Future<List<MemoryItem>> build() async {
    final repo = await ref.watch(memoryRepositoryProvider.future);
    final loadedItems = await repo.loadAll();
    await repo.saveAll(loadedItems);
    return loadedItems;
  }

  Future<void> addMemory({
    required String kind,
    required String localPath,
    required String remoteUrl,
    required DateTime createdAt,
    String coverUrl = '',
  }) async {
    final repo = await ref.read(memoryRepositoryProvider.future);
    final current = [...(state.valueOrNull ?? <MemoryItem>[])];
    current.insert(
      0,
      MemoryItem(
        id: IdGenerator.next(),
        kind: kind,
        groupKey: repo.groupKeyFor(createdAt),
        localPath: localPath,
        remoteUrl: remoteUrl,
        createdAt: createdAt,
        coverUrl: coverUrl,
      ),
    );
    await repo.saveAll(current);
    state = AsyncData(current);
  }

  Future<void> deleteMemory(String id) async {
    final repo = await ref.read(memoryRepositoryProvider.future);
    final current = [...(state.valueOrNull ?? <MemoryItem>[])];
    current.removeWhere((item) => item.id == id);
    await repo.saveAll(current);
    state = AsyncData(current);
  }
}
