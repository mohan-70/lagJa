class GroupMember {
  final String uid;
  final String displayName;
  final String photoUrl;
  final int weeklyProblems;
  final int totalProblems;
  final int currentStreak;

  GroupMember({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.weeklyProblems,
    required this.totalProblems,
    required this.currentStreak,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'weeklyProblems': weeklyProblems,
      'totalProblems': totalProblems,
      'currentStreak': currentStreak,
      'lastUpdated': DateTime.now(),
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      weeklyProblems: map['weeklyProblems'] ?? 0,
      totalProblems: map['totalProblems'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
    );
  }
}
