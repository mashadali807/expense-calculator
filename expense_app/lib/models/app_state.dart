import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../services/expense_repository.dart';

class AppState extends ChangeNotifier {
  static const _userKey      = 'user';
  static const _darkModeKey  = 'darkMode';
  static const _budgetKey    = 'monthlyBudget';

  // ── Auth
  bool   _isDarkMode  = false;
  bool   _isLoggedIn  = false;
  String _userName    = '';
  String _userEmail   = '';

  // ── Data
  bool          _isLoading    = false;
  String?       _errorMessage;
  List<Expense> _expenses     = [];

  // ── Aggregates (cached)
  double              _totalAmount    = 0;
  double              _todayTotal     = 0;
  double              _monthTotal     = 0;
  Map<String, double> _categoryTotals = {};

  // ── Budget
  double _monthlyBudget = 0; // 0 = not set

  final _repo = ExpenseRepository.instance;

  // ── Getters ───────────────────────────────────────────────────
  bool   get isDarkMode     => _isDarkMode;
  bool   get isLoggedIn     => _isLoggedIn;
  bool   get isLoading      => _isLoading;
  String get userName       => _userName;
  String get userEmail      => _userEmail;
  String? get errorMessage  => _errorMessage;

  List<Expense> get expenses        => List.unmodifiable(_expenses);
  List<Expense> get recentExpenses  => _expenses.take(5).toList();

  double              get totalExpenses  => _totalAmount;
  double              get todayTotal     => _todayTotal;
  double              get monthTotal     => _monthTotal;
  Map<String, double> get categoryTotals => Map.unmodifiable(_categoryTotals);

  double get monthlyBudget    => _monthlyBudget;
  bool   get hasBudget        => _monthlyBudget > 0;
  double get budgetRemaining  => (_monthlyBudget - _monthTotal).clamp(0, double.infinity);
  double get budgetUsedPct    => _monthlyBudget > 0 ? (_monthTotal / _monthlyBudget).clamp(0, 1) : 0;
  bool   get isOverBudget     => _monthlyBudget > 0 && _monthTotal > _monthlyBudget;

  // ── Auth ──────────────────────────────────────────────────────
  Future<void> login(String email, String name) async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = true;
    _userEmail  = email;
    _userName   = name;
    await prefs.setString(_userKey, jsonEncode({'email': email, 'name': name}));
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = false;
    _userName   = '';
    _userEmail  = '';
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<bool> checkAuth() async {
    final prefs    = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      final map   = jsonDecode(userData) as Map<String, dynamic>;
      _isLoggedIn = true;
      _userEmail  = map['email'] as String;
      _userName   = map['name']  as String;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Theme ─────────────────────────────────────────────────────
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    notifyListeners();
  }

  // ── Budget ────────────────────────────────────────────────────
  Future<void> setBudget(double amount) async {
    _monthlyBudget = amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, amount);
    notifyListeners();
  }

  Future<void> loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    _monthlyBudget = prefs.getDouble(_budgetKey) ?? 0;
  }

  // ── Expenses ─────────────────────────────────────────────────
  Future<void> loadExpenses() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _expenses = await _repo.fetchAll();
      await _refreshAggregates();
    } catch (e) {
      _errorMessage = 'Failed to load expenses. Please restart the app.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshAggregates() async {
    final now = DateTime.now();
    final results = await Future.wait([
      _repo.totalAmount(),
      _repo.todayTotal(),
      _repo.monthTotal(now.year, now.month),
      _repo.categoryTotals(),
    ]);
    _totalAmount    = results[0] as double;
    _todayTotal     = results[1] as double;
    _monthTotal     = results[2] as double;
    _categoryTotals = results[3] as Map<String, double>;
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    _errorMessage = null;
    try {
      final expense = await _repo.addExpense(
        title: title, amount: amount, category: category, date: date, note: note,
      );
      _expenses.insert(0, expense);
      await _refreshAggregates();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save expense.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpense(Expense updated) async {
    _errorMessage = null;
    try {
      final saved = await _repo.updateExpense(updated);
      final idx   = _expenses.indexWhere((e) => e.id == saved.id);
      if (idx != -1) _expenses[idx] = saved;
      await _refreshAggregates();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update expense.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    _errorMessage = null;
    try {
      await _repo.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      await _refreshAggregates();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete expense.';
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<Expense>> searchExpenses(String query)          => _repo.search(query);
  Future<List<Expense>> getExpensesForMonth(int y, int m)    => _repo.fetchForMonth(y, m);
  Future<Map<String, double>> getCategoryTotalsForMonth(int y, int m)
      => _repo.categoryTotalsForMonth(y, m);
  Future<Map<int, double>> getDailyTotalsForMonth(int y, int m)
      => _repo.dailyTotalsForMonth(y, m);
}
