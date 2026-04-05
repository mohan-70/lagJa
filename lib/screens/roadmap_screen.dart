// RoadmapScreen: An advanced AI-driven personalized preparation assistant.
// It classifies target companies into tiers, performs gap analysis on user skills,
// and generates a strictly ordered learning sequence tailored to specific roles.
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
import '../widgets/ui/ui_constants.dart';
import '../widgets/ui/shimmer_loader.dart';
import '../widgets/ui/lagja_loader.dart';
import '../widgets/ui/difficulty_chip.dart';

// ─── Internal Data Models ───

/// Represents a single topic or study item within the generated roadmap
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
  // ─── State & Initialization ───

  _ScreenState _state = _ScreenState.form;
  List<_RoadmapTopic> _topics = [];

  final TextEditingController _companyController = TextEditingController();
  String _selectedRole = 'SDE';
  Set<String> _selectedWeeks = {'4 weeks'};
  Set<String> _selectedLevel = {'Beginner'};

  // Detailed user assessment fields for gap analysis
  Set<String> _selectedLeetCode = {'0-50'};
  Set<String> _comfortableTopics = {};
  Set<String> _hasProjects = {'No'};

  static const List<String> _topicOptions = [
    'Arrays',
    'Linked List',
    'OOPs',
    'DBMS',
    'OS',
    'CN',
    'None',
  ];

  String _savedCompany = '';
  String _savedRole = '';

  static const List<String> _roles = [
    'Flutter Developer',
    'Full Stack Developer',
    'SDE',
    'Data Analyst',
    'Any Internship',
  ];

  // ── Company tier classification ─────────────────────────────────────────
  static const _massRecruiters = {
    'tcs', 'infosys', 'wipro', 'cognizant', 'hcl',
    'tech mahindra', 'capgemini', 'accenture', 'cts',
  };
  static const _productCompanies = {
    'google', 'amazon', 'microsoft', 'adobe', 'flipkart',
    'apple', 'meta', 'netflix', 'uber', 'atlassian',
    'oracle', 'intuit', 'salesforce', 'goldman sachs',
    'de shaw', 'tower research', 'samsung', 'qualcomm',
    'nvidia', 'paypal', 'linkedin', 'twitter',
  };

  // ─── Business Logic (Tiering & Prompts) ───

  /// Categorizes companies into broad difficulty tiers to adjust AI expectations
  String _classifyTier(String company) {
    final c = company.toLowerCase().trim();
    if (_massRecruiters.any((m) => c.contains(m))) return 'mass_recruiter';
    if (_productCompanies.any((p) => c.contains(p))) return 'product';
    return 'mid_tier';
  }
  // ────────────────────────────────────────────────────────────────────────

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

  /// Constructs a context-rich prompt for the AI including tier rules, gap analysis, and dependency ordering
  String _buildRoadmapPrompt({
    required String company,
    required String role,
    required String weeks,
    required String level,
    required String leetCode,
    required Set<String> comfortableIn,
    required bool hasProjects,
  }) {
    final tier = _classifyTier(company);

    // ── Tier-specific rules ──────────────────────────────────────────────
    String tierRules;
    switch (tier) {
      case 'mass_recruiter':
        tierRules = '''
COMPANY TIER: Mass Recruiter ($company — same category as TCS, Infosys, Wipro).
Focus areas:
- Aptitude & Logical Reasoning (MUST include as separate topics)
- Basic DSA: Only Easy level — Arrays, Strings, Sorting, Searching
- Core CS theory: OOPs basics, DBMS normalization, OS basics, CN basics
- Verbal & Written communication
- HR round prep
DO NOT include: Hard DSA, System Design, advanced data structures (Graphs, DP, Tries), competitive programming.''';
        break;
      case 'product':
        tierRules = '''
COMPANY TIER: Product / Top Tech ($company — same category as Google, Amazon, Microsoft).
Focus areas:
- DSA: Must include Medium AND Hard problems — cover Arrays, Trees, Graphs, DP, Backtracking, Greedy, Sliding Window, Two Pointers
- System Design: At least 2-3 topics (HLD basics, LLD basics, Design Patterns)
- Behavioral / Leadership Principles round
- Advanced CS theory: OS (scheduling, deadlocks, virtual memory), DBMS (transactions, indexing, query optimization), CN (TCP/IP, HTTP, DNS)
- Time & Space complexity analysis
DO NOT skip hard topics. This company WILL ask them.''';
        break;
      default: // mid_tier
        tierRules = '''
COMPANY TIER: Mid Tier / Startup ($company).
Focus areas:
- DSA: Primarily Medium level, a few Easy warm-ups, rare Hard
- OOPs in depth (classes, inheritance, polymorphism, SOLID)
- Project discussion & presentation
- Basic System Design (1-2 topics max — API design, database schema)
- Core CS theory: moderate depth
- HR round prep
DO NOT over-emphasize System Design or competitive-level hard DSA.''';
    }

    // ── Gap analysis — skip comfortable topics ───────────────────────────
    String gapSection;
    if (comfortableIn.isEmpty || comfortableIn.contains('None')) {
      gapSection =
          'The student has NO comfortable topics — start from absolute basics.';
    } else {
      final comfy = comfortableIn.join(', ');
      gapSection = '''
The student is ALREADY comfortable in: $comfy.
DO NOT generate beginner-level introductory topics for these subjects.
Instead, include only ADVANCED or interview-specific aspects of these topics if relevant.
Focus the roadmap on the GAPS — topics the student has NOT listed.''';
    }

    // ── Role-specific depth ──────────────────────────────────────────────
    String roleDepth;
    switch (role) {
      case 'Flutter Developer':
        roleDepth = '''
ROLE: Flutter Developer.
- Reduce System Design to at most 1 topic (basic API/state management).
- Add Flutter/Dart-specific topics: Widget lifecycle, State management, REST API integration.
- DSA depth: Medium at most — focus on Arrays, Strings, Maps, basic Trees.''';
        break;
      case 'Full Stack Developer':
        roleDepth = '''
ROLE: Full Stack Developer.
- Include both frontend and backend concepts.
- System Design: 2 topics (API design, database schema).
- Include REST APIs, authentication, basic deployment.
- DSA depth: Medium.''';
        break;
      case 'Data Analyst':
        roleDepth = '''
ROLE: Data Analyst.
- Reduce DSA to only Easy-Medium (Arrays, Strings, basic SQL).
- Add SQL query practice, data visualization, statistics basics.
- NO System Design.
- Include Excel/Sheets, Python/Pandas basics if time permits.''';
        break;
      case 'Any Internship':
        roleDepth = '''
ROLE: Any Internship (generalist).
- Keep DSA at Easy-Medium.
- Include resume & project discussion.
- Light theory, prioritize breadth over depth.
- 1 System Design topic only if 8 weeks available.''';
        break;
      default: // SDE / Backend
        roleDepth = '''
ROLE: SDE / Backend.
- Full DSA coverage as per company tier.
- System Design depth as per company tier.
- Strong OOPs and CS fundamentals required.''';
    }

    // ── LeetCode experience calibration ──────────────────────────────────
    String lcSection;
    switch (leetCode) {
      case '150+':
        lcSection =
            'Student has solved 150+ LeetCode problems — skip basic pattern '
            'introductions. Focus on advanced patterns and company-tagged problems.';
        break;
      case '50-150':
        lcSection =
            'Student has solved 50-150 LeetCode problems — they know basics. '
            'Include medium patterns and start introducing hard concepts.';
        break;
      default:
        lcSection =
            'Student has solved 0-50 LeetCode problems — include foundational '
            'pattern topics (sliding window, two pointers, etc.) from scratch.';
    }

    final projectNote = hasProjects
        ? 'Student HAS prior projects — skip "build a project" basics, '
          'focus on how to PRESENT projects in interviews.'
        : 'Student has NO prior projects — allocate time to build at least '
          '1 small project and prepare a project walkthrough.';

    return '''
You are a placement preparation expert for Indian BCA/BTech students.
Create a complete placement preparation roadmap for a student targeting
$company for the role of $role.
Timeline: $weeks. Current self-assessed level: $level.

$tierRules

$roleDepth

STUDENT ASSESSMENT:
$lcSection
$gapSection
$projectNote

LEARNING DEPENDENCY ORDER (MANDATORY):
Topics MUST follow this strict dependency sequence where applicable:
1. Basic data structures (Arrays, Strings) before advanced ones (Trees, Graphs)
2. Sorting & Searching before Two Pointers, Sliding Window
3. Recursion before Backtracking, DP
4. Trees before Graphs
5. OOPs before Design Patterns before System Design
6. OS, DBMS, CN basics before advanced theory
7. Core technical topics before HR/Behavioral
8. Earlier weeks should have foundational topics, later weeks should have advanced topics

TIMELINE RULES:
- Total estimated days across all topics MUST NOT exceed ${_weeksToDays(weeks)} days.
- Each topic's estimatedDays must be realistic (1-3 days for simple topics, 3-5 for complex).
- Do NOT generate more topics than can fit in the timeline.

Return ONLY a JSON array with no markdown, no backticks, no explanation.
Each item is a topic to study.
Format: [{"weekNumber": 1, "topic": "Arrays", "category": "DSA",
"priority": "High", "estimatedDays": 3,
"description": "one line what to study", "type": "practice"}].
category must be one of: DSA, OOPs, Theory, System Design, HR, Project.
type must be one of: practice, read, revise.
priority must be: High, Medium, or Low.
Generate 15-25 topics ordered by week and strict learning dependency sequence.
''';
  }

  int _weeksToDays(String weeks) {
    switch (weeks) {
      case '2 weeks':
        return 14;
      case '8 weeks':
        return 56;
      default:
        return 28;
    }
  }
  // ────────────────────────────────────────────────────────────────────────

  /// Orchestrates the entire roadmap generation flow from user input to state update
  Future<void> _generateRoadmap() async {
    final company = _companyController.text.trim();

    // minimum length validation — prevents single-char or empty queries
    if (company.length < 2) {
      _showSnackBar('Please enter a valid company name.');
      return;
    }

    final weeks = _selectedWeeks.first;
    final level = _selectedLevel.first;
    final leetCode = _selectedLeetCode.first;
    final hasProj = _hasProjects.first == 'Yes';

    setState(() {
      _state = _ScreenState.loading;
      _savedCompany = company;
      _savedRole = _selectedRole;
    });

    final prompt = _buildRoadmapPrompt(
      company: company,
      role: _selectedRole,
      weeks: weeks,
      level: level,
      leetCode: leetCode,
      comfortableIn: _comfortableTopics,
      hasProjects: hasProj,
    );

    try {
      final text = await AIService.generateContent(prompt: prompt);

      final int start = text.indexOf('[');
      final int end = text.lastIndexOf(']');

      // validate indices before substring to prevent RangeError
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

  // ─── Build Method & State Dispatcher ───

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
      // Switching UI based on current app state (Input Form vs Loading vs Result)
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

  // ─── View Builders (Form, Result) ───

  /// Builds the initial assessment form where users provide their details
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

          // ── New assessment fields ──────────────────────────────────────
          const SectionHeader('LEETCODE PROBLEMS SOLVED'),
          AppCard(
            padding: const EdgeInsets.all(4),
            child: _buildSegmentedRow(
              options: const ['0-50', '50-150', '150+'],
              selected: _selectedLeetCode,
              onChanged: (v) => setState(() => _selectedLeetCode = v),
            ),
          ),
          const SectionHeader('TOPICS YOU\'RE COMFORTABLE IN'),
          AppCard(
            child: _buildMultiSelectChips(
              options: _topicOptions,
              selected: _comfortableTopics,
              onChanged: (v) => setState(() {
                // "None" is exclusive — deselect everything else
                if (v.contains('None') && !_comfortableTopics.contains('None')) {
                  _comfortableTopics = {'None'};
                } else {
                  v.remove('None');
                  _comfortableTopics = v;
                }
              }),
            ),
          ),
          const SectionHeader('HAVE PRIOR PROJECTS?'),
          AppCard(
            padding: const EdgeInsets.all(4),
            child: _buildSegmentedRow(
              options: const ['Yes', 'No'],
              selected: _hasProjects,
              onChanged: (v) => setState(() => _hasProjects = v),
            ),
          ),
          // ──────────────────────────────────────────────────────────────

          const SizedBox(height: 48),
          GradientButton(label: 'Generate Roadmap', onTap: _generateRoadmap),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Builds the grouped list view showing the generated weekly study steps
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

  // ─── UI Helper Components ───

  /// Builds a clickable card for a specific roadmap topic
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

  /// Internal helper to build a grid of selectable filter-like chips for multi-select
  Widget _buildMultiSelectChips({
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onChanged,
  }) {
    // Ensuring "None" logic is handled correctly at UI level
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 2.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () {
            final next = Set<String>.from(selected);
            if (isSelected) {
              next.remove(opt);
            } else {
              next.add(opt);
            }
            onChanged(next);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Center(
              child: Text(
                opt,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Builds a custom horizontal segmented control row for single/restricted multiple choice
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
          ? const ShimmerContainer(
              height: 56,
              borderRadius: 16,
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