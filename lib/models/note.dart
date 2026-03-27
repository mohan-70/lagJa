import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String companyName;
  final String content;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.companyName,
    required this.content,
    required this.createdAt,
  });

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      companyName: data['companyName'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyName': companyName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Note copyWith({
    String? id,
    String? companyName,
    String? content,
    DateTime? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
