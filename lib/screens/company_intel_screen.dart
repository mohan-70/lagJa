import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

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
    "TCS", "Infosys", "Google", "Amazon", "Wipro", "Startup"
  ];

  Future<void> _fetchIntel(String companyName) async {
    if (companyName.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _intelResult = null;
    });

    final prompt = """
You are a placement expert for Indian students. Give a detailed company intel report for $companyName for freshers and interns in India. Return ONLY a JSON object with no markdown, no backticks. Format: {
  'overview': 'one line company description',
  'fresherCTC': 'e.g. ₹3.5 - 7 LPA',
  'internStipend': 'e.g. ₹10,000 - 20,000/month',
  'hiringDifficulty': 'Easy/Medium/Hard',
  'selectionRate': 'e.g. ~15-20%',
  'interviewRounds': ['Round 1: Aptitude', 'Round 2: Technical', 'Round 3: HR'],
  'keySkills': ['Java', 'Python', 'DBMS'],
  'knownFor': 'e.g. Mass hiring, good work-life balance',
  'tipsToGetIn': ['Tip 1', 'Tip 2', 'Tip 3'],
  'rating': 3.8
}
""";

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.geminiApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['candidates'][0]['content']['parts'][0]['text'];
        // Remove markdown backticks if present
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        setState(() {
          _intelResult = jsonDecode(text);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch data');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingState();
    if (_intelResult != null) return _buildResultState();
    return _buildSearchState();
  }

  Widget _buildSearchState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Company Intel 🔍", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Get salary, hiring process, and insider info for any company", style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. Google, TCS, Wipro, Startup",
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C2C2E))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C2C2E))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C63FF))),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _fetchIntel(_searchController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Get Intel 🔍", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickSearches.map((company) => ActionChip(
              label: Text(company, style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF2C2C2E))),
              onPressed: () {
                _searchController.text = company;
                _fetchIntel(company);
              },
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF6C63FF)),
          const SizedBox(height: 16),
          Text("Fetching intel for ${_searchController.text}...", style: const TextStyle(color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    final intel = _intelResult!;
    return SingleChildScrollView(
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
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() {
              _intelResult = null;
              _searchController.clear();
            }),
            child: const Text("Search Another Company", style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> intel) {
    double rating = (intel['rating'] ?? 0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_searchController.text.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(intel['overview'] ?? '', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              if (index < rating.floor()) return const Icon(Icons.star, color: Colors.amber, size: 20);
              if (index < rating) return const Icon(Icons.star_half, color: Colors.amber, size: 20);
              return const Icon(Icons.star_border, color: Colors.amber, size: 20);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(Map<String, dynamic> intel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E))),
      child: Row(
        children: [
          Expanded(child: _buildSalaryItem("Fresher CTC", intel['fresherCTC'] ?? 'N/A')),
          Container(height: 40, width: 0.5, color: const Color(0xFF2C2C2E)),
          Expanded(child: _buildSalaryItem("Intern Stipend", intel['internStipend'] ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _buildSalaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Color(0xFF30D158), fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHiringStatsCard(Map<String, dynamic> intel) {
    String diff = intel['hiringDifficulty'] ?? 'Medium';
    Color diffColor = Colors.orange;
    if (diff == 'Easy') diffColor = Colors.green;
    if (diff == 'Hard') diffColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(diff, diffColor, "Difficulty"),
          _buildStatItem(intel['selectionRate'] ?? 'N/A', const Color(0xFF6C63FF), "Selection Rate"),
          _buildStatItem("Yes", Colors.blue, "Campus Hiring"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, Color col, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(val, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
      ],
    );
  }

  Widget _buildInterviewProcessCard(Map<String, dynamic> intel) {
    List rounds = intel['interviewRounds'] ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Interview Rounds", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...rounds.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                CircleAvatar(radius: 10, backgroundColor: const Color(0xFF6C63FF), child: Text("${e.key + 1}", style: const TextStyle(fontSize: 10, color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildKeySkillsCard(Map<String, dynamic> intel) {
    List skills = intel['keySkills'] ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Key Skills", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(20)),
              child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(Map<String, dynamic> intel) {
    List tips = intel['tipsToGetIn'] ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tips to Get In", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("💡 ", style: TextStyle(fontSize: 14)),
                Expanded(child: Text(tip, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildKnownForCard(Map<String, dynamic> intel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2C2C2E))),
      child: Row(
        children: [
          const Text("⭐ ", style: TextStyle(fontSize: 14)),
          Expanded(child: Text("Known For: ${intel['knownFor'] ?? 'N/A'}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
