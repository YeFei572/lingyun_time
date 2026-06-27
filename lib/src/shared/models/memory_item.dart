import 'dart:convert';

class MemoryItem {
  MemoryItem({
    required this.id,
    required this.kind,
    required this.groupKey,
    required this.localPath,
    required this.remoteUrl,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String groupKey;
  final String localPath;
  final String remoteUrl;
  final DateTime createdAt;

  bool get isPhoto => kind == 'photo';
  bool get isVideo => kind == 'video';

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': kind,
    'groupKey': groupKey,
    'localPath': localPath,
    'remoteUrl': remoteUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final rawKind =
        json['type'] as String? ?? json['kind'] as String? ?? 'photo';
    return MemoryItem(
      id: json['id'] as String,
      kind: _normalizeKind(rawKind),
      groupKey: json['groupKey'] as String? ?? _groupKeyFor(createdAt),
      localPath: json['localPath'] as String? ?? '',
      remoteUrl: _normalizeRemoteUrl(json['remoteUrl'] as String? ?? ''),
      createdAt: createdAt,
    );
  }

  static String _normalizeKind(String rawKind) {
    final repaired = _repairMojibake(rawKind).trim();
    final lower = repaired.toLowerCase();
    return switch (lower) {
      'photo' || 'image' || 'picture' || '照片' || '图片' => 'photo',
      'video' || 'movie' || '视频' => 'video',
      _ => lower.isEmpty ? 'photo' : lower,
    };
  }

  static String _normalizeRemoteUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (!trimmed.endsWith('?')) {
      return trimmed;
    }
    return trimmed.replaceFirst(RegExp(r'\?+$'), '');
  }

  static String _repairMojibake(String value) {
    try {
      return utf8.decode(latin1.encode(value));
    } on FormatException {
      return value;
    } on ArgumentError {
      return value;
    }
  }

  static String _groupKeyFor(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}';
  }
}
