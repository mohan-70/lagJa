import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants/api_constants.dart';
import '../models/roadmap_problem.dart';
import '../services/firestore_service.dart';

// ---------------------------------------------------------------------------
// RoadmapScreen — AI-powered DSA Roadmap Generator
// Uses Google Gemini 2.0 Flash to build a personalised prep plan and lets the
// user save the result directly to the DSA Tracker.
// ---------------------------------------------------------------------------

class RoadmapScreen extends StatefulWidget {
  /// Called when the user taps "Save to DSA Tracker" and saving succeeds.
  /// The parent (MainScreen) uses this to navigate back to the DSA tab.
  final VoidCallback? onSaved;

  const RoadmapScreen({super.key, this.onSaved});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

// ─── Screen state machine ────────────────────────────────────────────────────
enum _ScreenState { form, loading, result }

class _RoadmapScreenState extends State<RoadmapScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();

  // ── State ─────────────────────────────────────────────────────────────────
  _ScreenState _state = _ScreenState.form;
  List<RoadmapProblem> _problems = [];

  // ── Form fields ───────────────────────────────────────────────────────────
  final TextEditingController _companyController = TextEditingController();
  String _selectedRole = 'SDE';
  Set<String> _selectedWeeks = {'4 weeks'};
  Set<String> _selectedLevel = {'Beginner'};

  // Saved form values — shown in the result header card
  String _savedCompany = '';
  String _savedRole = '';

  // ── Constants ─────────────────────────────────────────────────────────────
  static const _purple = Color(0xFF6C63FF);
  static const _bg = Color(0xFF0F0F1A);
  static const _card = Color(0xFF1A1A2E);

  static const List<String> _roles = [
    'Flutter Developer',
    'Full Stack Developer',
    'SDE',
    'Data Analyst',
    'Any Internship',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  // ── Gemini API ─────────────────────────────────────────────────────────────

  /// Builds the prompt and calls the Gemini API.
  Future<void> _generateRoadmap() async {
    final company = _companyController.text.trim();
    if (company.isEmpty) {
      _showSnackBar('Please enter a target company.');
      return;
    }

    final weekStr = _selectedWeeks.first;
    final levelStr = _selectedLevel.first;

    setState(() {
      _state = _ScreenState.loading;
      _savedCompany = company;
      _savedRole = _selectedRole;
    });

    // ── Build prompt ──────────────────────────────────────────────────────
    final prompt = '''You are a placement preparation expert for Indian BCA/BTech students. '''
        '''Generate a DSA roadmap for a student targeting $company for the role of $_selectedRole. '''
        '''They have $weekStr and are at $levelStr level. '''
        '''Return ONLY a JSON array with no markdown, no explanation, no backticks. '''
        '''Format: [{"topic":"","title":"","difficulty":"","whyImportant":""}]. '''
        '''Generate exactly 15-20 problems ordered by learning sequence. '''
        '''difficulty must be Easy, Medium, or Hard only.''';

    try {
      // ── HTTP POST to Gemini ─────────────────────────────────────────────
      final response = await http.post(
        Uri.parse(ApiConstants.geminiApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        // Log the error body locally for debugging
        final errorBody = response.body;
        // Optionally parse for error message
        String msg = 'API Error: ${response.statusCode}';
        try {
          final errorData = jsonDecode(errorBody);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            msg = 'API Error: ${errorData['error']['message']}';
          }
        } catch (_) {}
        throw Exception(msg);
      }

      // ── Parse Gemini response ───────────────────────────────────────────
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText =
          data['candidates'][0]['content']['parts'][0]['text'] as String;

      // Strip any accidental markdown fences Gemini might add despite instructions
      final cleaned = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final List<dynamic> jsonList = jsonDecode(cleaned);
      final problems =
          jsonList.map((e) => RoadmapProblem.fromMap(e as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _problems = problems;
          _state = _ScreenState.result;
        });
      }
    } catch (e) {
      // ── Error handling ──────────────────────────────────────
      if (mounted) {
        setState(() => _state = _ScreenState.form);
        
        final errorStr = e.toString().replaceFirst('Exception: ', '');
        if (errorStr.contains('jsonDecode') || errorStr.contains('FormatException')) {
          _showSnackBar('Format error. Please try again.');
        } else {
          // Show the actual error message like API Error: [details from Gemini]
          _showSnackBar(errorStr);
        }
      }
    }
  }

  // ── Firestore save ─────────────────────────────────────────────────────────

