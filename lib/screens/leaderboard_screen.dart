// LeaderboardScreen: Handles the social "Placement War" feature.
// Allows users to create/join groups and view a competitive leaderboard based on weekly problems solved.
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/group_member.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/fake_glass_card.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/ui_constants.dart';
import '../widgets/ui/lagja_loader.dart';
import '../widgets/ui/gradient_button.dart';

class LeaderboardScreen extends StatefulWidget {
  final bool showAppBar;
  const LeaderboardScreen({super.key, this.showAppBar = true});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // ─── State ───────────────────────────────────────────────────────────────────

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _groupId;
  String? _groupName;
  Future<QuerySnapshot>? _leaderboardFuture;

  // ─── Date helper ─────────────────────────────────────────────────────────────

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkGroupStatus();
  }

  // ─── Group Status ─────────────────────────────────────────────────────────────

  /// Checks if the current user is already part of a group on app launch
  Future<void> _checkGroupStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userGroupDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('meta')
          .doc('group')
          .get();

      if (userGroupDoc.exists) {
        final groupId = userGroupDoc.data()?['groupId'] as String?;
        if (groupId != null) {
          final groupDoc =
              await _firestore.collection('groups').doc(groupId).get();
          if (groupDoc.exists) {
            if (mounted) {
              setState(() {
                _groupId = groupId;
                _groupName = groupDoc.data()?['name'] as String?;
                _leaderboardFuture = _fetchLeaderboardData(groupId);
                _isLoading = false;
              });
            }
            _syncUserStats(groupId);
            return;
          }
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _showSnackBar('Error checking group status: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Data Sync ───────────────────────────────────────────────────────────────

  /// Syncs the user's local progress (DSA problems, streaks) to the group's leaderboard
  Future<void> _syncUserStats(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final dsaSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('dsa_problems')
          .collection('items')
          .where('isSolved', isEqualTo: true)
          .get();
      final totalProblems = dsaSnapshot.docs.length;

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek =
          DateTime(monday.year, monday.month, monday.day);

      final weeklySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('dsa_problems')
          .collection('items')
          .where('isSolved', isEqualTo: true)
          .where('createdAt',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(startOfWeek))
          .get();
      final weeklyProblems = weeklySnapshot.docs.length;

      final startDateStr = DateFormat('yyyy-MM-dd').format(
        _today().subtract(const Duration(days: 180)),
      );
      final activitySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('activity')
          .collection('dates')
          .where(FieldPath.documentId,
              isGreaterThanOrEqualTo: startDateStr)
          .get();

      final Map<String, int> activityData = {};
      for (final doc in activitySnapshot.docs) {
        final count = (doc.data()['count'] as num?)?.toInt() ?? 0;
        activityData[doc.id] = count;
      }

      final currentStreak = _calculateStreak(activityData);

      final member = GroupMember(
        uid: uid,
        displayName: _auth.currentUser?.displayName ?? 'User',
        photoUrl: _auth.currentUser?.photoURL ?? '',
        weeklyProblems: weeklyProblems,
        totalProblems: totalProblems,
        currentStreak: currentStreak,
      );

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .set(member.toMap());
    } catch (e) {
      debugPrint('[LeaderboardScreen] Sync error: $e');
    }
  }

  /// Computes the current daily activity streak
  int _calculateStreak(Map<String, int> activityData) {
    if (activityData.isEmpty) return 0;

    final today = _today();
    final sortedDates = activityData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final mostRecent =
        DateFormat('yyyy-MM-dd').parse(sortedDates.first);
    final gap = today.difference(mostRecent).inDays;
    if (gap > 1) return 0;

    int streak = 0;
    DateTime expected =
        gap == 0 ? today : today.subtract(const Duration(days: 1));

    for (final dateStr in sortedDates) {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      if (date == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (date.isBefore(expected)) {
        break;
      }
    }
    return streak;
  }

  // ─── Leaderboard Fetch ────────────────────────────────────────────────────────

  Future<QuerySnapshot> _fetchLeaderboardData(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .orderBy('weeklyProblems', descending: true)
        .get();
  }

  Future<void> _refreshLeaderboard() async {
    if (_groupId == null) return;
    await _syncUserStats(_groupId!);
    if (mounted) {
      setState(() {
        _leaderboardFuture = _fetchLeaderboardData(_groupId!);
      });
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(
            length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── Create Group ─────────────────────────────────────────────────────────────

  void _showCreateGroupSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create Group',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Group Name (e.g. LNCT CSE 2025)',
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Create',
              onTap: () {
                final name = controller.text.trim();
                controller.dispose();
                Navigator.pop(sheetContext);
                if (name.isNotEmpty) _createGroup(name);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final inviteCode = _generateRandomCode(6);
      final newGroupId = _firestore.collection('groups').doc().id;

      await _firestore.collection('groups').doc(newGroupId).set({
        'name': name,
        'inviteCode': inviteCode,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final member = GroupMember(
        uid: uid,
        displayName: _auth.currentUser?.displayName ?? 'User',
        photoUrl: _auth.currentUser?.photoURL ?? '',
        weeklyProblems: 0,
        totalProblems: 0,
        currentStreak: 0,
      );
      await _firestore
          .collection('groups')
          .doc(newGroupId)
          .collection('members')
          .doc(uid)
          .set(member.toMap());

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('meta')
          .doc('group')
          .set({
        'groupId': newGroupId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _groupId = newGroupId;
          _groupName = name;
          _leaderboardFuture = _fetchLeaderboardData(newGroupId);
          _isLoading = false;
        });
      }
      _syncUserStats(newGroupId);
    } catch (e) {
      _showSnackBar('Failed to create group: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Join Group ───────────────────────────────────────────────────────────────

  void _showJoinGroupSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Join Group',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                  color: AppColors.textPrimary, letterSpacing: 4),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: '6-DIGIT CODE',
                counterText: '',
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Join',
              onTap: () {
                final code =
                    controller.text.trim().toUpperCase();
                controller.dispose();
                Navigator.pop(sheetContext);
                if (code.length == 6) _joinGroup(code);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final groupsQuery = await _firestore
          .collection('groups')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (groupsQuery.docs.isEmpty) {
        _showSnackBar('Invalid code. Check with your friend.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final groupDoc = groupsQuery.docs.first;
      final groupId = groupDoc.id;

      final member = GroupMember(
        uid: uid,
        displayName: _auth.currentUser?.displayName ?? 'User',
        photoUrl: _auth.currentUser?.photoURL ?? '',
        weeklyProblems: 0,
        totalProblems: 0,
        currentStreak: 0,
      );

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .set(member.toMap());

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('meta')
          .doc('group')
          .set({
        'groupId': groupId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _groupId = groupId;
          _groupName = groupDoc.data()['name'] as String?;
          _leaderboardFuture = _fetchLeaderboardData(groupId);
          _isLoading = false;
        });
        _showSnackBar('Joined group successfully! 🎉');
      }
      _syncUserStats(groupId);
    } catch (e) {
      _showSnackBar('Failed to join group: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Leave Group ──────────────────────────────────────────────────────────────

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'You will lose your position in the leaderboard. '
          'Your personal stats will still be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGroup();
            },
            child: const Text('Leave',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final uid = _auth.currentUser?.uid;
    final groupId = _groupId;
    if (uid == null || groupId == null) return;

    setState(() => _isLoading = true);
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .delete();
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('meta')
          .doc('group')
          .delete();

      if (mounted) {
        setState(() {
          _groupId = null;
          _groupName = null;
          _isLoading = false;
        });
        _showSnackBar('Left group');
      }
    } catch (e) {
      _showSnackBar('Error leaving group: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: LagjaLoader());
    if (_groupId == null) return _buildNoGroupState();
    return _buildLeaderboardState();
  }

  // ─── No Group State ───────────────────────────────────────────────────────────

  Widget _buildNoGroupState() {
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            const Text(
              'Compete with Friends',
              style: AppStyles.heroTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a group or join one with an invite code. '
              'See who grinds the hardest.',
              textAlign: TextAlign.center,
              style: AppStyles.body,
            ),
            const SizedBox(height: 48),
            GradientButton(
              label: 'Create Group',
              onTap: _showCreateGroupSheet,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _showJoinGroupSheet,
                child: const Text(
                  'Join with Code',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return body;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Placement War 🏆'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: body,
    );
  }

  // ─── Leaderboard State ────────────────────────────────────────────────────────

  Widget _buildLeaderboardState() {
    final uid = _auth.currentUser?.uid;

    final body = FutureBuilder<QuerySnapshot>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LagjaLoader());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load leaderboard',
                    style:
                        TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _refreshLeaderboard,
                  child: const Text('Retry',
                      style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No members yet. Invite a friend!',
                style:
                    TextStyle(color: AppColors.textSecondary)),
          );
        }

        final members = snapshot.data!.docs
            .map((doc) => GroupMember.fromMap(
                doc.data() as Map<String, dynamic>))
            .toList();

        final userIndex =
            members.indexWhere((m) => m.uid == uid);
        final userMember =
            userIndex != -1 ? members[userIndex] : null;

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: _refreshLeaderboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (userMember != null)
                _buildRankCard(userIndex + 1, userMember),
              const SectionHeader('LEADERBOARD'),
              ...members.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMemberCard(
                      entry.key + 1,
                      entry.value,
                      entry.value.uid == uid,
                    ),
                  )),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Resets every Monday 🔄',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _groupName ?? 'Leaderboard',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Placement War 🏆',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textPrimary),
            onSelected: (val) {
              if (val == 'leave') _confirmLeaveGroup();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'leave',
                child: Text('Leave Group',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: body,
    );
  }

  // ─── Component Widgets ────────────────────────────────────────────────────────

  /// Hero card showing the current user's rank and stats
  Widget _buildRankCard(int rank, GroupMember member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FakeGlassCard(
        child: Column(
          children: [
            Text(
              'Your Rank: #$rank',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(
                    'Weekly', '${member.weeklyProblems}'),
                _buildMiniStat('Total', '${member.totalProblems}'),
                _buildMiniStat(
                    'Streak', '${member.currentStreak}d'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// Individual member row in the leaderboard list
  Widget _buildMemberCard(
      int rank, GroupMember member, bool isMe) {
    final rankPrefix = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '$rank',
    };

    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (isMe)
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(16)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              child: Text(
                rankPrefix,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${member.weeklyProblems} weekly · '
                      '${member.currentStreak}d streak',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${member.weeklyProblems}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}