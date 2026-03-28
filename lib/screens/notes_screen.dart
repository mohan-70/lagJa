import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/firestore_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _purple = Color(0xFF6C63FF);
  static const _bg = Color(0xFF000000);
  static const _card = Color(0xFF1C1C1E);
  static const _border = Color(0xFF2C2C2E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Notes'),
        shape: const Border(bottom: BorderSide(color: Color(0xFF38383A), width: 0.3)),
        actions: [
          IconButton(onPressed: _showAddNoteBottomSheet, icon: const Icon(Icons.add_rounded, color: _purple)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: const InputDecoration(hintText: 'Search by company...', prefixIcon: Icon(Icons.search_rounded, color: _textSecondary, size: 20)),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Note>>(
              stream: _searchQuery.isEmpty ? _firestoreService.getNotes() : _firestoreService.searchNotes(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _purple));
                final notes = snapshot.data ?? [];
                if (notes.isEmpty) return _buildEmptyState();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  children: [
                    _buildSectionHeader('${notes.length} INTERVIEW NOTES'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.5)),
                      child: Column(
                        children: List.generate(notes.length, (i) {
                          final n = notes[i];
                          return Column(
                            children: [
                              _buildNoteItem(n),
                              if (i < notes.length - 1) const Divider(color: Color(0xFF38383A), height: 0.5, indent: 16),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));
  }

  Widget _buildNoteItem(Note n) {
    return InkWell(
      onLongPress: () => _showDeleteConfirmation(n),
      onTap: () => _showNoteDetail(n),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.companyName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(n.content, style: const TextStyle(color: _textSecondary, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(_formatDate(n.createdAt), style: const TextStyle(color: Color(0xFF48484A), fontSize: 12)),
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
          const Icon(Icons.note_alt_rounded, size: 64, color: _border),
          const SizedBox(height: 16),
          const Text('No notes yet.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          Text(_searchQuery.isEmpty ? 'Document your interview details.' : 'No matches found.', style: TextStyle(color: _textSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  void _showAddNoteBottomSheet() {
    final companyC = TextEditingController();
    final contentC = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: _bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 16, right: 16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('New Note', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)), const SizedBox(height: 24), TextField(controller: companyC, decoration: const InputDecoration(hintText: 'Company Name')), const SizedBox(height: 16), TextField(controller: contentC, decoration: const InputDecoration(hintText: 'Note details...'), maxLines: 6), const SizedBox(height: 32), SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () async { if (companyC.text.isEmpty) return; await _firestoreService.addNote(Note(id: _uuid.v4(), companyName: companyC.text, content: contentC.text, createdAt: DateTime.now())); Navigator.pop(context); }, child: const Text('Add Note'))), const SizedBox(height: 32)])));
  }

  void _showNoteDetail(Note n) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: _bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (b) => DraggableScrollableSheet(expand: false, initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, builder: (c, s) => Container(padding: const EdgeInsets.all(24), child: ListView(controller: s, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Interview Note', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Color(0xFF48484A)))]), const SizedBox(height: 8), Text(n.companyName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1)), Text(_formatDate(n.createdAt), style: const TextStyle(color: _textSecondary, fontSize: 15)), const SizedBox(height: 32), Text(n.content, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.5))]))));
  }

  void _showDeleteConfirmation(Note n) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: _card, title: const Text('Delete'), content: Text('Remove note for ${n.companyName}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))), TextButton(onPressed: () async { Navigator.pop(ctx); await _firestoreService.deleteNote(n.id); }, child: const Text('Delete', style: TextStyle(color: Color(0xFFFF453A))))]));
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
