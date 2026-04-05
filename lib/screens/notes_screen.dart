// NotesScreen: Manages interview experiences and preparation notes.
// Users can log company-specific details and quickly search through their history.
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/firestore_service.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/ui_constants.dart';
import '../widgets/ui/gradient_button.dart';
import '../widgets/ui/shimmer_loader.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // ─── State & Initialization ───

  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Build Method ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Notes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.3),
          child: Container(color: AppColors.border, height: 0.3),
        ),
      ),
      body: Column(
        children: [
          // Search bar for filtering notes by company name
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search by company...',
                  prefixIcon: Icon(Icons.search, color: AppColors.accent),
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Note>>(
              // Dynamically switching streams based on search query presence
              stream: _searchQuery.isEmpty
                  ? _firestoreService.getNotes()
                  : _firestoreService.searchNotes(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ShimmerList();
                }
                final notes = snapshot.data ?? [];
                if (notes.isEmpty) return _buildEmptyState();
                
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final n = notes[index];
                    return AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _buildNoteCard(n),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteBottomSheet,
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ─── UI Helpers (Cards & Empty States) ───

  /// Builds a card representing a single note, showing a snippet of the content
  Widget _buildNoteCard(Note n) {
    final bool isLong = n.content.length > 100;

    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(n),
      onTap: () => _showNoteDetail(n), // Opens full-screen detail sheet
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    n.companyName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('MMM dd').format(n.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Displaying a truncated snippet of the note content
            Text(
              n.content,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
            if (isLong) ...[
              const SizedBox(height: 8),
              const Text(
                'Read more',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Placeholder UI when current search returns no results or collection is empty
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notes, size: 64, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'No notes yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Document your interview experiences 📝',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logic & Sheet Builders ───

  /// Opens a simplified bottom sheet form to add a new note
  void _showAddNoteBottomSheet() {
    final companyC = TextEditingController();
    final contentC = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
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
                   color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('New Note',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            TextField(
              controller: companyC,
              decoration: const InputDecoration(hintText: 'Company Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentC,
              decoration: const InputDecoration(hintText: 'Note details...'),
              maxLines: 6,
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Add Note',
              onTap: () async {
                if (companyC.text.isEmpty) return;
                await _firestoreService.addNote(Note(
                  id: _uuid.v4(),
                  companyName: companyC.text,
                  content: contentC.text,
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
    );
  }

  /// Displays the full content of a note in an expandable modal
  void _showNoteDetail(Note n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (b) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (c, s) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: s,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                n.companyName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                DateFormat('MMMM dd, yyyy').format(n.createdAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                n.content,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirms deletion before calling Firestore removal
  void _showDeleteConfirmation(Note n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Remove note for ${n.companyName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.deleteNote(n.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

