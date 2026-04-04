import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/fake_glass_card.dart';
import '../widgets/ui/gradient_button.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/ui_constants.dart';
import '../widgets/ui/lagja_loader.dart';

class CompanyIntelScreen extends StatefulWidget {
  const CompanyIntelScreen({super.key});

  @override
  State<CompanyIntelScreen> createState() => _CompanyIntelScreenState();
}

class _CompanyIntelScreenState extends State<CompanyIntelScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _intelResult;

  final List<String> _quickSearches = [
    "TCS",
    "Infosys",
    "Google",
    "Amazon",
    "Wipro",
    "Startup"
  ];

  // ✅ Fix: safe double parse for rating
  double _safeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<void> _fetchIntel(String companyName) async {
    if (companyName.isEmpty) return;

    setState(() {
      _isLoading = true;
      _intelResult = null;
    });

   final prompt = """
You are a placement intelligence system for Indian college students (BCA/BTech freshers).

Analyze the company "$companyName" and return a JSON object with EXACTLY this structure.

STRICT RULES:
- Return ONLY raw JSON. No markdown, no backticks, no explanation, no extra text.
- All values must be specific to "$companyName" based on real-world data.
- "hiringDifficulty" must be exactly one of: "Easy", "Medium", "Hard"
- "rating" must be a number between 1.0 and 5.0 based on employee reviews and fresher experience
- "interviewRounds" must have 3-5 items describing actual rounds used by this company
- "keySkills" must have 4-6 items most relevant to this company's hiring
- "tipsToGetIn" must have exactly 3 actionable, company-specific tips
- "selectionRate" should reflect actual difficulty of getting hired at this company
- If company is a generic startup or unknown, give realistic estimated values based on similar Indian startups

JSON structure (keys must match exactly):
{
  "overview": "",
  "fresherCTC": "",
  "internStipend": "",
  "hiringDifficulty": "",
  "selectionRate": "",
  "interviewRounds": [],
  "keySkills": [],
  "knownFor": "",
  "tipsToGetIn": [],
  "rating": 0.0
}
""";

    try {
      final text = await AIService.generateContent(prompt: prompt);
      final cleanedText =
          text.replaceAll('```json', '').replaceAll('```', '').trim();

      // ✅ Fix: safe JSON parse with clear error
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(cleanedText);
      } catch (_) {
        throw Exception('AI returned invalid response. Please try again.');
      }

      if (mounted) {
        setState(() => _intelResult = parsed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      // ✅ Fix: single place for loading = false
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose(); // ✅ Fix: controller dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: LagjaLoader(
            message:
                "Gathering intel for ${_searchController.text}..."),
      );
    }
    if (_intelResult != null) return _buildResultState();
    return _buildSearchState();
  }

  // ✅ Fix: wrapped in Scaffold for consistency
  Widget _buildSearchState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Company Intel 🔍", style: AppStyles.heroTitle),
            const SizedBox(height: 8),
            const Text(
                "Get salary, hiring process, and insider info for any company",
                style: AppStyles.body),
            const SizedBox(height: 32),
            AppCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                style:
                    const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: "e.g. Google, TCS, Wipro, Startup",
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.accent),
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (val) => _fetchIntel(val.trim()), // ✅ keyboard submit support
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: "Get Intel Report",
              onTap: () =>
                  _fetchIntel(_searchController.text.trim()),
            ),
            const SectionHeader("QUICK SEARCH"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickSearches
                  .map((company) => GestureDetector(
                        onTap: () {
                          _searchController.text = company;
                          _fetchIntel(company);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border:
                                Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            company,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultState() {
    final intel = _intelResult!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textPrimary),
          onPressed: () => setState(() => _intelResult = null),
        ),
        title: Text(_searchController.text.toUpperCase()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(intel),
            const SizedBox(height: 12),
            _buildSalaryCard(intel),
            const SizedBox(height: 12),
            _buildHiringStatsCard(intel),
            const SizedBox(height: 12),
            _buildInterviewProcessCard(intel),
            const SizedBox(height: 12),
            _buildKeySkillsCard(intel),
            const SizedBox(height: 12),
            _buildTipsCard(intel),
            const SizedBox(height: 12),
            _buildKnownForCard(intel),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => setState(() {
                _intelResult = null;
                _searchController.clear();
              }),
              child: const Text("Search Another Company",
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> intel) {
    final double rating = _safeDouble(intel['rating']); // ✅ safe parse
    return FakeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_searchController.text.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(intel['overview'] ?? '', style: AppStyles.body),
          const SizedBox(height: 16),
          Row(
            children: List.generate(5, (index) {
              if (index < rating.floor()) {
                return const Icon(Icons.star,
                    color: Colors.amber, size: 20);
              }
              if (index < rating) {
                return const Icon(Icons.star_half,
                    color: Colors.amber, size: 20);
              }
              return const Icon(Icons.star_border,
                  color: Colors.amber, size: 20);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(Map<String, dynamic> intel) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
              child: _buildSalaryItem(
                  "Fresher CTC", intel['fresherCTC'] ?? 'N/A')),
          Container(height: 40, width: 0.5, color: AppColors.border),
          Expanded(
              child: _buildSalaryItem(
                  "Intern Stipend", intel['internStipend'] ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _buildSalaryItem(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHiringStatsCard(Map<String, dynamic> intel) {
    String diff = intel['hiringDifficulty'] ?? 'Medium';
    Color diffColor = AppColors.warning;
    if (diff == 'Easy') diffColor = AppColors.success;
    if (diff == 'Hard') diffColor = AppColors.error;

    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(diff, diffColor, "Difficulty"),
          _buildStatItem(intel['selectionRate'] ?? 'N/A',
              AppColors.accent, "Selection Rate"),
          _buildStatItem("Yes", Colors.blue, "Campus Hiring"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, Color col, String label) {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Text(val,
              style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildInterviewProcessCard(Map<String, dynamic> intel) {
    List rounds = intel['interviewRounds'] ?? [];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Interview Rounds",
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...rounds.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            AppColors.accent.withValues(alpha: 0.2),
                        child: Text("${e.key + 1}",
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(e.value,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildKeySkillsCard(Map<String, dynamic> intel) {
    List skills = intel['keySkills'] ?? [];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Key Skills",
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          border:
                              Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(s,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(Map<String, dynamic> intel) {
    List tips = intel['tipsToGetIn'] ?? [];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tips to Get In",
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("💡",
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(tip,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildKnownForCard(Map<String, dynamic> intel) {
    return AppCard(
      child: Row(
        children: [
          const Text("⭐", style: TextStyle(fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
              child: Text("Known For: ${intel['knownFor'] ?? 'N/A'}",
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}