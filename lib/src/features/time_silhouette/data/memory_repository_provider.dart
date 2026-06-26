import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import 'memory_repository.dart';

final memoryRepositoryProvider = FutureProvider<MemoryRepository>((ref) async {
  final store = await ref.watch(memoryStoreProvider.future);
  return MemoryRepository(store);
});
