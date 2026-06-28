class BabyProfile {
  const BabyProfile({this.birthDate});

  final DateTime? birthDate;

  bool get hasBirthDate => birthDate != null;

  Map<String, dynamic> toJson() {
    return {
      'birthDate': birthDate?.toIso8601String(),
    };
  }

  factory BabyProfile.fromJson(Map<String, dynamic> json) {
    final rawBirthDate = json['birthDate'] as String?;
    return BabyProfile(
      birthDate: rawBirthDate == null || rawBirthDate.trim().isEmpty
          ? null
          : DateTime.parse(rawBirthDate),
    );
  }
}
