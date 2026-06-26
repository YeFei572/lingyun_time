import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppPaths {
  static Future<Directory> dataDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/lingyun_time');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }
}
