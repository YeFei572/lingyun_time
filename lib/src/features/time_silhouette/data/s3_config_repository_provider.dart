import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import 's3_config_repository.dart';

final s3ConfigRepositoryProvider = FutureProvider<S3ConfigRepository>((ref) async {
  final store = await ref.watch(s3ConfigStoreProvider.future);
  return S3ConfigRepository(store);
});
