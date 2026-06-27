import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_paths.dart';
import 'local_json_store.dart';

final appDirectoryProvider = FutureProvider<Directory>((ref) async {
  return AppPaths.dataDir();
});

final babyLogStoreProvider = FutureProvider<LocalJsonStore>((ref) async {
  final dir = await ref.watch(appDirectoryProvider.future);
  return LocalJsonStore(File('${dir.path}/baby_logs.json'));
});

final memoryStoreProvider = FutureProvider<LocalJsonStore>((ref) async {
  final dir = await ref.watch(appDirectoryProvider.future);
  return LocalJsonStore(File('${dir.path}/memories.json'));
});

final s3ConfigStoreProvider = FutureProvider<LocalJsonStore>((ref) async {
  final dir = await ref.watch(appDirectoryProvider.future);
  return LocalJsonStore(File('${dir.path}/s3_config.json'));
});
