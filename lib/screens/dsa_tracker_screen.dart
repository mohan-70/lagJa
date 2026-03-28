import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/dsa_problem.dart';
import '../services/firestore_service.dart';

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

  static const _purple = Color(0xFF6C63FF);
  static const _bg = Color(0xFF000000);
  static const _card = Color(0xFF1C1C1E);
  static const _border = Color(0xFF2C2C2E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('DSA Tracker'),
        shape: const Border(bottom: BorderSide(color: Color(0xFF38383A), width: 0.3)),
        actions: [
          IconButton(onPressed: _showAddProblemBottomSheet, icon: const Icon(Icons.add_rounded, color: _purple)),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: StreamBuilder<List<DSAProblem>>(
              stream: _firestoreService.getDSAProblems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _purple));
                final problems = snapshot.data ?? [];
                final filtered = _filterProblems(problems);
                if (filtered.isEmpty) return _buildEmptyState();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  children: [
                    _buildSectionHeader('${filtered.length} PROBLEMS'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.5)),
                      child: Column(
                        children: List.generate(filtered.length, (i) {
                          final p = filtered[i];
                          return Column(
                            children: [
                              _buildProblemItem(p),
                              if (i < filtered.length - 1) const Divider(color: Color(0xFF38383A), height: 0.5, indent: 16),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: const InputDecoration(hintText: 'Search problems...', prefixIcon: Icon(Icons.search_rounded, color: _textSecondary, size: 20)),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FilterOption.values.map((f) {
                final isSelected = _currentFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.name.toUpperCase()),
                    selected: isSelected,
                    onSelected: (s) => setState(() => _currentFilter = f),
                    backgroundColor: _card,
                    selectedColor: _purple,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : _textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? _purple : _border, width: 0.5)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemItem(DSAProblem p) {
    Color dColor = const Color(0xFFFF9F0A);
    final d = p.difficulty.toLowerCase();
    if (d == 'easy') dColor = const Color(0xFF30D158);
    if (d == 'hard') dColor = const Color(0xFFFF453A);

    return InkWell(
      onLongPress: () => _showDeleteConfirmation(p),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Checkbox(
              value: p.isSolved,
              activeColor: const Color(0xFF30D158),
              onChanged: (v) => _toggleSolved(p),
              shape: const CircleBorder(),
              side: const BorderSide(color: Color(0xFF38383A), width: 1.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: TextStyle(color: p.isSolved ? _textSecondary : Colors.white, fontSize: 17, fontWeight: FontWeight.w500, decoration: p.isSolved ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(p.difficulty.toUpperCase(), style: TextStyle(color: dColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text(p.topic, style: const TextStyle(color: _textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.code_off_rounded, size: 64, color: _border),
          const SizedBox(height: 16),
          const Text('No problems found.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          Text('Try a different filter or search.', style: TextStyle(color: _textSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  Future<void> _toggleSolved(DSAProblem p) async {
    try {
      final updated = p.copyWith(isSolved: !p.isSolved);
      await _firestoreService.updateDSAProblem(updated);
      if (updated.isSolved) {
        final today = DateTime.now();
        await _firestoreService.incrementActivity('${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
      }
    } catch (_) {}
  }

  void _showDeleteConfirmation(DSAProblem p) {
    showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: _card, title: const Text('Delete Problem'), content: Text('Remove "${p.title}"?'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _textSecondary))), TextButton(onPressed: () async { Navigator.pop(context); await _firestoreService.deleteDSAProblem(p.id); }, child: const Text('Delete', style: TextStyle(color: Color(0xFFFF453A))))]));
  }

  void _showAddProblemBottomSheet() {
    final titleC = TextEditingController();
    final topicC = TextEditingController();
    String diff = 'Medium';
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: _bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => StatefulBuilder(builder: (c, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 16, right: 16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('New Problem', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)), const SizedBox(height: 24), TextField(controller: titleC, decoration: const InputDecoration(hintText: 'Problem Title')), const SizedBox(height: 16), TextField(controller: topicC, decoration: const InputDecoration(hintText: 'Topic (e.g. Arrays)')), const SizedBox(height: 24), _buildSectionHeader('DIFFICULTY'), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['Easy', 'Medium', 'Hard'].map((d) { final sel = diff == d; return Expanded(child: GestureDetector(onTap: () => setS(() => diff = d), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: sel ? _purple : _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? _purple : _border)), child: Center(child: Text(d, style: TextStyle(color: sel ? Colors.white : _textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal)))))); }).toList()), const SizedBox(height: 32), SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () async { if (titleC.text.isEmpty) return; await _firestoreService.addDSAProblem(DSAProblem(id: _uuid.v4(), topic: topicC.text, title: titleC.text, difficulty: diff, isSolved: false, createdAt: DateTime.now())); Navigator.pop(context); }, child: const Text('Add Problem'))), const SizedBox(height: 32)]))));
  }

  List<DSAProblem> _filterProblems(List<DSAProblem> problems) {
    return problems.where((p) {
      if (_searchQuery.isNotEmpty && !p.title.toLowerCase().contains(_searchQuery) && !p.topic.toLowerCase().contains(_searchQuery)) return false;
      switch (_currentFilter) {
        case FilterOption.all: return true;
        case FilterOption.easy: return p.difficulty.toLowerCase() == 'easy';
        case FilterOption.medium: return p.difficulty.toLowerCase() == 'medium';
        case FilterOption.hard: return p.difficulty.toLowerCase() == 'hard';
        case FilterOption.solved: return p.isSolved;
        case FilterOption.unsolved: return !p.isSolved;
      }
    }).toList();
  }
}
