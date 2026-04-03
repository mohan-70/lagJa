import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dsa_problem.dart';
import '../models/company.dart';
import '../models/note.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  CollectionReference get _userCollection =>
      _firestore.collection('users').doc(userId).collection('data');

  // DSA Problems
  CollectionReference get _dsaProblemsCollection =>
      _userCollection.doc('dsa_problems').collection('items');

  Stream<List<DSAProblem>> getDSAProblems() {
    return _dsaProblemsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DSAProblem.fromFirestore(doc))
            .toList());
  }

  Future<void> addDSAProblem(DSAProblem problem) async {
    await _dsaProblemsCollection.doc(problem.id).set(problem.toFirestore());
  }

  /// Saves a pre-built Firestore map directly. Used by the Roadmap Generator
  /// to insert AI-generated problems without coupling to [DSAProblem].
  Future<void> addDSAProblemRaw(String id, Map<String, dynamic> data) async {
    await _dsaProblemsCollection.doc(id).set(data);
  }

  Future<void> updateDSAProblem(DSAProblem problem) async {
    await _dsaProblemsCollection.doc(problem.id).update(problem.toFirestore());
  }

  Future<void> deleteDSAProblem(String id) async {
    await _dsaProblemsCollection.doc(id).delete();
  }

  // Companies
  CollectionReference get _companiesCollection =>
      _userCollection.doc('companies').collection('items');

  Stream<List<Company>> getCompanies() {
    return _companiesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Company.fromFirestore(doc))
            .toList());
  }

  Future<void> addCompany(Company company) async {
    await _companiesCollection.doc(company.id).set(company.toFirestore());
  }

  Future<void> updateCompany(Company company) async {
    await _companiesCollection.doc(company.id).update(company.toFirestore());
  }

  Future<void> deleteCompany(String id) async {
    await _companiesCollection.doc(id).delete();
  }

  // Notes
  CollectionReference get _notesCollection =>
      _userCollection.doc('notes').collection('items');

  Stream<List<Note>> getNotes() {
    return _notesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Note.fromFirestore(doc))
            .toList());
  }

  Stream<List<Note>> searchNotes(String query) {
    if (query.isEmpty) return getNotes();
    
    return _notesCollection
        .where('companyName', isGreaterThanOrEqualTo: query)
        .where('companyName', isLessThanOrEqualTo: '$query\uf8ff')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Note.fromFirestore(doc))
            .toList());
  }

  Future<void> addNote(Note note) async {
    await _notesCollection.doc(note.id).set(note.toFirestore());
  }

  Future<void> deleteNote(String id) async {
    await _notesCollection.doc(id).delete();
  }

  // Activity Tracking
  CollectionReference get _activityCollection =>
      _userCollection.doc('activity').collection('dates');

  Future<void> incrementActivity(String date) async {
    final docRef = _activityCollection.doc(date);
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (doc.exists) {
        final count = doc.get('count') ?? 0;
        transaction.update(docRef, {'count': count + 1});
      } else {
        transaction.set(docRef, {'count': 1});
      }
    });
  }

  Stream<Map<String, int>> getActivityData([DateTime? startDate]) {
    Query query = _activityCollection;
    if (startDate != null) {
      final startDateStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      query = query.where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr);
    }
    
    return query.snapshots().map((snapshot) {
      final Map<String, int> data = {};
      for (var doc in snapshot.docs) {
        data[doc.id] = (doc.data() as Map<String, dynamic>)['count'] ?? 0;
      }
      return data;
    });
  }

  // Stats
  Stream<Map<String, int>> getStats() {
    final controller = StreamController<Map<String, int>>.broadcast();
    
    StreamSubscription<int>? sub1, sub2, sub3, sub4;
    int total = 0, solved = 0, companies = 0, notes = 0;
    
    void update() {
      controller.add({
        'totalProblems': total,
        'solvedProblems': solved,
        'companies': companies,
        'notes': notes,
      });
    }
    
    sub1 = _dsaProblemsCollection.snapshots()
        .map((s) => s.docs.length)
        .listen((v) { total = v; update(); });
    sub2 = _dsaProblemsCollection
        .where('isSolved', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length)
        .listen((v) { solved = v; update(); });
    sub3 = _companiesCollection.snapshots()
        .map((s) => s.docs.length)
        .listen((v) { companies = v; update(); });
    sub4 = _notesCollection.snapshots()
        .map((s) => s.docs.length)
        .listen((v) { notes = v; update(); });
    
    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
      sub3?.cancel();
      sub4?.cancel();
    };
    
    // Initial emit
    update();
    
    return controller.stream;
  }
  // Data Clearing Methods
  Future<void> clearDSAProblems() async {
    final snapshot = await _dsaProblemsCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> clearCompanies() async {
    final snapshot = await _companiesCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> clearNotes() async {
    final snapshot = await _notesCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteUserData() async {
    // Clear all sub-collections
    await clearDSAProblems();
    await clearCompanies();
    await clearNotes();
    
    // Clear activity
    final activitySnapshot = await _activityCollection.get();
    for (var doc in activitySnapshot.docs) {
      await doc.reference.delete();
    }

    // Clear meta
    final metaDocs = await _firestore.collection('users').doc(userId).collection('meta').get();
    for (var doc in metaDocs.docs) {
      await doc.reference.delete();
    }

    // Finally delete user document
    await _firestore.collection('users').doc(userId).delete();
  }
}
