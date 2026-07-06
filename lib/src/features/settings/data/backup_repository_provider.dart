import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import 'backup_repository.dart';

final backupRepositoryProvider = FutureProvider<BackupRepository>((ref) async {
  final babyLogStore = await ref.watch(babyLogStoreProvider.future);
  final memoryStore = await ref.watch(memoryStoreProvider.future);
  final s3ConfigStore = await ref.watch(s3ConfigStoreProvider.future);
  final babyProfileStore = await ref.watch(babyProfileStoreProvider.future);
  final themeConfigStore = await ref.watch(themeConfigStoreProvider.future);

  return BackupRepository(
    babyLogStore: babyLogStore,
    memoryStore: memoryStore,
    s3ConfigStore: s3ConfigStore,
    babyProfileStore: babyProfileStore,
    themeConfigStore: themeConfigStore,
  );
});
