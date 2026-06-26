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

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'groupKey': groupKey,
        'localPath': localPath,
        'remoteUrl': remoteUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String,
      kind: json['kind'] as String,
      groupKey: json['groupKey'] as String,
      localPath: json['localPath'] as String,
      remoteUrl: json['remoteUrl'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
