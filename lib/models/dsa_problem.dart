import 'package:cloud_firestore/cloud_firestore.dart';

class DSAProblem {
  final String id;
  final String topic;
  final String title;
  final String difficulty;
  final bool isSolved;
  final DateTime createdAt;

  DSAProblem({
    required this.id,
    required this.topic,
    required this.title,
    required this.difficulty,
    required this.isSolved,
    required this.createdAt,
  });

  factory DSAProblem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DSAProblem(
      id: doc.id,
      topic: data['topic'] ?? '',
      title: data['title'] ?? '',
      difficulty: data['difficulty'] ?? 'Medium',
      isSolved: data['isSolved'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'topic': topic,
      'title': title,
      'difficulty': difficulty,
      'isSolved': isSolved,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  DSAProblem copyWith({
    String? id,
    String? topic,
    String? title,
    String? difficulty,
    bool? isSolved,
    DateTime? createdAt,
  }) {
    return DSAProblem(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      title: title ?? this.title,
      difficulty: difficulty ?? this.difficulty,
      isSolved: isSolved ?? this.isSolved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