  /// Saves all generated problems to Firestore as regular DSAProblem documents
  /// so they appear immediately in the DSA Tracker screen.
  Future<void> _saveToTracker() async {
    try {
      for (final problem in _problems) {
        final map = problem.toMap();
        await _firestoreService.addDSAProblemRaw(_uuid.v4(), map);
      }

      if (mounted) {
        _showSnackBar('Roadmap saved to DSA Tracker ✅');
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save roadmap: ${e.toString()}');
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF4CAF50);
      case 'hard':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFF9800);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Roadmap Generator ✨',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Show "Regenerate" button only in result state
        actions: _state == _ScreenState.result
            ? [
                TextButton.icon(
                  onPressed: () => setState(() => _state = _ScreenState.form),
                  icon: const Icon(Icons.refresh, color: _purple, size: 18),
                  label: const Text(
                    'Regenerate',
                    style: TextStyle(color: _purple),
                  ),
                ),
              ]
            : null,
      ),
      // ── Body switches between form / loading / result states ─────────────
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _state == _ScreenState.result
            ? _buildResultView()
            : _buildFormView(),
      ),
    );
  }

  // ── Form & Loading view ───────────────────────────────────────────────────

  Widget _buildFormView() {
    final isLoading = _state == _ScreenState.loading;

    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          const Text(
            'Let AI build your prep plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Answer 3 quick questions and get a personalised\nDSA roadmap tailored to your dream company.',
            style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
          ),

          const SizedBox(height: 32),

          // ── Q1: Target Company ───────────────────────────────────────────
          _sectionLabel('🏢  Target Company'),
          const SizedBox(height: 8),
          TextField(
            controller: _companyController,
            enabled: !isLoading,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Google, TCS, Startup',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.business_center_outlined, color: _purple),
              filled: true,
              fillColor: _card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _purple, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Q2: Job Role (Dropdown) ────────────────────────────────────
          _sectionLabel('💼  Job Role'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            items: _roles
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: isLoading ? null : (v) => setState(() => _selectedRole = v!),
            dropdownColor: _card,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.work_outline, color: _purple),
              filled: true,
              fillColor: _card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Q3: Weeks Available (Segmented buttons) ──────────────────
          _sectionLabel('📅  Weeks Available'),
          const SizedBox(height: 10),
          _buildSegmentedRow(
            options: const ['2 weeks', '4 weeks', '8 weeks'],
            selected: _selectedWeeks,
            enabled: !isLoading,
            onChanged: (v) => setState(() => _selectedWeeks = v),
          ),

          const SizedBox(height: 24),

          // ── Q4: Current Level (Segmented buttons) ────────────────────
          _sectionLabel('🎓  Current Level'),
          const SizedBox(height: 10),
          _buildSegmentedRow(
            options: const ['Beginner', 'Intermediate'],
            selected: _selectedLevel,
            enabled: !isLoading,
            onChanged: (v) => setState(() => _selectedLevel = v),
          ),

          const SizedBox(height: 36),

          // ── Generate button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _generateRoadmap,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                disabledBackgroundColor: _purple.withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Generate My Roadmap 🚀',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          // ── Loading subtitle ─────────────────────────────────────────
          if (isLoading) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Gemini is building your roadmap...',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Result view ────────────────────────────────────────────────────────────

  Widget _buildResultView() {
    return Column(
      key: const ValueKey('result'),
      children: [
        // ── Success header card ──────────────────────────────────────────
        _buildSuccessHeader(),

        // ── Problems list ────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            itemCount: _problems.length,
            itemBuilder: (ctx, i) => _buildProblemCard(i),
          ),
        ),

        // ── Save button ──────────────────────────────────────────────────
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3D38A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Roadmap is Ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_savedCompany · $_savedRole',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_problems.length} problems ordered by learning sequence',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard(int index) {
    final problem = _problems[index];
    final diffColor = _difficultyColor(problem.difficulty);

    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: problem.isSolved
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : Colors.grey[800]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: topic chip + difficulty chip + checkbox ────────
              Row(
                children: [
                  // Topic chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: _purple),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      problem.topic,
                      style: const TextStyle(
                        color: _purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Difficulty chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.15),
                      border: Border.all(color: diffColor),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      problem.difficulty,
                      style: TextStyle(
                        color: diffColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Mark solved checkbox
                  Transform.scale(
                    scale: 1.1,
                    child: Checkbox(
                      value: problem.isSolved,
                      activeColor: const Color(0xFF4CAF50),
                      checkColor: Colors.white,
                      side: BorderSide(color: Colors.grey[600]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) {
                        setCardState(() => problem.isSolved = v ?? false);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Problem title ────────────────────────────────────────────
              Text(
                problem.title,
                style: TextStyle(
                  color: problem.isSolved
                      ? Colors.grey[500]
                      : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: problem.isSolved
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),

              const SizedBox(height: 6),

              // ── Why important ────────────────────────────────────────────
              Text(
                problem.whyImportant,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: _bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _saveToTracker,
          icon: const Icon(Icons.save_alt_rounded),
          label: const Text(
            'Save to DSA Tracker',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// A custom segmented button row using styled ChoiceChips to match the
  /// dark theme without any Material 3 SegmentedButton colour limitations.
  Widget _buildSegmentedRow({
    required List<String> options,
    required Set<String> selected,
    required bool enabled,
    required ValueChanged<Set<String>> onChanged,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = selected.contains(opt);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: enabled
                  ? () => onChanged({opt})
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _purple : _card,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? _purple : Colors.grey[700]!,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
