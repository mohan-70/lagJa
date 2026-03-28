import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/dsa_tracker_screen.dart';
import '../screens/companies_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/roadmap_screen.dart';
import '../screens/leaderboard_screen.dart'; // Add this line
import '../services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  List<Widget> get _screens => [
    const DashboardScreen(),
    const DSATrackerScreen(),
    const CompaniesScreen(),
    const NotesScreen(),
    // 5th tab — AI Roadmap Generator
    RoadmapScreen(
      onSaved: () => setState(() => _currentIndex = 1), // jump to DSA tab
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          border: Border(
            top: BorderSide(color: Color(0xFF38383A), width: 0.3),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF6C63FF),
          unselectedItemColor: const Color(0xFF8E8E93),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.code_outlined),
              activeIcon: Icon(Icons.code),
              label: 'DSA',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Companies',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.note_alt_outlined),
              activeIcon: Icon(Icons.note_alt),
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Roadmap',
            ),
          ],
        ),
      ),
    );
  }

}
