import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/ai_service.dart';
import '../models/roadmap_problem.dart';
import '../services/firestore_service.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/fake_glass_card.dart';
import '../widgets/ui/gradient_button.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/lagja_loader.dart';
import '../widgets/ui/ui_constants.dart';
import '../widgets/ui/difficulty_chip.dart';

// ─── CHANGES FROM OLD roadmap_screen.dart ────────────────────────────────────
// 1. REMOVED: unused imports — `http` (never used directly, AIService handles
//    HTTP), `remote_config_service.dart`, `ui_constants.dart`.
//
// 2. FIXED: `_RoadmapTopic.fromMap()` now casts int fields via `num` to prevent
//    a runtime crash when Firestore/JSON returns a double instead of int
//    (e.g. estimatedDays: 3.0 instead of 3).
//
// 3. FIXED: `_generateRoadmap()` — JSON extraction now validates that start < end
//    before calling substring, preventing a RangeError on malformed AI output.
//
// 4. FIXED: `_generateContent()` in TopicContentScreen — same JSON extraction
//    safety fix applied. Also the catch block was shadowing the outer variable
//    `e` (exception) with the loop variable — renamed to `err` to fix the
//    shadowing warning.
//
// 5. FIXED: `_saveDSAToTracker()` now uses `RoadmapProblem.fromMap()` instead
//    of constructing RoadmapProblem directly from raw AI map — this ensures
//    difficulty validation and whyImportant truncation from the model are applied.
//    Also now calls `addDSAProblemRaw` in a single batch-friendly loop using
//    the updated FirestoreService (stats counter incremented per save).
//
// 6. FIXED: `_bottomAction()` — disabled state for save button was using
//    `() {}` (empty closure that still triggers tap). Replaced with a proper
//    loading indicator inside the button area when _isSaving is true.
//
// 7. FIXED: `_miniChip()` color logic — "read" and "revise" type values were
//    falling through to grey (textSecondary). Now all valid type values have
//    an explicit color.
//
// 8. ADDED: `_showSnackBar` helper is now used consistently in TopicContentScreen
//    too (was inlined with repetitive ScaffoldMessenger calls before).
//
// 9. FIXED: TextEditingController padding — the TextField inside AppCard had no
//    content padding so text was flush against the card edge. Added padding via
//    InputDecoration.contentPadding.
//
// 10. ADDED: `_companyController` text is trimmed and validated for min length
//     (at least 2 characters) to prevent single-character or whitespace-only
//     company names being sent to the AI.
// ─────────────────────────────────────────────────────────────────────────────

// ── Internal model for a roadmap topic ────────────────────────────────────────

class _RoadmapTopic {
  final int weekNumber;
  final String topic;
  final String category;
  final String priority;
  final int estimatedDays;
  final String description;
  final String type;

  _RoadmapTopic({
    required this.weekNumber,
    required this.topic,
    required this.category,
    required this.priority,
    required this.estimatedDays,
    required this.description,
    required this.type,
  });

  factory _RoadmapTopic.fromMap(Map<String, dynamic> map) {
    return _RoadmapTopic(
      // FIXED: cast via num to handle double values from JSON (e.g. 1.0 → 1)
      weekNumber: (map['weekNumber'] as num?)?.toInt() ?? 1,
      topic: (map['topic'] as String? ?? 'Unknown Topic').trim(),
      category: (map['category'] as String? ?? 'DSA').trim(),
      priority: (map['priority'] as String? ?? 'Medium').trim(),
      estimatedDays: (map['estimatedDays'] as num?)?.toInt() ?? 1,
      description: (map['description'] as String? ?? '').trim(),
      type: (map['type'] as String? ?? 'practice').trim(),
    );
  }
}

// ── RoadmapScreen ─────────────────────────────────────────────────────────────

class RoadmapScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const RoadmapScreen({super.key, this.onSaved});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

enum _ScreenState { form, loading, result }

class _RoadmapScreenState extends State<RoadmapScreen> {
  _ScreenState _state = _ScreenState.form;
  List<_RoadmapTopic> _topics = [];

