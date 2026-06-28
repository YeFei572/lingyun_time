import '../../../core/storage/local_json_store.dart';
import '../domain/baby_profile.dart';

class BabyProfileRepository {
  BabyProfileRepository(this.store);

  final LocalJsonStore store;

  Future<BabyProfile> load() async {
    final map = await store.readMap();
    if (map.isEmpty) {
      return const BabyProfile();
    }
    return BabyProfile.fromJson(map);
  }

  Future<void> save(BabyProfile profile) async {
    await store.writeMap(profile.toJson());
  }
}
