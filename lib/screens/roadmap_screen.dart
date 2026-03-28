import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants/api_constants.dart';
import '../models/roadmap_problem.dart';
import '../services/firestore_service.dart';

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

  static const _purple = Color(0xFF6C63FF);
  static const _bg = Color(0xFF000000);
  static const _card = Color(0xFF1C1C1E);
  static const _border = Color(0xFF2C2C2E);
  static const _textSecondary = Color(0xFF8E8E93);

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
          'contents': [{'parts': [{'text': prompt}]}]
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;

      final int start = rawText.indexOf('[');
      final int end = rawText.lastIndexOf(']');
      if (start == -1 || end == -1) throw Exception('Invalid JSON format');

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
        _showSnackBar(e.toString());
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _border, width: 0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _state == _ScreenState.result ? _buildResultView() : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    final isLoading = _state == _ScreenState.loading;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plan your career.', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Let Gemini build your tailored prep roadmap.', style: TextStyle(color: _textSecondary, fontSize: 17)),
          const SizedBox(height: 32),
          _sectionLabel('TARGET COMPANY'),
          const SizedBox(height: 8),
          TextField(
            controller: _companyController,
            enabled: !isLoading,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'e.g. Google, Amazon, TCS'),
          ),
          const SizedBox(height: 24),
          _sectionLabel('ROLE'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: isLoading ? null : (v) => setState(() => _selectedRole = v!),
            dropdownColor: _card,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
          const SizedBox(height: 24),
          _sectionLabel('PREP DURATION'),
          const SizedBox(height: 10),
          _buildSegmentedRow(
            options: const ['2 weeks', '4 weeks', '8 weeks'],
            selected: _selectedWeeks,
            enabled: !isLoading,
            onChanged: (v) => setState(() => _selectedWeeks = v),
          ),
          const SizedBox(height: 24),
          _sectionLabel('CURRENT LEVEL'),
          const SizedBox(height: 10),
          _buildSegmentedRow(
            options: const ['Beginner', 'Intermediate'],
            selected: _selectedLevel,
            enabled: !isLoading,
            onChanged: (v) => setState(() => _selectedLevel = v),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _generateRoadmap,
              child: isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate Roadmap'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final Map<int, List<_RoadmapTopic>> grouped = {};
    for (var t in _topics) {
      grouped.putIfAbsent(t.weekNumber, () => []).add(t);
    }
    final sortedWeeks = grouped.keys.toList()..sort();

    return Column(
      children: [
        _buildSuccessHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedWeeks.length,
            itemBuilder: (context, idx) {
              final week = sortedWeeks[idx];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
                    child: Text('WEEK $week', style: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  ),
                  Container(
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.5)),
                    child: Column(
                      children: List.generate(grouped[week]!.length, (i) {
                        final t = grouped[week]![i];
                        return Column(
                          children: [
                            _buildTopicRow(t),
                            if (i < grouped[week]!.length - 1) const Divider(color: Color(0xFF38383A), height: 0.5, indent: 16, endIndent: 16),
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
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.5)),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF30D158), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Roadmap generated', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                Text('$_savedCompany · $_savedRole', style: const TextStyle(color: _textSecondary, fontSize: 13)),
              ],
            ),
          ),
          IconButton(onPressed: () => setState(() => _state = _ScreenState.form), icon: const Icon(Icons.refresh, color: _purple, size: 20)),
        ],
      ),
    );
  }

  Widget _buildTopicRow(_RoadmapTopic topic) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TopicContentScreen(topic: topic.topic, category: topic.category, company: _savedCompany, role: _savedRole, level: _selectedLevel.first, onSaved: widget.onSaved))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          topic.topic,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _chip(topic.category),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(topic.description, style: const TextStyle(color: _textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniChip(topic.priority),
                      const SizedBox(width: 8),
                      Text('~${topic.estimatedDays}d', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF48484A), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _miniChip(String label) {
    return Text(label.toUpperCase(), style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700));
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));
  }

  Widget _buildSegmentedRow({required List<String> options, required Set<String> selected, required bool enabled, required ValueChanged<Set<String>> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: options.map((opt) {
          final isSelected = selected.contains(opt);
          return Expanded(
            child: GestureDetector(
              onTap: enabled ? () => onChanged({opt}) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: isSelected ? _border : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : _textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, fontSize: 14))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TopicContentScreen extends StatefulWidget {
  final String topic;
  final String category;
  final String company;
  final String role;
  final String level;
  final VoidCallback? onSaved;

  const TopicContentScreen({super.key, required this.topic, required this.category, required this.company, required this.role, required this.level, this.onSaved});
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
  static const _bg = Color(0xFF000000);
  static const _card = Color(0xFF1C1C1E);
  static const _border = Color(0xFF2C2C2E);
  static const _textSecondary = Color(0xFF8E8E93);

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
      final response = await http.post(Uri.parse(ApiConstants.geminiApiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}]}));
      if (response.statusCode != 200) throw Exception('API Error');
      final data = jsonDecode(response.body);
      final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;
      final int s = rawText.indexOf('[');
      final int e = rawText.lastIndexOf(']');
      if (s == -1 || e == -1) throw Exception('Invalid JSON');
      if (mounted) setState(() { _content = jsonDecode(rawText.substring(s, e + 1)); _isLoading = false; });
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); Navigator.pop(context); }
    }
  }

  Future<void> _saveDSAToTracker() async {
    setState(() => _isSaving = true);
    try {
      for (var item in _content) {
        final problem = RoadmapProblem(topic: widget.topic, title: item['title'] ?? 'Untitled', difficulty: item['difficulty'] ?? 'Medium', whyImportant: item['whyImportant'] ?? '');
        await _firestoreService.addDSAProblemRaw(_uuid.v4(), problem.toMap());
      }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved ✅'))); widget.onSaved?.call(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category.toUpperCase();
    final isDSA = cat == 'DSA' || cat == 'OOPS';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0, scrolledUnderElevation: 0,
        title: Text(widget.topic, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _purple, size: 20), onPressed: () => Navigator.pop(context)),
        shape: const Border(bottom: BorderSide(color: Color(0xFF38383A), width: 0.3)),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: _purple))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _content.length,
                    itemBuilder: (context, i) {
                      if (i == 0) return Column(children: [_header(), const SizedBox(height: 24), _listContainer()]);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                _bottomAction(isDSA),
              ],
            ),
    );
  }

  Widget _header() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.5)), child: Row(children: [const Icon(Icons.auto_awesome_rounded, color: _purple, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.topic, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text('${widget.category} • ${widget.company}', style: const TextStyle(color: _textSecondary, fontSize: 13))]))]));
  }

  Widget _listContainer() {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.5)),
      child: Column(
        children: List.generate(_content.length, (i) {
          final item = _content[i];
          return Column(
            children: [
              _item(item),
              if (i < _content.length - 1) const Divider(color: Color(0xFF38383A), height: 0.5, indent: 16, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }

  Widget _item(dynamic item) {
    final cat = widget.category.toUpperCase();
    if (cat == 'DSA' || cat == 'OOPS') {
      Color dColor = const Color(0xFFFF9F0A);
      final d = (item['difficulty'] ?? 'Medium').toString().toLowerCase();
      if (d == 'easy') dColor = const Color(0xFF30D158);
      if (d == 'hard') dColor = const Color(0xFFFF453A);
      return Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Flexible(child: Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Text((item['difficulty'] ?? '').toUpperCase(), style: TextStyle(color: dColor, fontSize: 10, fontWeight: FontWeight.w700))]), const SizedBox(height: 4), Text(item['whyImportant'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 14))]))]));
    } else if (cat == 'THEORY') {
      return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(item['concept'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))), if (item['likelyAsked'] == true) Text('LIKELY ASKED', style: TextStyle(color: Colors.tealAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w800))]), const SizedBox(height: 4), Text(item['explanation'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 14))]));
    } else {
      return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['question'] ?? item['point'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(item['tipToAnswer'] ?? item['detail'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 14))]));
    }
  }

  Widget _bottomAction(bool isDSA) {
    return Container(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), decoration: const BoxDecoration(color: _bg, border: Border(top: BorderSide(color: Color(0xFF38383A), width: 0.3))), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: isDSA ? (_isSaving ? null : _saveDSAToTracker) : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Revised ✓'))), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(isDSA ? 'Save to DSA Tracker' : 'Mark as Revised'))));
  }
}
