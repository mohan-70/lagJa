import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'dsa_tracker_screen.dart';
import 'companies_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(authService),
            const SizedBox(height: 32),
            _buildSectionHeader('YOUR OVERVIEW'),
            const SizedBox(height: 12),
            _buildStatsCards(firestoreService),
            const SizedBox(height: 24),
            _buildSectionHeader('STREAK'),
            const SizedBox(height: 12),
            _buildStreakCard(firestoreService),
            const SizedBox(height: 24),
            _buildSectionHeader('ACTIVITY'),
            const SizedBox(height: 12),
            _buildActivityHeatmap(firestoreService),
            const SizedBox(height: 24),
            _buildSectionHeader('QUICK ACTIONS'),
            const SizedBox(height: 12),
            _buildQuickActions(context),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));
  }

  Widget _buildGreeting(AuthService authService) {
    final hour = DateTime.now().hour;
    String greeting = 'Good ';
    if (hour < 12) greeting += 'Morning';
    else if (hour < 17) greeting += 'Afternoon';
    else greeting += 'Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting,', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 17, fontWeight: FontWeight.w400)),
        Text('${authService.currentUserName?.split(' ').first ?? 'User'}!',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1)),
      ],
    );
  }

  Widget _buildStatsCards(FirestoreService firestoreService) {
    return StreamBuilder<Map<String, int>>(
      stream: firestoreService.getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'totalProblems': 0, 'solvedProblems': 0, 'companies': 0};
        return Container(
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5)),
          child: Column(
            children: [
              _buildStatItem('DSA Completion', '${stats['solvedProblems']}/${stats['totalProblems']}', Icons.code_rounded, const Color(0xFF6C63FF)),
              const Divider(color: Color(0xFF38383A), height: 0.5, indent: 56),
              _buildStatItem('Applications', '${stats['companies']}', Icons.business_center_rounded, const Color(0xFF30D158)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500))),
          Text(value, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 17, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStreakCard(FirestoreService firestoreService) {
    return StreamBuilder<Map<String, int>>(
      stream: firestoreService.getActivityData(),
      builder: (context, snapshot) {
        final activityData = snapshot.data ?? {};
        final streak = _calculateStreak(activityData);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5)),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [const Color(0xFF6C63FF).withOpacity(0.08), Colors.transparent],
                      ),
                    ),
                  ),
                  const Text('🔥', style: TextStyle(fontSize: 32)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$streak Day Streak', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Text('Consistency is key.', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityHeatmap(FirestoreService firestoreService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5)),
      child: StreamBuilder<Map<String, int>>(
        stream: firestoreService.getActivityData(),
        builder: (context, snapshot) {
          final activityData = snapshot.data ?? {};
          final convertedData = <DateTime, int>{};
          activityData.forEach((key, value) => convertedData[DateTime.parse(key)] = value);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: HeatMapCalendar(
                datasets: convertedData,
                colorMode: ColorMode.color, // Fixed: Changed from invalid .description to .color
                showColorTip: true,
                size: 28,
                fontSize: 10,
                margin: const EdgeInsets.all(2),
                weekTextColor: const Color(0xFF8E8E93),
                textColor: Colors.white,
                monthFontSize: 14,
                colorsets: {
                  1: const Color(0xFF6C63FF).withOpacity(0.2),
                  2: const Color(0xFF6C63FF).withOpacity(0.4),
                  3: const Color(0xFF6C63FF).withOpacity(0.6),
                  4: const Color(0xFF6C63FF).withOpacity(0.8),
                  5: const Color(0xFF6C63FF),
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5)),
      child: Column(
        children: [
          _buildActionItem('Add DSA Problem', Icons.add_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DSATrackerScreen()))),
          const Divider(color: Color(0xFF38383A), height: 0.5, indent: 56),
          _buildActionItem('Add Company', Icons.business_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CompaniesScreen()))),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: const Color(0xFF6C63FF), size: 20)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w400)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF48484A), size: 20),
    );
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
}
