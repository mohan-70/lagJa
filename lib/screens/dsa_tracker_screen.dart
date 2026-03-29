import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/dsa_problem.dart';
import '../services/firestore_service.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/difficulty_chip.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/ui_constants.dart';

enum FilterOption { all, easy, medium, hard, solved, unsolved }

class DSATrackerScreen extends StatefulWidget {
  const DSATrackerScreen({super.key});
  @override
  State<DSATrackerScreen> createState() => _DSATrackerScreenState();
}

class _DSATrackerScreenState extends State<DSATrackerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();
  FilterOption _currentFilter = FilterOption.all;
  String _searchQuery = '';
  final Map<String, bool> _optimisticSolved = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('DSA Tracker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: StreamBuilder<List<DSAProblem>>(
              stream: _firestoreService.getDSAProblems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent));
                }
                final problems = snapshot.data ?? [];
                final filtered = _filterProblems(problems);
                if (filtered.isEmpty) return _buildEmptyState();
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _buildProblemCard(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProblemBottomSheet,
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search problems...',
                prefixIcon: Icon(Icons.search, color: AppColors.accent),
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: FilterOption.values.map((f) {
              final isSelected = _currentFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _currentFilter = f),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : AppColors.surface,
                      border: Border.all(
                        color: isSelected ? AppColors.accent : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f.name.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProblemCard(DSAProblem p) {
    Color dColor;
    switch (p.difficulty.toLowerCase()) {
      case 'easy': dColor = AppColors.success; break;
      case 'hard': dColor = AppColors.error; break;
      default: dColor = AppColors.warning;
    }

    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(p),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: dColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.topic,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    DifficultyChip(difficulty: p.difficulty),
                    const SizedBox(width: 4),
                    Checkbox(
                      value: _optimisticSolved[p.id] ?? p.isSolved,
                      activeColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (v) => _toggleSolved(p),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code, size: 64, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'No problems yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Start grinding! 💪',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSolved(DSAProblem p) async {
    final bool newSolvedState = !p.isSolved;
    setState(() {
      _optimisticSolved[p.id] = newSolvedState;
    });

    try {
      final updated = p.copyWith(isSolved: newSolvedState);
      await _firestoreService.updateDSAProblem(updated);
      
      setState(() {
        _optimisticSolved.remove(p.id); // Clear local map once network syncs
      });
      
      if (updated.isSolved) {
        final today = DateTime.now();
        await _firestoreService.incrementActivity(
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
      }
    } catch (_) {
      // Revert if saving fails
      setState(() => _optimisticSolved.remove(p.id));
    }
  }

  void _showDeleteConfirmation(DSAProblem p) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Problem'),
        content: Text('Remove "${p.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestoreService.deleteDSAProblem(p.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddProblemBottomSheet() {
    final titleC = TextEditingController();
    final topicC = TextEditingController();
    String diff = 'Medium';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 16,
            right: 16,
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
                    color: const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('New Problem',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              TextField(
                controller: titleC,
                decoration: const InputDecoration(hintText: 'Problem Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: topicC,
                decoration: const InputDecoration(hintText: 'Topic (e.g. Arrays)'),
              ),
              const SectionHeader('DIFFICULTY'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Easy', 'Medium', 'Hard'].map((d) {
                  final sel = diff == d;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => diff = d),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.accent : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppColors.accent : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              color: sel ? Colors.white : AppColors.textSecondary,
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleC.text.isEmpty) return;
                    await _firestoreService.addDSAProblem(DSAProblem(
                      id: _uuid.v4(),
                      topic: topicC.text,
                      title: titleC.text,
                      difficulty: diff,
                      isSolved: false,
                      createdAt: DateTime.now(),
                    ));
                    if (c.mounted) {
                      Navigator.pop(c);
                    }
                  },
                  child: const Text('Add Problem'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  List<DSAProblem> _filterProblems(List<DSAProblem> problems) {
    return problems.where((p) {
      if (_searchQuery.isNotEmpty &&
          !p.title.toLowerCase().contains(_searchQuery) &&
          !p.topic.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      switch (_currentFilter) {
        case FilterOption.all: return true;
        case FilterOption.easy: return p.difficulty.toLowerCase() == 'easy';
        case FilterOption.medium: return p.difficulty.toLowerCase() == 'medium';
        case FilterOption.hard: return p.difficulty.toLowerCase() == 'hard';
        case FilterOption.solved: return (_optimisticSolved[p.id] ?? p.isSolved);
        case FilterOption.unsolved: return !(_optimisticSolved[p.id] ?? p.isSolved);
      }
    }).toList();
  }
}

