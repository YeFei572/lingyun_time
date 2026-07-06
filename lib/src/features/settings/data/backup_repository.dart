import 'dart:convert';

import '../../../core/storage/local_json_store.dart';
import '../../../shared/models/baby_log_entry.dart';
import '../../../shared/models/memory_item.dart';

class BackupRepository {
  BackupRepository({
    required this.babyLogStore,
    required this.memoryStore,
    required this.s3ConfigStore,
    required this.babyProfileStore,
    required this.themeConfigStore,
  });

  final LocalJsonStore babyLogStore;
  final LocalJsonStore memoryStore;
  final LocalJsonStore s3ConfigStore;
  final LocalJsonStore babyProfileStore;
  final LocalJsonStore themeConfigStore;

  static const _backupVersion = 1;
  static const _appName = 'lingyun_time';
  static const _babyLogStoreName = 'baby_logs.json';
  static const _memoryStoreName = 'memories.json';
  static const _s3ConfigStoreName = 's3_config.json';
  static const _babyProfileStoreName = 'baby_profile.json';
  static const _themeConfigStoreName = 'theme_config.json';

  Future<String> exportTxt() async {
    final backupMap = <String, dynamic>{
      'app': _appName,
      'backupVersion': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      // stores 中保存当前应用所有本地 JSON 存储内容，后续新增本地 store 时只需要扩展这里。
      'stores': {
        _babyLogStoreName: _normalizeBabyLogStoreMap(
          await babyLogStore.readMap(),
        ),
        _memoryStoreName: _normalizeMemoryStoreMap(await memoryStore.readMap()),
        _s3ConfigStoreName: await s3ConfigStore.readMap(),
        _babyProfileStoreName: await babyProfileStore.readMap(),
        _themeConfigStoreName: await themeConfigStore.readMap(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  Future<void> importTxt(String content) async {
    final trimmed = content.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (trimmed.isEmpty) {
      throw const BackupException('备份文件内容为空');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      await _importLegacyBabyLogs(trimmed);
      return;
    }

    if (decoded is Map && decoded['stores'] is Map) {
      await _importFullBackup(Map<String, dynamic>.from(decoded));
      return;
    }

    // 兼容旧版逐行 JSON 行为记录备份，避免用户之前导出的旧数据无法恢复。
    await _importLegacyBabyLogs(trimmed);
  }

  Future<void> _importFullBackup(Map<String, dynamic> backupMap) async {
    if (backupMap['app'] != _appName) {
      throw const BackupException('备份文件不是凌云时光的数据');
    }

    final stores = Map<String, dynamic>.from(backupMap['stores'] as Map);
    await babyLogStore.writeMap(
      _normalizeBabyLogStoreMap(_readStoreMap(stores, _babyLogStoreName)),
    );
    await memoryStore.writeMap(
      _normalizeMemoryStoreMap(_readStoreMap(stores, _memoryStoreName)),
    );
    await s3ConfigStore.writeMap(_readStoreMap(stores, _s3ConfigStoreName));
    await babyProfileStore.writeMap(_readStoreMap(stores, _babyProfileStoreName));
    await themeConfigStore.writeMap(_readStoreMap(stores, _themeConfigStoreName));
  }

  Future<void> _importLegacyBabyLogs(String content) async {
    final items = <BabyLogEntry>[];
    for (final line in content.split('\n')) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        continue;
      }
      items.add(
        BabyLogEntry.fromJson(jsonDecode(trimmedLine) as Map<String, dynamic>),
      );
    }

    await babyLogStore.writeMap({
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  Map<String, dynamic> _readStoreMap(
    Map<String, dynamic> stores,
    String storeName,
  ) {
    final storeContent = stores[storeName];
    if (storeContent == null) {
      return <String, dynamic>{};
    }
    if (storeContent is! Map) {
      throw BackupException('$storeName 数据格式不正确');
    }
    return Map<String, dynamic>.from(storeContent);
  }

  Map<String, dynamic> _normalizeBabyLogStoreMap(
    Map<String, dynamic> storeMap,
  ) {
    final rawItems = storeMap['items'] as List<dynamic>? ?? const [];
    final normalizedItems = rawItems.map((item) {
      if (item is! Map) {
        return item;
      }
      try {
        return BabyLogEntry.fromJson(Map<String, dynamic>.from(item)).toJson();
      } catch (_) {
        return Map<String, dynamic>.from(item);
      }
    }).toList();

    return {...storeMap, 'items': normalizedItems};
  }

  Map<String, dynamic> _normalizeMemoryStoreMap(Map<String, dynamic> storeMap) {
    final rawItems = storeMap['items'] as List<dynamic>? ?? const [];
    final normalizedItems = rawItems.map((item) {
      if (item is! Map) {
        return item;
      }
      try {
        return MemoryItem.fromJson(Map<String, dynamic>.from(item)).toJson();
      } catch (_) {
        return Map<String, dynamic>.from(item);
      }
    }).toList();

    return {...storeMap, 'items': normalizedItems};
  }
}

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}
