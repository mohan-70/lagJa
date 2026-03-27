import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/dsa_problem.dart';
import '../services/firestore_service.dart';

enum FilterOption {
  all,
  easy,
  medium,
  hard,
  solved,
  unsolved,
}

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        title: const Text(
          'DSA Tracker',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showAddProblemBottomSheet,
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Add Problem',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          _buildSearchAndFilter(),
          
          // Problems List
          Expanded(
            child: StreamBuilder<List<DSAProblem>>(
              stream: _firestoreService.getDSAProblems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final problems = snapshot.data ?? [];
                final filteredProblems = _filterProblems(problems);

                if (filteredProblems.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProblems.length,
                  itemBuilder: (context, index) {
                    final problem = filteredProblems[index];
                    return _buildProblemCard(problem);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search problems...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          
          const SizedBox(height: 16),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FilterOption.values.map((filter) {
                final isSelected = _currentFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter.name.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _currentFilter = filter;
                      });
                    },
                    backgroundColor: const Color(0xFF1A1A2E),
                    selectedColor: const Color(0xFF6C63FF),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[600]!,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.code_off,
              size: 60,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No DSA Problems Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding problems to track your progress',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddProblemBottomSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add First Problem'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard(DSAProblem problem) {
    final difficultyColor = _getDifficultyColor(problem.difficulty);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: problem.isSolved 
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : Colors.grey[600]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Difficulty Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: difficultyColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: difficultyColor),
                ),
                child: Text(
                  problem.difficulty.toUpperCase(),
                  style: TextStyle(
                    color: difficultyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Solved Badge
              if (problem.isSolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'SOLVED',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Problem Title
          Text(
            problem.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Topic
          Row(
            children: [
              Icon(Icons.tag, color: Colors.grey[400], size: 16),
              const SizedBox(width: 4),
              Text(
                problem.topic,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              // Mark as Solved/Unsolved
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleSolved(problem),
                  icon: Icon(
                    problem.isSolved ? Icons.undo : Icons.check,
                    size: 18,
                  ),
                  label: Text(
                    problem.isSolved ? 'Mark Unsolved' : 'Mark Solved',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: problem.isSolved 
                        ? Colors.grey[600]
                        : const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Delete Button
              IconButton(
                onPressed: () => _showDeleteConfirmation(problem),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'hard':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  List<DSAProblem> _filterProblems(List<DSAProblem> problems) {
    var filtered = problems.where((problem) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = problem.title.toLowerCase().contains(_searchQuery) ||
            problem.topic.toLowerCase().contains(_searchQuery);
        if (!matchesSearch) return false;
      }
      
      // Status filter
      switch (_currentFilter) {
        case FilterOption.all:
          return true;
        case FilterOption.easy:
          return problem.difficulty.toLowerCase() == 'easy';
        case FilterOption.medium:
          return problem.difficulty.toLowerCase() == 'medium';
        case FilterOption.hard:
          return problem.difficulty.toLowerCase() == 'hard';
        case FilterOption.solved:
          return problem.isSolved;
        case FilterOption.unsolved:
          return !problem.isSolved;
      }
    }).toList();
    
    return filtered;
  }

  void _showAddProblemBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAddProblemBottomSheet(),
    );
  }

  Widget _buildAddProblemBottomSheet() {
    final titleController = TextEditingController();
    final topicController = TextEditingController();
    String selectedDifficulty = 'Medium';

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add DSA Problem',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title Field
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Problem Title',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              
              const SizedBox(height: 16),
              
              // Topic Field
              TextField(
                controller: topicController,
                decoration: InputDecoration(
                  labelText: 'Topic',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              
              const SizedBox(height: 16),
              
              // Difficulty Dropdown
              DropdownButtonFormField<String>(
                initialValue: selectedDifficulty,
                decoration: InputDecoration(
                  labelText: 'Difficulty',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                items: ['Easy', 'Medium', 'Hard'].map((difficulty) {
                  return DropdownMenuItem(
                    value: difficulty,
                    child: Text(difficulty),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDifficulty = value!;
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              // Add Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        topicController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final problem = DSAProblem(
                      id: _uuid.v4(),
                      topic: topicController.text.trim(),
                      title: titleController.text.trim(),
                      difficulty: selectedDifficulty,
                      isSolved: false,
                      createdAt: DateTime.now(),
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    try {
                      await _firestoreService.addDSAProblem(problem);
                      if (mounted) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Problem added successfully!'),
                            backgroundColor: Color(0xFF4CAF50),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to add problem: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Problem',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleSolved(DSAProblem problem) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updatedProblem = problem.copyWith(isSolved: !problem.isSolved);
      await _firestoreService.updateDSAProblem(updatedProblem);

      if (updatedProblem.isSolved) {
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await _firestoreService.incrementActivity(dateStr);
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              problem.isSolved ? 'Marked as unsolved' : 'Marked as solved! 🎉',
            ),
            backgroundColor: problem.isSolved ? Colors.orange : const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update problem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(DSAProblem problem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Delete Problem',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${problem.title}"?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9E9E9E)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await _firestoreService.deleteDSAProblem(problem.id);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Problem deleted'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete problem: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
