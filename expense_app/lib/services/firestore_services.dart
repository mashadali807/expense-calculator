// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _userExpenses {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('expenses');
  }

  // ── CREATE ── returns the added expense
  Future<Expense> addExpense(Expense expense) async {
    await _userExpenses.doc(expense.id).set(expense.toMap());
    return expense; // ✅ return the same object
  }

  // ── READ ──
  Future<List<Expense>> getAllExpenses() async {
    final snapshot =
        await _userExpenses.orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final doc = await _userExpenses.doc(id).get();
    if (!doc.exists) return null;
    return Expense.fromMap(doc.data()!);
  }

  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1))
        .millisecondsSinceEpoch;

    final snapshot = await _userExpenses
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList();
  }

  // ── UPDATE ── returns the updated expense
  Future<Expense> updateExpense(Expense expense) async {
    await _userExpenses.doc(expense.id).update(expense.toMap());
    return expense; // ✅ return the updated object
  }

  // ── DELETE ──
  Future<void> deleteExpense(String id) async {
    await _userExpenses.doc(id).delete();
  }

  // ── AGGREGATES ── (using loops for clarity)
  Future<double> getTotalAmount() async {
    final expenses = await getAllExpenses();
    double total = 0.0;
    for (final e in expenses) total += e.amount;
    return total;
  }

  Future<double> getTodayTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    final snapshot = await _userExpenses
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    double total = 0.0;
    for (final doc in snapshot.docs) {
      total += Expense.fromMap(doc.data()).amount;
    }
    return total;
  }

  Future<double> getMonthTotal(int year, int month) async {
    final expenses = await getExpensesForMonth(year, month);
    double total = 0.0;
    for (final e in expenses) total += e.amount;
    return total;
  }

  Future<Map<String, double>> getCategoryTotalsForMonth(
      int year, int month) async {
    final expenses = await getExpensesForMonth(year, month);
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
    return map;
  }

  Future<Map<String, double>> getAllTimeCategoryTotals() async {
    final expenses = await getAllExpenses();
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
    return map;
  }

  Future<Map<int, double>> getDailyTotalsForMonth(int year, int month) async {
    final expenses = await getExpensesForMonth(year, month);
    final map = <int, double>{};
    for (final e in expenses) {
      map[e.date.day] = (map[e.date.day] ?? 0.0) + e.amount;
    }
    return map;
  }

  // ── REAL‑TIME STREAM ──
  Stream<List<Expense>> watchExpenses() {
    return _userExpenses.orderBy('date', descending: true).snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList());
  }
}
