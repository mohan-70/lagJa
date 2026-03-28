import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants/api_constants.dart';
import '../models/roadmap_problem.dart';
import '../services/firestore_service.dart';

// ---------------------------------------------------------------------------
// _RoadmapTopic — Private model for Phase 1 roadmap topics
// ---------------------------------------------------------------------------
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
      weekNumber: map['weekNumber'] as int? ?? 1,
      topic: map['topic'] as String? ?? 'Unknown Topic',
      category: map['category'] as String? ?? 'DSA',
      priority: map['priority'] as String? ?? 'Medium',
      estimatedDays: map['estimatedDays'] as int? ?? 1,
      description: map['description'] as String? ?? '',
      type: map['type'] as String? ?? 'practice',
    );
  }
}

// ---------------------------------------------------------------------------
// RoadmapScreen — AI-powered Placement Roadmap Generator (Phase 1)
// ---------------------------------------------------------------------------
class RoadmapScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const RoadmapScreen({super.key, this.onSaved});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

enum _ScreenState { form, loading, result }

class _RoadmapScreenState extends State<RoadmapScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  // ignore: unused_field
  final FirestoreService _firestoreService = FirestoreService();
  // ignore: unused_field
  final Uuid _uuid = const Uuid();

  // ── State ─────────────────────────────────────────────────────────────────
  _ScreenState _state = _ScreenState.form;
  List<_RoadmapTopic> _topics = [];

  // ── Form fields ───────────────────────────────────────────────────────────
  final TextEditingController _companyController = TextEditingController();
  String _selectedRole = 'SDE';
  Set<String> _selectedWeeks = {'4 weeks'};
  Set<String> _selectedLevel = {'Beginner'};

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

  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  // ── Gemini API (Phase 1: Roadmap Generation) ──────────────────────────────

  Future<void> _generateRoadmap() async {
    final company = _companyController.text.trim();
    if (company.isEmpty) {
      _showSnackBar('Please enter a target company.');
      return;
    }

    final weeks = _selectedWeeks.first;
    final level = _selectedLevel.first;

    setState(() {
      _state = _ScreenState.loading;
      _savedCompany = company;
      _savedRole = _selectedRole;
    });

    final prompt = '''You are a placement preparation expert for Indian BCA/BTech students. Create a complete placement preparation roadmap for a student targeting $company for $_selectedRole. They have $weeks and are at $level level. Return ONLY a JSON array with no markdown, no backticks, no explanation. Each item is a topic to study. Format: [{"weekNumber": 1, "topic": "Arrays", "category": "DSA", "priority": "High", "estimatedDays": 3, "description": "one line what to study", "type": "practice"}]. category must be one of: DSA, OOPs, Theory, System Design, HR, Project. type must be one of: practice, read, revise. priority must be: High, Medium, or Low. Generate 15-25 topics ordered by week and learning sequence.''';

    try {
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
        String msg = 'API Error: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            msg = 'Gemini Error: ${errorData['error']['message']}';
          }
        } catch (_) {}
        throw Exception(msg);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
        throw Exception('Gemini returned no results. This could be due to safety filters.');
      }

      final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;

      // Robust JSON extraction: Find the first '[' and last ']' to extract the array
      final int start = rawText.indexOf('[');
      final int end = rawText.lastIndexOf(']');
      
      if (start == -1 || end == -1) {
        throw Exception('Invalid JSON format returned by Gemini.');
      }

      final String jsonStr = rawText.substring(start, end + 1);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final topics = jsonList.map((e) => _RoadmapTopic.fromMap(e as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _topics = topics;
          _state = _ScreenState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _ScreenState.form);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'DSA': return Colors.purpleAccent;
      case 'OOPS': return Colors.blueAccent;
      case 'THEORY': return Colors.tealAccent;
      case 'HR': return Colors.orangeAccent;
      case 'PROJECT': return Colors.greenAccent;
      case 'SYSTEM DESIGN': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Roadmap Generator ✨',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: _state == _ScreenState.result
            ? [
                TextButton.icon(
                  onPressed: () => setState(() => _state = _ScreenState.form),
                  icon: const Icon(Icons.refresh, color: _purple, size: 18),
                  label: const Text('Regenerate', style: TextStyle(color: _purple)),
                ),
              ]
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _state == _ScreenState.result ? _buildResultView() : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    final isLoading = _state == _ScreenState.loading;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Let AI build your prep plan',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Answer quick questions to get a personalized roadmap.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 32),
          _sectionLabel('🏢 Target Company'),
          const SizedBox(height: 8),
          TextField(
            controller: _companyController,
            enabled: !isLoading,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('e.g. Google, TCS', Icons.business_center_outlined),
          ),
          const SizedBox(height: 24),
          _sectionLabel('💼 Job Role'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: isLoading ? null : (v) => setState(() => _selectedRole = v!),
            dropdownColor: _card,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('', Icons.work_outline),
          ),
          const SizedBox(height: 24),
          _sectionLabel('📅 Prep Duration'),
          const SizedBox(height: 10),
          _buildSegmentedRow(
            options: const ['2 weeks', '4 weeks', '8 weeks'],
            selected: _selectedWeeks,
            enabled: !isLoading,
            onChanged: (v) => setState(() => _selectedWeeks = v),
          ),
          const SizedBox(height: 24),
          _sectionLabel('🎓 Current Level'),
          const SizedBox(height: 10),
          _buildSegmentedRow(
            options: const ['Beginner', 'Intermediate'],
            selected: _selectedLevel,
            enabled: !isLoading,
            onChanged: (v) => setState(() => _selectedLevel = v),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _generateRoadmap,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Generate My Roadmap 🚀',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const Center(
                child: Text('Gemini is building your roadmap...', style: TextStyle(color: Colors.grey))),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[500]),
      prefixIcon: Icon(icon, color: _purple),
      filled: true,
      fillColor: _card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }

  Widget _buildResultView() {
    final Map<int, List<_RoadmapTopic>> groupedTopics = {};
    for (var topic in _topics) {
      groupedTopics.putIfAbsent(topic.weekNumber, () => []).add(topic);
    }
    final sortedWeeks = groupedTopics.keys.toList()..sort();

    return Column(
      children: [
        _buildSuccessHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedWeeks.length,
            itemBuilder: (context, weekIdx) {
              final weekNum = sortedWeeks[weekIdx];
              final weekTopics = groupedTopics[weekNum]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(border: Border(left: BorderSide(color: _purple, width: 4))),
                    child: Text('Week $weekNum',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ...weekTopics.map((topic) => _buildTopicCard(topic)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_purple, Color(0xFF3D38A7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Roadmap is Ready',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$_savedCompany · $_savedRole',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(_RoadmapTopic topic) {
    final catColor = _getCategoryColor(topic.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: catColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: catColor.withOpacity(0.5))),
                child: Text(topic.category,
                    style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TopicContentScreen(
                        topic: topic.topic,
                        category: topic.category,
                        company: _savedCompany,
                        role: _savedRole,
                        level: _selectedLevel.first,
                        onSaved: widget.onSaved,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _purple),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('→ Generate Content',
                    style: TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(topic.topic,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(topic.description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoChip(topic.priority, Colors.grey[800]!),
              const SizedBox(width: 12),
              Text('~${topic.estimatedDays} days', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(width: 12),
              _infoChip(topic.type, Colors.grey[800]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600));
  }

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
              onTap: enabled ? () => onChanged({opt}) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _purple : _card,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isSelected ? _purple : Colors.grey[700]!),
                ),
                child: Text(opt,
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TopicContentScreen — AI-powered Topic Content Generator (Phase 2)
// ---------------------------------------------------------------------------
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

  static const _purple = Color(0xFF6C63FF);
  static const _bg = Color(0xFF0F0F1A);
  static const _card = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _generateContent();
  }

  Future<void> _generateContent() async {
    String prompt = '';
    final cat = widget.category.toUpperCase();

    if (cat == 'DSA' || cat == 'OOPS') {
      prompt = 'Generate practice problems for the topic ${widget.topic} for a student targeting ${widget.company} for ${widget.role} at ${widget.level} level. Return ONLY a JSON array. Format: [{"title":"","difficulty":"Easy/Medium/Hard","whyImportant":""}]. Generate exactly 8-12 problems.';
    } else if (cat == 'THEORY') {
      prompt = 'Generate key concepts and interview questions for ${widget.topic} for a student targeting ${widget.company} for ${widget.role}. Return ONLY a JSON array. Format: [{"concept":"","explanation":"one line","likelyAsked": true/false}]. Generate 10-15 items.';
    } else if (cat == 'HR') {
      prompt = 'Generate HR interview questions for a student targeting ${widget.company} for ${widget.role}. Return ONLY a JSON array. Format: [{"question":"","tipToAnswer":"one line tip"}]. Generate 10 questions.';
    } else {
      prompt = 'Generate talking points and prep tips for ${widget.topic} for a student targeting ${widget.company} for ${widget.role}. Return ONLY a JSON array. Format: [{"point":"","detail":"one line explanation"}]. Generate 8-10 items.';
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.geminiApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ]
        }),
      );

      if (response.statusCode != 200) {
        String msg = 'API Error: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            msg = 'Gemini Error: ${errorData['error']['message']}';
          }
        } catch (_) {}
        throw Exception(msg);
      }

      final data = jsonDecode(response.body);
      if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
        throw Exception('Gemini returned no results. This could be due to safety filters.');
      }

      final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;
      
      // Robust JSON extraction
      final int start = rawText.indexOf('[');
      final int end = rawText.lastIndexOf(']');
      
      if (start == -1 || end == -1) {
        throw Exception('Invalid JSON format returned by Gemini.');
      }

      final String jsonStr = rawText.substring(start, end + 1);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      
      if (mounted) {
        setState(() {
          _content = jsonList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveDSAToTracker() async {
    setState(() => _isSaving = true);
    try {
      for (var item in _content) {
        final problem = RoadmapProblem(
          topic: widget.topic,
          title: item['title'] ?? 'Untitled',
          difficulty: item['difficulty'] ?? 'Medium',
          whyImportant: item['whyImportant'] ?? '',
        );
        await _firestoreService.addDSAProblemRaw(_uuid.v4(), problem.toMap());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to DSA Tracker ✅')));
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: Text(widget.topic, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _purple),
                  const SizedBox(height: 16),
                  Text('Gemini is preparing ${widget.topic} content...', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                _buildHeaderCard(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _content.length,
                    itemBuilder: (context, index) => _buildContentCard(_content[index]),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_purple, Color(0xFF3D38A7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.topic, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${widget.category} • ${widget.company}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(dynamic item) {
    final cat = widget.category.toUpperCase();
    if (cat == 'DSA' || cat == 'OOPS') {
      return _buildDSACard(item);
    } else if (cat == 'THEORY') {
      return _buildTheoryCard(item);
    } else if (cat == 'HR') {
      return _buildHRCard(item);
    } else {
      return _buildGenericCard(item);
    }
  }

  Widget _buildDSACard(dynamic item) {
    Color diffColor = const Color(0xFFFF9800);
    final d = (item['difficulty'] ?? 'Medium').toString().toLowerCase();
    if (d == 'easy') diffColor = const Color(0xFF4CAF50);
    if (d == 'hard') diffColor = const Color(0xFFF44336);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: diffColor.withOpacity(0.15), border: Border.all(color: diffColor), borderRadius: BorderRadius.circular(20)),
                child: Text(item['difficulty'] ?? 'Medium', style: TextStyle(color: diffColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Checkbox(value: false, onChanged: (v) {}, side: BorderSide(color: Colors.grey[600]!)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(item['whyImportant'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTheoryCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item['concept'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
              if (item['likelyAsked'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Likely Asked', style: TextStyle(color: Colors.tealAccent, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item['explanation'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildHRCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item['question'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tip: ${item['tipToAnswer'] ?? ""}', style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildGenericCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item['point'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(item['detail'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final cat = widget.category.toUpperCase();
    final isDSA = cat == 'DSA' || cat == 'OOPS';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: _bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: isDSA ? (_isSaving ? null : _saveDSAToTracker) : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Revised ✓'))),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _isSaving
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(isDSA ? 'Save to DSA Tracker' : 'Mark as Revised ✓', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}
