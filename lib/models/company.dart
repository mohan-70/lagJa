import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  wishlist,
  applied,
  interview,
  offered,
  rejected,
}

class Company {
  final String id;
  final String name;
  final String role;
  final ApplicationStatus status;
  final String? notes;
  final DateTime createdAt;

  Company({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory Company.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      status: _parseStatus(data['status'] ?? 'wishlist'),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  static ApplicationStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'wishlist':
        return ApplicationStatus.wishlist;
      case 'applied':
        return ApplicationStatus.applied;
      case 'interview':
        return ApplicationStatus.interview;
      case 'offered':
        return ApplicationStatus.offered;
      case 'rejected':
        return ApplicationStatus.rejected;
      default:
        return ApplicationStatus.wishlist;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role,
      'status': status.name,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? role,
    ApplicationStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  ApplicationStatus get nextStatus {
    switch (status) {
      case ApplicationStatus.wishlist:
        return ApplicationStatus.applied;
      case ApplicationStatus.applied:
        return ApplicationStatus.interview;
      case ApplicationStatus.interview:
        return ApplicationStatus.offered;
      case ApplicationStatus.offered:
      case ApplicationStatus.rejected:
        return status;
    }
  }
}
