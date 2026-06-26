import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import 'baby_log_repository.dart';

final babyLogRepositoryProvider = FutureProvider<BabyLogRepository>((ref) async {
  final store = await ref.watch(babyLogStoreProvider.future);
  return BabyLogRepository(store);
});
