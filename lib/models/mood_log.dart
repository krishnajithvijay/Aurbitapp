class MoodLog {
  final String id;
  final String userId;
  final String mood;
  final String? note;
  final DateTime createdAt;

  MoodLog({
    required this.id,
    required this.userId,
    required this.mood,
    this.note,
    required this.createdAt,
  });

  factory MoodLog.fromJson(Map<String, dynamic> json) {
    return MoodLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      mood: json['mood']?.toString() ?? 'Neutral',
      note: json['note']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'mood': mood,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
