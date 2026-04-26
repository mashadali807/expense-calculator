// ─────────────────────────────────────────────────────────────────
//  ExpenseRepository
//
//  A thin service layer that wraps DatabaseHelper.
//  AppState talks only to this class — never directly to the DB.
//  This makes it easy to swap the backend (e.g. Firebase) later.
// ─────────────────────────────────────────────────────────────────

import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository._internal();
  static final ExpenseRepository instance = ExpenseRepository._internal();
  factory ExpenseRepository() => instance;

  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  // ── Create ────────────────────────────────────────────────────
  Future<Expense> addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    final expense = Expense(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      category: category,
      date: date,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: DateTime.now(),
    );
    await _db.insertExpense(expense);
    return expense;
  }

  // ── Read – all, newest first ───────────────────────────────────
  Future<List<Expense>> fetchAll() => _db.getAllExpenses();

  // ── Read – by id ──────────────────────────────────────────────
  Future<Expense?> fetchById(String id) => _db.getExpenseById(id);

  // ── Read – filtered / searched ────────────────────────────────
  Future<List<Expense>> search(String query) => _db.searchExpenses(query);

  Future<List<Expense>> fetchByCategory(String category) =>
      _db.getExpensesByCategory(category);

  Future<List<Expense>> fetchForMonth(int year, int month) =>
      _db.getExpensesForMonth(year, month);

  Future<List<Expense>> fetchForDay(DateTime day) =>
      _db.getExpensesForDay(day);

  // ── Update ────────────────────────────────────────────────────
  Future<Expense> updateExpense(Expense updated) async {
    final trimmed = updated.copyWith(
      title: updated.title.trim(),
      note: updated.note?.trim().isEmpty == true
          ? null
          : updated.note?.trim(),
    );
    await _db.updateExpense(trimmed);
    return trimmed;
  }

  // ── Delete ────────────────────────────────────────────────────
  Future<void> deleteExpense(String id) => _db.deleteExpense(id);

  Future<void> deleteAll() => _db.deleteAllExpenses();

  // ── Aggregates ────────────────────────────────────────────────
  Future<double> totalAmount() => _db.getTotalAmount();
  Future<double> todayTotal() => _db.getTodayTotal();

  Future<double> monthTotal(int year, int month) =>
      _db.getMonthTotal(year, month);

  Future<Map<String, double>> categoryTotals() =>
      _db.getAllTimeCategoryTotals();

  Future<Map<String, double>> categoryTotalsForMonth(int year, int month) =>
      _db.getCategoryTotalsForMonth(year, month);

  Future<Map<int, double>> dailyTotalsForMonth(int year, int month) =>
      _db.getDailyTotalsForMonth(year, month);

  Future<int> count() => _db.getExpenseCount();
}
