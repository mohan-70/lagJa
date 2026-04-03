import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  String? _groupId;
  String? _groupName;
  String? _inviteCode;
  Future<QuerySnapshot>? _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _checkGroupStatus();
  }

  Future<void> _checkGroupStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final userGroupDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('meta')
          .doc('group')
          .get();
      if (userGroupDoc.exists) {
        final groupId = userGroupDoc.data()?['groupId'];
        if (groupId != null) {
          final groupDoc =
              await _firestore.collection('groups').doc(groupId).get();
          if (groupDoc.exists) {
            setState(() {
              _groupId = groupId;
              _groupName = groupDoc.data()?['name'];
              _inviteCode = groupDoc.data()?['inviteCode'];
              _leaderboardFuture = _fetchLeaderboardData(groupId);
            });
            await _leaderboardFuture;
            if (mounted) {
              setState(() => isLoading = false);
            }
            _syncUserStats(groupId);
            return;
          }
        }
      }
      setState(() {
        _groupId = null;
        isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error checking group status: $e');
      setState(() => isLoading = false);
    }
  }

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
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);
      
      final startDateStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 180)));

      final activitySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('activity')
          .collection('dates')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .get();

      int weeklyProblems = 0;
      Map<String, int> activityData = {};

      for (var doc in activitySnapshot.docs) {
        final dateStr = doc.id;
        final count = doc.data()['count'] ?? 0;
        activityData[dateStr] = count;

        try {
          final date = DateTime.parse(dateStr);
          if (date.isAtSameMomentAs(startOfWeek) ||
              (date.isAfter(startOfWeek) &&
                  date.isBefore(now.add(const Duration(days: 1))))) {
            weeklyProblems += count is int ? count : (count as num).toInt();
          }
        } catch (_) {}
      }

      int currentStreak = _calculateStreak(activityData);

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
      debugPrint('Sync Error: $e');
    }
  }

  int _calculateStreak(Map<String, int> activityData) {
    if (activityData.isEmpty) return 0;
    final sortedDates = activityData.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime current = DateTime.now();
    for (int i = 0; i < sortedDates.length; i++) {
      final date = DateFormat('yyyy-MM-dd').parse(sortedDates[i]);
      final diff = current.difference(date).inDays;
      if (diff == streak) {
        streak++;
      } else if (diff > streak) {
        break;
      }
    }
    return streak;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: LagjaLoader());

    if (_groupId == null) {
      return _buildNoGroupState();
    }

    return _buildLeaderboardState();
  }

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
              'Create a group or join one with an invite code. See who grinds the hardest.',
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
                child: const Text('Join with Code',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.accent)),
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

  void _showCreateGroupSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
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
            const Text('Create Group',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Group Name (e.g. LNCT CSE 2025)',
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Create',
              onTap: () => _createGroup(controller.text.trim()),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    if (name.isEmpty) return;
    Navigator.pop(context);
    setState(() => isLoading = true);

    try {
      final uid = _auth.currentUser?.uid;
      final inviteCode = _generateRandomCode(6);
      final newGroupId = _firestore.collection('groups').doc().id;

      final groupData = {
        'name': name,
        'inviteCode': inviteCode,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('groups').doc(newGroupId).set(groupData);

      final member = GroupMember(
        uid: uid!,
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

      setState(() {
        _groupId = newGroupId;
        _groupName = name;
        _inviteCode = inviteCode;
        _leaderboardFuture = _fetchLeaderboardData(newGroupId);
      });
      await _leaderboardFuture;
      if (mounted) {
        setState(() => isLoading = false);
      }
      _syncUserStats(newGroupId);
    } catch (e) {
      _showSnackBar('Failed to create group: $e');
      setState(() => isLoading = false);
    }
  }

  void _showJoinGroupSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
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
            const Text('Join Group',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
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
              onTap: () => _joinGroup(controller.text.trim().toUpperCase()),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(String code) async {
    if (code.length != 6) return;
    Navigator.pop(context);
    setState(() => isLoading = true);

    try {
      final groupsQuery = await _firestore
          .collection('groups')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (groupsQuery.docs.isEmpty) {
        _showSnackBar('Invalid code. Check with your friend.');
        setState(() => isLoading = false);
        return;
      }

      final groupDoc = groupsQuery.docs.first;
      final groupId = groupDoc.id;
      final uid = _auth.currentUser?.uid;

      final member = GroupMember(
        uid: uid!,
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

      setState(() {
        _groupId = groupId;
        _groupName = groupDoc.data()['name'];
        _inviteCode = groupDoc.data()['inviteCode'];
        _leaderboardFuture = _fetchLeaderboardData(groupId);
      });
      await _leaderboardFuture;
      if (mounted) {
        setState(() => isLoading = false);
      }
      _showSnackBar('Joined group successfully! 🎉');
      _syncUserStats(groupId);
    } catch (e) {
      _showSnackBar('Failed to join group: $e');
      setState(() => isLoading = false);
    }
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
        length, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<QuerySnapshot> _fetchLeaderboardData(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .orderBy('weeklyProblems', descending: true)
        .get();
  }

  Future<void> _refreshLeaderboard() async {
    if (_groupId != null) {
      await _syncUserStats(_groupId!);
      setState(() {
        _leaderboardFuture = _fetchLeaderboardData(_groupId!);
      });
    }
  }

  Widget _buildLeaderboardState() {
    final uid = _auth.currentUser?.uid;

    final body = FutureBuilder<QuerySnapshot>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final members = snapshot.data!.docs
            .map((doc) => GroupMember.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        final userIndex = members.indexWhere((m) => m.uid == uid);
        final userMember = userIndex != -1 ? members[userIndex] : null;

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: _refreshLeaderboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
            if (userMember != null) _buildRankCard(userIndex + 1, userMember),
            const SectionHeader('LEADERBOARD'),
            ...members.asMap().entries.map((entry) {
              return AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: _buildMemberCard(
                    entry.key + 1, entry.value, entry.value.uid == uid),
              );
            }),
            const SizedBox(height: 12),
            const Center(
                child: Text('Resets every Monday 🔄',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12))),
            const SectionHeader('INVITE'),
            _buildInviteCard(),
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
            Text(_groupName ?? 'Leaderboard',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Placement War 🏆',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.textPrimary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _inviteCode ?? ''));
              _showSnackBar('Invite code copied: $_inviteCode 📋');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (val) {
              if (val == 'leave') _confirmLeaveGroup();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'leave',
                  child:
                      Text('Leave Group', style: TextStyle(color: Colors.red))),
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

  Widget _buildRankCard(int rank, GroupMember member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FakeGlassCard(
        child: Column(
          children: [
            Text('Your Rank: #$rank',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Weekly', '${member.weeklyProblems}'),
                _buildMiniStat('Total', '${member.totalProblems}'),
                _buildMiniStat('Streak', '${member.currentStreak}d'),
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
        Text(value,
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildMemberCard(int rank, GroupMember member, bool isMe) {
    String rankPrefix = '$rank';
    if (rank == 1) {
      rankPrefix = '🥇';
    } else if (rank == 2) {
      rankPrefix = '🥈';
    } else if (rank == 3) {
      rankPrefix = '🥉';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
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
                            left: Radius.circular(16)))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Text(rankPrefix,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.displayName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        '${member.weeklyProblems} weekly · ${member.currentStreak}d streak',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${member.weeklyProblems}',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return AppCard(
      child: Column(
        children: [
          const Text('Invite Friends',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                  child: Text(_inviteCode ?? '',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          fontFamily: 'monospace')),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _inviteCode ?? ''));
                  _showSnackBar('Invite code copied! 📋');
                },
                icon: const Icon(Icons.copy, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
              'Share this code with your friends to add them to the war 💪',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
            'You will lose your position in the leaderboard. Your stats will still be saved locally.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGroup();
            },
            child: const Text('Leave', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    setState(() => isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      final groupId = _groupId;

      if (uid != null && groupId != null) {
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
      }

      setState(() {
        _groupId = null;
        _groupName = null;
        _inviteCode = null;
        isLoading = false;
      });
      _showSnackBar('Left group');
    } catch (e) {
      _showSnackBar('Error leaving group: $e');
      setState(() => isLoading = false);
    }
  }
}
