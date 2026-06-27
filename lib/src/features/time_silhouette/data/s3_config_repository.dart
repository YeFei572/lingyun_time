import '../../../core/storage/local_json_store.dart';
import '../domain/s3_upload_config.dart';

class S3ConfigRepository {
  S3ConfigRepository(this.store);

  final LocalJsonStore store;

  Future<S3UploadConfig> load() async {
    final map = await store.readMap();
    if (map.isEmpty) {
      return const S3UploadConfig();
    }
    return S3UploadConfig.fromJson(map);
  }

  Future<void> save(S3UploadConfig config) async {
    await store.writeMap(config.toJson());
  }
}
