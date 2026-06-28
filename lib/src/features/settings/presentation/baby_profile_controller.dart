import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/baby_profile_repository_provider.dart';
import '../domain/baby_profile.dart';

final babyProfileControllerProvider =
    AsyncNotifierProvider<BabyProfileController, BabyProfile>(BabyProfileController.new);

class BabyProfileController extends AsyncNotifier<BabyProfile> {
  @override
  Future<BabyProfile> build() async {
    final repo = await ref.watch(babyProfileRepositoryProvider.future);
    return repo.load();
  }

  Future<void> saveBirthDate(DateTime? birthDate) async {
    final repo = await ref.read(babyProfileRepositoryProvider.future);
    final profile = BabyProfile(birthDate: birthDate);
    await repo.save(profile);
    state = AsyncData(profile);
  }
}