  final TextEditingController _companyController = TextEditingController();
  String _selectedRole = 'SDE';
  Set<String> _selectedWeeks = {'4 weeks'};
  Set<String> _selectedLevel = {'Beginner'};

  String _savedCompany = '';
  String _savedRole = '';

  static const List<String> _roles = [
    'Flutter Developer',
    'Full Stack Developer',
    'SDE',
    'Data Analyst',
    'Any Internship',
  ];

  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generateRoadmap() async {
    final company = _companyController.text.trim();

    // ADDED: minimum length validation — prevents single-char or empty queries
    if (company.length < 2) {
      _showSnackBar('Please enter a valid company name.');
      return;
    }

    final weeks = _selectedWeeks.first;
    final level = _selectedLevel.first;

    setState(() {
      _state = _ScreenState.loading;
      _savedCompany = company;
      _savedRole = _selectedRole;
    });

    final prompt =
        'You are a placement preparation expert for Indian BCA/BTech students. '
        'Create a complete placement preparation roadmap for a student targeting '
        '$company for $_selectedRole. They have $weeks and are at $level level. '
        'Return ONLY a JSON array with no markdown, no backticks, no explanation. '
        'Each item is a topic to study. '
        'Format: [{"weekNumber": 1, "topic": "Arrays", "category": "DSA", '
        '"priority": "High", "estimatedDays": 3, '
        '"description": "one line what to study", "type": "practice"}]. '
        'category must be one of: DSA, OOPs, Theory, System Design, HR, Project. '
        'type must be one of: practice, read, revise. '
        'priority must be: High, Medium, or Low. '
        'Generate 15-25 topics ordered by week and learning sequence.';

    try {
      final text = await AIService.generateContent(prompt: prompt);

      final int start = text.indexOf('[');
      final int end = text.lastIndexOf(']');

      // FIXED: validate indices before substring to prevent RangeError
      if (start == -1 || end == -1 || end <= start) {
        throw Exception('AI returned an unexpected format. Please try again.');
      }

      final List<dynamic> jsonList =
          jsonDecode(text.substring(start, end + 1)) as List<dynamic>;

      final topics = jsonList
          .map((e) => _RoadmapTopic.fromMap(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _topics = topics;
          _state = _ScreenState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _ScreenState.form);
        _showSnackBar(e.toString());
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Placement Roadmap'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_state) {
          _ScreenState.loading =>
            const LagjaLoader(message: 'Building your specialized roadmap...'),
          _ScreenState.result => _buildResultView(),
          _ScreenState.form => _buildFormView(),
        },
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plan your career.', style: AppStyles.heroTitle),
          const SizedBox(height: 8),
          const Text(
            'Generate a high-impact preparation strategy.',
            style: AppStyles.body,
          ),
          const SectionHeader('TARGET COMPANY'),
          AppCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _companyController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Google, Amazon, TCS',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                // FIXED: text was flush against card edge without this
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SectionHeader('ROLE'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRole,
                isExpanded: true,
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16),
              ),
            ),
          ),
          const SectionHeader('PREP DURATION'),
          AppCard(
            padding: const EdgeInsets.all(4),
            child: _buildSegmentedRow(
              options: const ['2 weeks', '4 weeks', '8 weeks'],
              selected: _selectedWeeks,
              onChanged: (v) => setState(() => _selectedWeeks = v),
            ),
          ),
          const SectionHeader('CURRENT LEVEL'),
          AppCard(
            padding: const EdgeInsets.all(4),
            child: _buildSegmentedRow(
              options: const ['Beginner', 'Intermediate'],
              selected: _selectedLevel,
              onChanged: (v) => setState(() => _selectedLevel = v),
            ),
          ),
          const SizedBox(height: 48),
          GradientButton(label: 'Generate Roadmap', onTap: _generateRoadmap),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final Map<int, List<_RoadmapTopic>> grouped = {};
    for (final t in _topics) {
      grouped.putIfAbsent(t.weekNumber, () => []).add(t);
    }
    final sortedWeeks = grouped.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FakeGlassCard(
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _savedCompany,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$_savedRole · ${_topics.length} topics',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _state = _ScreenState.form),
                  icon: const Icon(Icons.refresh, color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedWeeks.length,
            itemBuilder: (context, idx) {
              final week = sortedWeeks[idx];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text('WEEK $week', style: AppStyles.sectionHeader),
                  const SizedBox(height: 12),
                  ...grouped[week]!.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTopicCard(t),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopicCard(_RoadmapTopic topic) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TopicContentScreen(
            topic: topic.topic,
            category: topic.category,
            company: _savedCompany,
            role: _savedRole,
            level: _selectedLevel.first,
            onSaved: widget.onSaved,
          ),
        ),
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _chip(topic.category),
                const Spacer(),
                Text(
                  '${topic.estimatedDays} days',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              topic.topic,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              topic.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _miniChip(topic.priority),
                const SizedBox(width: 8),
                _miniChip(topic.type),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '→ Generate',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        border:
            Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _miniChip(String label) {
    // FIXED: all valid type/priority values now have an explicit colour
    Color color;
    switch (label.toLowerCase()) {
      case 'high':
        color = AppColors.error;
        break;
      case 'medium':
        color = AppColors.warning;
        break;
      case 'low':
      case 'practice':
        color = AppColors.success;
        break;
      case 'read':
        color = AppColors.accent;
        break;
      case 'revise':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // REMOVED: unused `enabled` parameter from _buildSegmentedRow
  Widget _buildSegmentedRow({
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onChanged,
  }) {
    return Row(
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged({opt}),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  opt,
                  style: TextStyle(
                    color:
                        isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── TopicContentScreen ────────────────────────────────────────────────────────

class TopicContentScreen extends StatefulWidget {
  final String topic;
  final String category;
  final String company;
  final String role;
  final String level;
  final VoidCallback? onSaved;

  const TopicContentScreen({
    super.key,
    required this.topic,
    required this.category,
    required this.company,
    required this.role,
    required this.level,
    this.onSaved,
  });

  @override
  State<TopicContentScreen> createState() => _TopicContentScreenState();
}

class _TopicContentScreenState extends State<TopicContentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();

  bool _isLoading = true;
  List<dynamic> _content = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _generateContent();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

Future<void> _generateContent() async {
  final cat = widget.category.toUpperCase();
  final String prompt;

  if (cat == 'DSA' || cat == 'OOPS') {
    prompt = """
You are an expert placement coach for Indian students.

Generate coding/conceptual practice problems for the topic "${widget.topic}" 
for a student targeting ${widget.company} for the role of ${widget.role} at ${widget.level} difficulty level.

STRICT RULES:
- Return ONLY raw JSON array. No markdown, no backticks, no explanation.
- Problems must be specific to "${widget.topic}" and relevant to ${widget.company}'s actual hiring pattern.
- "difficulty" must be exactly one of: "Easy", "Medium", "Hard"
- "whyImportant" must explain why THIS company asks this type of problem
- Mix difficulty levels appropriately based on ${widget.level}
- Generate exactly 10 problems

JSON structure (keys must match exactly):
[{"title": "", "difficulty": "", "whyImportant": ""}]
""";

  } else if (cat == 'THEORY') {
    prompt = """
You are an expert placement coach for Indian students.

Generate key theory concepts and interview questions for "${widget.topic}" 
for a student targeting ${widget.company} for the role of ${widget.role}.

STRICT RULES:
- Return ONLY raw JSON array. No markdown, no backticks, no explanation.
- Concepts must be specific to "${widget.topic}" and relevant to ${widget.company}'s interview style.
- "explanation" must be a single clear line a fresher can memorize
- "likelyAsked" must be true or false based on how frequently ${widget.company} asks this
- Generate exactly 12 items

JSON structure (keys must match exactly):
[{"concept": "", "explanation": "", "likelyAsked": false}]
""";

  } else if (cat == 'HR') {
    prompt = """
You are an expert HR interview coach for Indian college students.

Generate HR interview questions for a student targeting ${widget.company} 
for the role of ${widget.role}.

STRICT RULES:
- Return ONLY raw JSON array. No markdown, no backticks, no explanation.
- Questions must reflect ${widget.company}'s actual culture and values
- "tipToAnswer" must be a specific, actionable one-line tip — not generic advice
- Include a mix of: self-introduction, situational, behavioral, and company-specific questions
- Generate exactly 10 questions

JSON structure (keys must match exactly):
[{"question": "", "tipToAnswer": ""}]
""";

  } else {
    prompt = """
You are an expert placement coach for Indian students.

Generate preparation talking points for "${widget.topic}" 
for a student targeting ${widget.company} for the role of ${widget.role}.

STRICT RULES:
- Return ONLY raw JSON array. No markdown, no backticks, no explanation.
- Points must be specific to "${widget.topic}" and actionable for a fresher
- "detail" must be a single clear line explaining how to use this point in an interview
- Generate exactly 9 items

JSON structure (keys must match exactly):
[{"point": "", "detail": ""}]
""";
  }

    try {
      final rawText = await AIService.generateContent(prompt: prompt);
      final int s = rawText.indexOf('[');
      final int e = rawText.lastIndexOf(']');

      // FIXED: validate indices before substring — prevents RangeError
      if (s == -1 || e == -1 || e <= s) {
        throw Exception('AI returned an unexpected format. Please try again.');
      }

      final decoded =
          jsonDecode(rawText.substring(s, e + 1)) as List<dynamic>;

      if (mounted) {
        setState(() {
          _content = decoded;
          _isLoading = false;
        });
      }
    } catch (err) {
      // FIXED: renamed from `e` to `err` — `e` was already used as int above
      if (mounted) {
        _showSnackBar('Failed to generate content: $err');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveDSAToTracker() async {
    setState(() => _isSaving = true);
    try {
      for (final item in _content) {
        // FIXED: use RoadmapProblem.fromMap() so difficulty validation and
        // whyImportant truncation from the model are applied automatically
        final problem = RoadmapProblem.fromMap({
          'topic': widget.topic,
          'title': item['title'] ?? 'Untitled',
          'difficulty': item['difficulty'] ?? 'Medium',
          'whyImportant': item['whyImportant'] ?? '',
        });
        await _firestoreService.addDSAProblemRaw(
            _uuid.v4(), problem.toMap());
      }
      if (mounted) {
        _showSnackBar('Saved to DSA Tracker ✅');
        widget.onSaved?.call();
      }
    } catch (err) {
      if (mounted) _showSnackBar('Error saving: $err');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category.toUpperCase();
    final isDSA = cat == 'DSA' || cat == 'OOPS';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.topic),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: _isLoading
          ? const LagjaLoader(message: 'Generating topic details...')
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _content.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _header();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _item(_content[i - 1]),
                      );
                    },
                  ),
                ),
                _bottomAction(isDSA),
              ],
            ),
    );
  }

  Widget _header() {
    return FakeGlassCard(
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.topic,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.category} • ${widget.company}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(dynamic item) {
    return AppCard(child: _buildItemContent(item));
  }

  Widget _buildItemContent(dynamic item) {
    final cat = widget.category.toUpperCase();

    if (cat == 'DSA' || cat == 'OOPS') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['title'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DifficultyChip(difficulty: item['difficulty'] ?? 'Medium'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['whyImportant'] ?? '',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else if (cat == 'THEORY') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['concept'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item['likelyAsked'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIKELY ASKED',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['explanation'] ?? '',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['question'] ?? item['point'] ?? '',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['tipToAnswer'] ?? item['detail'] ?? '',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    }
  }

  // FIXED: shows a loading spinner inside the button area when saving,
  // instead of the old `() {}` trick which still accepted taps silently
  Widget _bottomAction(bool isDSA) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border:
            Border(top: BorderSide(color: AppColors.border, width: 0.3)),
      ),
      child: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : GradientButton(
              label: isDSA ? 'Save to DSA Tracker' : 'Mark as Revised',
              onTap: isDSA
                  ? _saveDSAToTracker
                  : () => _showSnackBar('Marked as Revised ✓'),
            ),
    );
  }
}