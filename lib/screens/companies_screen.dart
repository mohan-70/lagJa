import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/company.dart';
import '../services/firestore_service.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/status_chip.dart';
import '../widgets/ui/gradient_button.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/ui_constants.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});
  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();
  ApplicationStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Companies'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<List<Company>>(
              stream: _firestoreService.getCompanies(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent));
                }
                final allCompanies = snapshot.data ?? [];
                final companies = _filterStatus == null
                    ? allCompanies
                    : allCompanies.where((c) => c.status == _filterStatus).toList();

                if (companies.isEmpty) return _buildEmptyState();
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: companies.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = companies[index];
                    return AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _buildCompanyCard(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCompanyBottomSheet,
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildChip(null, 'ALL'),
          ...ApplicationStatus.values.map((s) => _buildChip(s, s.name.toUpperCase())),
        ],
      ),
    );
  }

  Widget _buildChip(ApplicationStatus? status, String label) {
    final isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = status),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(Company c) {
    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(c),
      onTap: () => _showStatusUpdate(c),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status: c.status.name),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              c.role,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Added on ${DateFormat('MMM dd, yyyy').format(c.createdAt)}',
              style: const TextStyle(
                color: Color(0xFF3F3F46),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center, size: 64, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'No companies yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Track your dream companies!',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCompanyBottomSheet() {
    final nameC = TextEditingController();
    final roleC = TextEditingController();
    final notesC = TextEditingController();
    ApplicationStatus status = ApplicationStatus.wishlist;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 12,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('New Application',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              TextField(
                controller: nameC,
                decoration: const InputDecoration(hintText: 'Company Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roleC,
                decoration: const InputDecoration(hintText: 'Role (e.g. SDE)')),
              const SectionHeader('STATUS'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ApplicationStatus.values.map((s) {
                  final sel = status == s;
                  return GestureDetector(
                    onTap: () => setS(() => status = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accent : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Text(
                        s.name.toUpperCase(),
                        style: TextStyle(
                          color: sel ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              GradientButton(
                label: 'Save Company',
                onTap: () async {
                  if (nameC.text.isEmpty) return;
                  await _firestoreService.addCompany(Company(
                    id: _uuid.v4(),
                    name: nameC.text,
                    role: roleC.text,
                    status: status,
                    notes: notesC.text.isEmpty ? null : notesC.text,
                    createdAt: DateTime.now(),
                  ));
                  if (c.mounted) {
                    Navigator.pop(c);
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusUpdate(Company c) {
    showModalBottomSheet(
      context: context,
      builder: (b) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Update Status',
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            ...ApplicationStatus.values.map((s) => ListTile(
                  onTap: () async {
                    await _firestoreService.updateCompany(c.copyWith(status: s));
                    if (b.mounted) {
                      Navigator.pop(b);
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                  title: StatusChip(status: s.name),
                  trailing: s == c.status
                      ? const Icon(Icons.check_rounded, color: AppColors.success)
                      : null,
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Company c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Remove ${c.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.deleteCompany(c.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
