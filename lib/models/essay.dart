// lib/models/essay.dart
class Essay {
  final String id;
  final String topic;
  final String content;
  final DateTime createdAt;
  final int rating; // New field for rating

  Essay({
    required this.id,
    required this.topic,
    required this.content,
    required this.createdAt,
    this.rating = 0,
  });

  factory Essay.fromJson(Map<String, dynamic> json) {
    return Essay(
      id: json['id'],
      topic: json['topic'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      rating: json['rating'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'rating': rating,
    };
  }
}
