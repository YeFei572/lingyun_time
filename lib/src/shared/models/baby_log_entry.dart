import 'dart:convert';

class BabyLogEntry {
  BabyLogEntry({
    required this.id,
    required this.type,
    required this.time,
    required this.amountMl,
    required this.note,
    int? sortOrder,
  }) : sortOrder = sortOrder ?? time.microsecondsSinceEpoch;

  final String id;
  final String type;
  final DateTime time;
  final int amountMl;
  final String note;
  final int sortOrder;

  bool get isFeeding => type == '吃奶';
  bool get isUrination => type == '小便' || type == '大便';

  BabyLogEntry copyWith({
    String? id,
    String? type,
    DateTime? time,
    int? amountMl,
    String? note,
    int? sortOrder,
  }) {
    return BabyLogEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      time: time ?? this.time,
      amountMl: amountMl ?? this.amountMl,
      note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'time': time.toIso8601String(),
        'amountMl': amountMl,
        'note': note,
        'sortOrder': sortOrder,
      };

  factory BabyLogEntry.fromJson(Map<String, dynamic> json) {
    final time = DateTime.parse(json['time'] as String);
    final rawType = json['type'] as String? ?? '';
    return BabyLogEntry(
      id: json['id'] as String,
      type: _normalizeType(rawType),
      time: time,
      amountMl: json['amountMl'] as int? ?? 0,
      note: json['note'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? time.microsecondsSinceEpoch,
    );
  }

  static String _normalizeType(String rawType) {
    final repaired = _repairMojibake(rawType).trim();
    return switch (repaired) {
      '吃奶' => '吃奶',
      '小便' || '大便' => '小便',
      _ => repaired,
    };
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
}
