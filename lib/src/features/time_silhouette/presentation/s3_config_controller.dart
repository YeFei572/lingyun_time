import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/s3_config_repository_provider.dart';
import '../domain/s3_upload_config.dart';

final s3ConfigControllerProvider =
    AsyncNotifierProvider<S3ConfigController, S3UploadConfig>(S3ConfigController.new);

class S3ConfigController extends AsyncNotifier<S3UploadConfig> {
  @override
  Future<S3UploadConfig> build() async {
    final repo = await ref.watch(s3ConfigRepositoryProvider.future);
    return repo.load();
  }

  Future<void> saveConfig(S3UploadConfig config) async {
    final repo = await ref.read(s3ConfigRepositoryProvider.future);
    await repo.save(config);
    state = AsyncData(config);
  }
}
