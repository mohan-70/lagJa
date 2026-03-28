import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/group_member.dart';

class LeaderboardScreen extends StatefulWidget {
  final bool showAppBar;
  const LeaderboardScreen({super.key, this.showAppBar = true});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _groupId;
  String? _groupName;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    _checkGroupStatus();
  }

  Future<void> _checkGroupStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final userGroupDoc = await _firestore.collection('users').doc(uid).collection('meta').doc('group').get();
      if (userGroupDoc.exists) {
        final groupId = userGroupDoc.data()?['groupId'];
        if (groupId != null) {
          final groupDoc = await _firestore.collection('groups').doc(groupId).get();
          if (groupDoc.exists) {
            setState(() {
              _groupId = groupId;
              _groupName = groupDoc.data()?['name'];
              _inviteCode = groupDoc.data()?['inviteCode'];
              _isLoading = false;
            });
            // Sync stats if in a group
            _syncUserStats(groupId);
            return;
          }
        }
      }
      setState(() {
        _groupId = null;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error checking group status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncUserStats(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Total Problems
      final dsaSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('dsa_problems')
          .collection('items')
          .where('isSolved', isEqualTo: true)
          .get();
      final totalProblems = dsaSnapshot.docs.length;

      // 2. Weekly Problems (Monday to Today)
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);
      
      final activitySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('activity')
          .collection('dates')
          .get();

      int weeklyProblems = 0;
      Map<String, int> activityData = {};
      
      for (var doc in activitySnapshot.docs) {
        final dateStr = doc.id;
        final count = (doc.data() as Map<String, dynamic>)['count'] ?? 0;
        activityData[dateStr] = count;
        
        try {
          final date = DateTime.parse(dateStr);
          // Check if date is within current week (Monday to Today inclusive)
          if (date.isAtSameMomentAs(startOfWeek) || (date.isAfter(startOfWeek) && date.isBefore(now.add(const Duration(days: 1))))) {
            weeklyProblems += count is int ? count : (count as num).toInt();
          }
        } catch (_) {}
      }

      // 3. Current Streak (Reusing logic from Dashboard)
      int currentStreak = _calculateStreak(activityData);

      // Update Member doc
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
    final sortedDates = activityData.keys.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime current = DateTime.now();
    for (int i = 0; i < sortedDates.length; i++) {
      final date = DateFormat('yyyy-MM-dd').parse(sortedDates[i]);
      final diff = current.difference(date).inDays;
      if (diff == streak) streak++;
      else if (diff > streak) break;
    }
    return streak;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.showAppBar 
        ? const Scaffold(
            backgroundColor: Color(0xFF000000),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
          )
        : const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }

    if (_groupId == null) {
      return _buildNoGroupState();
    }

    return _buildLeaderboardState();
  }

  // --- STATE 1: NO GROUP ---

  Widget _buildNoGroupState() {
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Compete with Friends',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a group or join one with an invite code. See who grinds the hardest.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _showCreateGroupSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _showJoinGroupSheet,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2C2C2E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Join with Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: const Text('Placement War 🏆', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: body,
    );
  }

  void _showCreateGroupSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Group', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Group Name (e.g. LNCT CSE 2025)',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _createGroup(controller.text.trim()),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    if (name.isEmpty) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);

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

      // Add user as member
      final member = GroupMember(
        uid: uid!,
        displayName: _auth.currentUser?.displayName ?? 'User',
        photoUrl: _auth.currentUser?.photoURL ?? '',
        weeklyProblems: 0,
        totalProblems: 0,
        currentStreak: 0,
      );
      await _firestore.collection('groups').doc(newGroupId).collection('members').doc(uid).set(member.toMap());

      // Update user meta
      await _firestore.collection('users').doc(uid).collection('meta').doc('group').set({
        'groupId': newGroupId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _groupId = newGroupId;
        _groupName = name;
        _inviteCode = inviteCode;
        _isLoading = false;
      });
      _syncUserStats(newGroupId);
    } catch (e) {
      _showSnackBar('Failed to create group: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showJoinGroupSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Join Group', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, letterSpacing: 4),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '6-DIGIT CODE',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93), letterSpacing: 0),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _joinGroup(controller.text.trim().toUpperCase()),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(String code) async {
    if (code.length != 6) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final groupsQuery = await _firestore.collection('groups').where('inviteCode', isEqualTo: code).limit(1).get();
      
      if (groupsQuery.docs.isEmpty) {
        _showSnackBar('Invalid code. Check with your friend.');
        setState(() => _isLoading = false);
        return;
      }

      final groupDoc = groupsQuery.docs.first;
      final groupId = groupDoc.id;
      final uid = _auth.currentUser?.uid;

      // Add user as member
      final member = GroupMember(
        uid: uid!,
        displayName: _auth.currentUser?.displayName ?? 'User',
        photoUrl: _auth.currentUser?.photoURL ?? '',
        weeklyProblems: 0,
        totalProblems: 0,
        currentStreak: 0,
      );
      await _firestore.collection('groups').doc(groupId).collection('members').doc(uid).set(member.toMap());

      // Update user meta
      await _firestore.collection('users').doc(uid).collection('meta').doc('group').set({
        'groupId': groupId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _groupId = groupId;
        _groupName = groupDoc.data()['name'];
        _inviteCode = groupDoc.data()['inviteCode'];
        _isLoading = false;
      });
      _showSnackBar('Joined group successfully! 🎉');
      _syncUserStats(groupId);
    } catch (e) {
      _showSnackBar('Failed to join group: $e');
      setState(() => _isLoading = false);
    }
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  // --- STATE 2: LEADERBOARD ---

  Widget _buildLeaderboardState() {
    final uid = _auth.currentUser?.uid;

    final body = StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .doc(_groupId)
          .collection('members')
          .orderBy('weeklyProblems', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
        }

        final members = snapshot.data!.docs.map((doc) => GroupMember.fromMap(doc.data() as Map<String, dynamic>)).toList();
        
        final userIndex = members.indexWhere((m) => m.uid == uid);
        final userMember = userIndex != -1 ? members[userIndex] : null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (userMember != null) _buildRankCard(userIndex + 1, userMember),
            const SizedBox(height: 24),
            const Text('LEADERBOARD', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...members.asMap().entries.map((entry) {
              return _buildMemberCard(entry.key + 1, entry.value, entry.value.uid == uid);
            }),
            const SizedBox(height: 12),
            const Center(child: Text('Resets every Monday 🔄', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12))),
            const SizedBox(height: 24),
            _buildInviteCard(),
            const SizedBox(height: 40),
          ],
        );
      },
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_groupName ?? 'Leaderboard', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Placement War 🏆', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _inviteCode ?? ''));
              _showSnackBar('Invite code copied: $_inviteCode 📋');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'leave') _confirmLeaveGroup();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'leave', child: Text('Leave Group', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildRankCard(int rank, GroupMember member) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        children: [
          Text('Your Rank: #$rank', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
      ],
    );
  }

  Widget _buildMemberCard(int rank, GroupMember member, bool isMe) {
    String rankPrefix = '$rank';
    if (rank == 1) rankPrefix = '🥇';
    else if (rank == 2) rankPrefix = '🥈';
    else if (rank == 3) rankPrefix = '🥉';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? const Color(0xFF6C63FF).withOpacity(0.5) : const Color(0xFF2C2C2E)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (isMe) Container(width: 4, decoration: const BoxDecoration(color: Color(0xFF6C63FF), borderRadius: BorderRadius.horizontal(left: Radius.circular(12)))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(rankPrefix, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      '${member.weeklyProblems} problems this week · ${member.currentStreak} day streak',
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${member.weeklyProblems}', style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        children: [
          const Text('Invite Friends', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFF000000), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF2C2C2E))),
                  child: Text(_inviteCode ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'monospace')),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _inviteCode ?? ''));
                  _showSnackBar('Invite code copied! 📋');
                },
                icon: const Icon(Icons.copy, color: Color(0xFF6C63FF)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Share this code with your friends to add them to the war 💪', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Leave Group?', style: TextStyle(color: Colors.white)),
        content: const Text('You will lose your position in the leaderboard. Your stats will still be saved locally.', style: TextStyle(color: Color(0xFF8E8E93))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93)))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGroup();
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      final groupId = _groupId;

      if (uid != null && groupId != null) {
        await _firestore.collection('groups').doc(groupId).collection('members').doc(uid).delete();
        await _firestore.collection('users').doc(uid).collection('meta').doc('group').delete();
      }

      setState(() {
        _groupId = null;
        _groupName = null;
        _inviteCode = null;
        _isLoading = false;
      });
      _showSnackBar('Left group');
    } catch (e) {
      _showSnackBar('Error leaving group: $e');
      setState(() => _isLoading = false);
    }
  }
}
