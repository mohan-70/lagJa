import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/fake_glass_card.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/ui_constants.dart';
import 'dsa_tracker_screen.dart';
import 'companies_screen.dart';
import 'leaderboard_screen.dart';
import 'company_intel_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          toolbarHeight: 80,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lagja',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Hey ${authService.currentUserName?.split(' ').first ?? 'User'} 👋',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 2,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  isScrollable: false,
                  tabs: [
                    Tab(text: "Overview"),
                    Tab(text: "Leaderboard"),
                    Tab(text: "Intel"),
                    Tab(text: "Settings"),
                  ],
                ),
                Container(
                  height: 0.3,
                  color: AppColors.border,
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(authService, firestoreService, context),
            const LeaderboardScreen(showAppBar: false),
            const CompanyIntelScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(AuthService authService,
      FirestoreService firestoreService, BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStreakCard(firestoreService),
          const SizedBox(height: 24),
          _buildStatsCards(firestoreService),
          const SectionHeader("ACTIVITY"),
          _buildActivityHeatmap(firestoreService),
          const SectionHeader("QUICK ACTIONS"),
          _buildQuickActions(context),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildStatsCards(FirestoreService firestoreService) {
    return StreamBuilder<Map<String, int>>(
      stream: firestoreService.getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ??
            {'totalProblems': 0, 'solvedProblems': 0, 'companies': 0};
        return Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Icon(Icons.code, color: AppColors.accent, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      '${stats['solvedProblems']}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'SOLVED',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Icon(Icons.business_center,
                        color: AppColors.accent, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      '${stats['companies']}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'APPLIED',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Icon(Icons.list_alt, color: AppColors.accent, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      '${stats['totalProblems']}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreakCard(FirestoreService firestoreService) {
    return StreamBuilder<Map<String, int>>(
      stream: firestoreService.getActivityData(DateTime.now().subtract(const Duration(days: 180))),
      builder: (context, snapshot) {
        final activityData = snapshot.data ?? {};
        final streak = _calculateStreak(activityData);

        return FakeGlassCard(
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak Day Streak',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Consistency is your superpower',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityHeatmap(FirestoreService firestoreService) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: StreamBuilder<Map<String, int>>(
        stream: firestoreService.getActivityData(DateTime.now().subtract(const Duration(days: 180))),
        builder: (context, snapshot) {
          final activityData = snapshot.data ?? {};
          final convertedData = <DateTime, int>{};
          activityData.forEach(
              (key, value) => convertedData[DateTime.parse(key)] = value);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HeatMapCalendar(
              datasets: convertedData,
              colorMode: ColorMode.color,
              showColorTip: false,
              size: 28,
              fontSize: 10,
              margin: const EdgeInsets.all(2),
              weekTextColor: AppColors.textSecondary,
              textColor: AppColors.textPrimary,
              monthFontSize: 14,
              colorsets: {
                1: AppColors.accent.withValues(alpha: 0.2),
                2: AppColors.accent.withValues(alpha: 0.4),
                3: AppColors.accent.withValues(alpha: 0.6),
                4: AppColors.accent.withValues(alpha: 0.8),
                5: AppColors.accent,
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildActionItem(
              'Practice DSA',
              Icons.code_rounded,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const DSATrackerScreen()))),
          const Divider(color: AppColors.border, height: 1),
          _buildActionItem(
              'Track Companies',
              Icons.business_rounded,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const CompaniesScreen()))),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: AppColors.accent, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
    );
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
}

