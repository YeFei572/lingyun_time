import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import 'baby_profile_repository.dart';

final babyProfileRepositoryProvider = FutureProvider<BabyProfileRepository>((ref) async {
  final store = await ref.watch(babyProfileStoreProvider.future);
  return BabyProfileRepository(store);
});
