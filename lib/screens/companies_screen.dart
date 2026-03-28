import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/company.dart';
import '../services/firestore_service.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});
  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();

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
        title: const Text('Companies'),
        shape: const Border(bottom: BorderSide(color: Color(0xFF38383A), width: 0.3)),
        actions: [
          IconButton(onPressed: _showAddCompanyBottomSheet, icon: const Icon(Icons.add_rounded, color: _purple)),
        ],
      ),
      body: StreamBuilder<List<Company>>(
        stream: _firestoreService.getCompanies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _purple));
          final companies = snapshot.data ?? [];
          if (companies.isEmpty) return _buildEmptyState();
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              _buildSectionHeader('${companies.length} APPLICATIONS'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.5)),
                child: Column(
                  children: List.generate(companies.length, (i) {
                    final c = companies[i];
                    return Column(
                      children: [
                        _buildCompanyItem(c),
                        if (i < companies.length - 1) const Divider(color: Color(0xFF38383A), height: 0.5, indent: 16),
                      ],
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));
  }

  Widget _buildCompanyItem(Company c) {
    final statusColor = _getStatusColor(c.status);
    return InkWell(
      onLongPress: () => _showDeleteConfirmation(c),
      onTap: () => _showStatusUpdate(c),
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
                      Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(c.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(c.role, style: const TextStyle(color: _textSecondary, fontSize: 15)),
                  if (c.notes != null && c.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(c.notes!, style: const TextStyle(color: Color(0xFF48484A), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF48484A), size: 20),
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
          const Icon(Icons.business_center_rounded, size: 64, color: _border),
          const SizedBox(height: 16),
          const Text('No companies yet.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          Text('Track your job applications here.', style: TextStyle(color: _textSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.wishlist: return _textSecondary;
      case ApplicationStatus.applied: return const Color(0xFF6C63FF);
      case ApplicationStatus.interview: return const Color(0xFFFF9F0A);
      case ApplicationStatus.offered: return const Color(0xFF30D158);
      case ApplicationStatus.rejected: return const Color(0xFFFF453A);
    }
  }

  void _showAddCompanyBottomSheet() {
    final nameC = TextEditingController();
    final roleC = TextEditingController();
    final notesC = TextEditingController();
    ApplicationStatus status = ApplicationStatus.wishlist;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: _bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => StatefulBuilder(builder: (c, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 16, right: 16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('New Application', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)), const SizedBox(height: 24), TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Company Name')), const SizedBox(height: 16), TextField(controller: roleC, decoration: const InputDecoration(hintText: 'Role (e.g. SDE)')), const SizedBox(height: 16), TextField(controller: notesC, decoration: const InputDecoration(hintText: 'Notes (Optional)')), const SizedBox(height: 24), _buildSectionHeader('STATUS'), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: ApplicationStatus.values.map((s) { final sel = status == s; return GestureDetector(onTap: () => setS(() => status = s), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: sel ? _purple : _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? _purple : _border)), child: Text(s.name.toUpperCase(), style: TextStyle(color: sel ? Colors.white : _textSecondary, fontSize: 12, fontWeight: FontWeight.bold)))); }).toList()), const SizedBox(height: 32), SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () async { if (nameC.text.isEmpty) return; await _firestoreService.addCompany(Company(id: _uuid.v4(), name: nameC.text, role: roleC.text, status: status, notes: notesC.text.isEmpty ? null : notesC.text, createdAt: DateTime.now())); Navigator.pop(context); }, child: const Text('Add Company'))), const SizedBox(height: 32)]))));
  }

  void _showStatusUpdate(Company c) {
    showModalBottomSheet(context: context, backgroundColor: _bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (b) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Update Status', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)), const SizedBox(height: 16), ...ApplicationStatus.values.map((s) => ListTile(onTap: () async { await _firestoreService.updateCompany(c.copyWith(status: s)); Navigator.pop(context); }, title: Text(s.name.toUpperCase(), style: TextStyle(color: _getStatusColor(s), fontWeight: FontWeight.w800, fontSize: 14)), leading: Icon(Icons.circle, color: _getStatusColor(s), size: 12), trailing: s == c.status ? const Icon(Icons.check_rounded, color: Color(0xFF30D158)) : null))])));
  }

  void _showDeleteConfirmation(Company c) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: _card, title: const Text('Delete'), content: Text('Remove ${c.name}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))), TextButton(onPressed: () async { Navigator.pop(ctx); await _firestoreService.deleteCompany(c.id); }, child: const Text('Delete', style: TextStyle(color: Color(0xFFFF453A))))]));
  }
}
