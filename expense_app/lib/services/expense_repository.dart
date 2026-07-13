// lib/services/expense_repository.dart
import 'package:expense_tracker/services/firestore_services.dart';

import '../models/expense.dart';

class ExpenseRepository {
  final FirestoreService _firestore = FirestoreService();

  // Singleton
  static final ExpenseRepository _instance = ExpenseRepository._internal();
  factory ExpenseRepository() => _instance;
  ExpenseRepository._internal();
  static ExpenseRepository get instance => _instance;

  // ── CRUD ──
  Future<Expense> addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
    final expense = Expense(
      id: id,
      title: title,
      amount: amount,
      category: category,
      date: date,
      note: note,
      createdAt: DateTime.now(),
    );
    return await _firestore.addExpense(expense);
  }

  Future<List<Expense>> fetchAll() async => await _firestore.getAllExpenses();
  Future<List<Expense>> fetchForMonth(int year, int month) async =>
      await _firestore.getExpensesForMonth(year, month);
  Future<Expense?> fetchById(String id) async =>
      await _firestore.getExpenseById(id);
  Future<Expense> updateExpense(Expense expense) async =>
      await _firestore.updateExpense(expense);
  Future<void> deleteExpense(String id) async =>
      await _firestore.deleteExpense(id);

  // ── Aggregates ──
  Future<double> totalAmount() async => await _firestore.getTotalAmount();
  Future<double> todayTotal() async => await _firestore.getTodayTotal();
  Future<double> monthTotal(int year, int month) async =>
      await _firestore.getMonthTotal(year, month);
  Future<Map<String, double>> categoryTotals() async =>
      await _firestore.getAllTimeCategoryTotals();
  Future<Map<String, double>> categoryTotalsForMonth(
          int year, int month) async =>
      await _firestore.getCategoryTotalsForMonth(year, month);
  Future<Map<int, double>> dailyTotalsForMonth(int year, int month) async =>
      await _firestore.getDailyTotalsForMonth(year, month);

  // ── Search ──
  Future<List<Expense>> search(String query) async {
    final all = await fetchAll();
    final lower = query.toLowerCase();
    return all
        .where((e) =>
            e.title.toLowerCase().contains(lower) ||
            (e.note?.toLowerCase().contains(lower) ?? false))
        .toList();
  }

  // ── Stream ──
  Stream<List<Expense>> watchAll() => _firestore.watchExpenses();
}
