import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/fake_glass_card.dart';
import '../widgets/ui/section_header.dart';
import '../theme/app_colors.dart';
import 'dsa_tracker_screen.dart';
import 'companies_screen.dart';
import 'leaderboard_screen.dart';
import 'company_intel_screen.dart';
import 'settings_screen.dart';

// DashboardScreen: The main landing screen of the application.
// Provides a high-level overview of streaks, stats, activity, and quick actions.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              'Hey ${_authService.currentUserName?.split(' ').first ?? 'User'} 👋',
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
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 2,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                isScrollable: false,
                tabs: const [
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
        controller: _tabController,
        children: const [
          _OverviewTab(),
          LeaderboardScreen(showAppBar: false),
          CompanyIntelScreen(),
          SettingsScreen(),
        ],
      ),
    );
  }
}

/// Overview Tab: Extracted into its own StatefulWidget with AutomaticKeepAliveClientMixin 
/// so the tab content (and its Firestore streams) survive tab switches.
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  bool get wantKeepAlive => true;

  /// Returns DateTime.now() with time stripped to midnight.
  /// Used by streak calculation to avoid time-of-day edge cases.
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Calculates the current streak from activity data.
  /// Treats "solved today OR yesterday" as day-0 so the streak is not reset
  /// just because the user hasn't opened the app yet this morning.
  int _calculateStreak(Map<String, int> activityData) {
    if (activityData.isEmpty) return 0;

    final today = _today();
    final sortedDates = activityData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // descending

    final mostRecent = DateFormat('yyyy-MM-dd').parse(sortedDates.first);
    final gap = today.difference(mostRecent).inDays;
    if (gap > 1) return 0; 

    int streak = 0;
    DateTime expected = gap == 0 ? today : today.subtract(const Duration(days: 1));

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

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return StreamBuilder<Map<String, int>>(
      stream: _firestoreService.getActivityData(_today().subtract(const Duration(days: 180))),
      builder: (context, snapshot) {
        final activityData = snapshot.data ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStreakCard(activityData),
              const SizedBox(height: 24),
              _buildStatsCards(),
              const SectionHeader("ACTIVITY"),
              _buildActivityHeatmap(activityData),
              const SectionHeader("QUICK ACTIONS"),
              _buildQuickActions(context),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  /// Displays high-level stats (solved problems, applications) using real-time data
  Widget _buildStatsCards() {
    return StreamBuilder<Map<String, int>>(
      stream: _firestoreService.getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ??
            {'totalProblems': 0, 'solvedProblems': 0, 'companies': 0, 'notes': 0};
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
                    ),
                    const Text(
                      'SOLVED',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
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
                    ),
                    const Text(
                      'APPLIED',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Total tasks/problems tracked
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
                    ),
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
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

  /// Displays the current consistency streak based on historical activity
  Widget _buildStreakCard(Map<String, int> activityData) {
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
                ),
                const Text(
                  'Consistency is your superpower',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a GitHub-style heatmap visualize the user's daily progress
  Widget _buildActivityHeatmap(Map<String, int> activityData) {
    final convertedData = <DateTime, int>{};
    
    // Transforming string keys from Firestore back into DateTime objects for the heatmap
    activityData.forEach(
        (key, value) => convertedData[DateTime.parse(key)] = value);

    return AppCard(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
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
      ),
    );
  }

  /// Displays navigation shortcuts to commonly used screens
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

  /// Individual action row helper for the Quick Actions section
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
        // FIXED: was hardcoded Icons.add — now correctly uses the passed icon
        child: Icon(icon, color: AppColors.accent, size: 20),
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
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}
