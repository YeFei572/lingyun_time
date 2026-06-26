import 'dart:convert';
import 'dart:io';

class LocalJsonStore {
  final File file;

  LocalJsonStore(this.file);

  Future<Map<String, dynamic>> readMap() async {
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> writeMap(Map<String, dynamic> data) async {
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}
