// models/app_state.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../services/expense_repository.dart';

class AppState extends ChangeNotifier {
  static const _userKey = 'user';
  static const _darkModeKey = 'darkMode';
  static const _budgetKey = 'monthlyBudget';

  // ── Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _firebaseUser;

  // ── Auth
  bool _isDarkMode = false;
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';

  // ── Data
  bool _isLoading = false;
  String? _errorMessage;
  List<Expense> _expenses = [];

  // ── Aggregates (cached)
  double _totalAmount = 0;
  double _todayTotal = 0;
  double _monthTotal = 0;
  Map<String, double> _categoryTotals = {};

  // ── Budget
  double _monthlyBudget = 0; // 0 = not set

  final _repo = ExpenseRepository.instance;

  // ── Getters ───────────────────────────────────────────────────
  bool get isDarkMode => _isDarkMode;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String? get errorMessage => _errorMessage;
  User? get firebaseUser => _firebaseUser;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Expense> get recentExpenses => _expenses.take(5).toList();

  double get totalExpenses => _totalAmount;
  double get todayTotal => _todayTotal;
  double get monthTotal => _monthTotal;
  Map<String, double> get categoryTotals => Map.unmodifiable(_categoryTotals);

  double get monthlyBudget => _monthlyBudget;
  bool get hasBudget => _monthlyBudget > 0;
  double get budgetRemaining =>
      (_monthlyBudget - _monthTotal).clamp(0, double.infinity);
  double get budgetUsedPct =>
      _monthlyBudget > 0 ? (_monthTotal / _monthlyBudget).clamp(0, 1) : 0;
  bool get isOverBudget => _monthlyBudget > 0 && _monthTotal > _monthlyBudget;

  // ── Constructor ──────────────────────────────────────────────
  AppState() {
    _firebaseUser = _auth.currentUser;
    _auth.authStateChanges().listen((User? user) {
      _firebaseUser = user;
      if (user != null) {
        _isLoggedIn = true;
        _userEmail = user.email ?? '';
        _userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        _saveUserToPrefs();
      } else {
        _isLoggedIn = false;
        _userEmail = '';
        _userName = '';
        _clearUserFromPrefs();
      }
      notifyListeners();
    });
  }

  // ── Auth ──────────────────────────────────────────────────────

  // Login with Firebase – improved error logging
  Future<void> login(String email, String password) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      print('🔐 Attempting login for: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      print('✅ Login successful for: ${userCredential.user?.email}');

      _firebaseUser = userCredential.user;
      _isLoggedIn = true;
      _userEmail = userCredential.user?.email ?? '';
      _userName = userCredential.user?.displayName ??
          userCredential.user?.email?.split('@')[0] ??
          'User';

      await _saveUserToPrefs();
      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      // Print detailed error to console
      print('❌ FirebaseAuthException (login): ${e.code} - ${e.message}');
      _errorMessage = _getFirebaseErrorMessage(e);
      notifyListeners();
      rethrow; // rethrow so UI can catch if needed
    } catch (e, stack) {
      _isLoading = false;
      // Print unexpected error with stack trace
      print('❌ Unexpected login error: $e');
      print(stack);
      _errorMessage = 'Unexpected error: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // Sign up with Firebase – improved error logging
  Future<void> signUp(String email, String password, String name) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      print('🔐 Attempting signUp for: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      print('✅ SignUp successful for: ${userCredential.user?.email}');

      // Update user profile with name
      await userCredential.user?.updateDisplayName(name.trim());
      await userCredential.user?.reload();

      _firebaseUser = _auth.currentUser;
      _isLoggedIn = true;
      _userEmail = email.trim();
      _userName = name.trim();

      await _saveUserToPrefs();
      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      print('❌ FirebaseAuthException (signUp): ${e.code} - ${e.message}');
      _errorMessage = _getFirebaseErrorMessage(e);
      notifyListeners();
      rethrow;
    } catch (e, stack) {
      _isLoading = false;
      print('❌ Unexpected signUp error: $e');
      print(stack);
      _errorMessage = 'Unexpected error: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // Send password reset email – improved error logging
  Future<void> sendPasswordResetEmail(String email) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      print('🔐 Sending password reset to: $email');
      await _auth.sendPasswordResetEmail(email: email.trim());
      print('✅ Password reset email sent');
      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      print('❌ FirebaseAuthException (reset): ${e.code} - ${e.message}');
      _errorMessage = _getFirebaseErrorMessage(e);
      notifyListeners();
      rethrow;
    } catch (e, stack) {
      _isLoading = false;
      print('❌ Unexpected reset email error: $e');
      print(stack);
      _errorMessage = 'Failed to send reset email. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🔐 Logging out');
      await _auth.signOut();
      _firebaseUser = null;
      _isLoggedIn = false;
      _userName = '';
      _userEmail = '';
      _expenses = [];
      _totalAmount = 0;
      _todayTotal = 0;
      _monthTotal = 0;
      _categoryTotals = {};

      await _clearUserFromPrefs();
      _isLoading = false;
      notifyListeners();
      print('✅ Logout successful');
    } catch (e, stack) {
      _isLoading = false;
      print('❌ Logout error: $e');
      print(stack);
      _errorMessage = 'Failed to logout. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  // Check auth state – improved with more logging
  Future<bool> checkAuth() async {
    print('🔍 Checking auth state...');
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);

    if (userData != null && _firebaseUser != null) {
      try {
        final map = jsonDecode(userData) as Map<String, dynamic>;
        _isLoggedIn = true;
        _userEmail = map['email'] as String;
        _userName = map['name'] as String;
        notifyListeners();
        print('✅ Auth check: logged in as $_userEmail');
        return true;
      } catch (e) {
        print('⚠️ Error decoding user data: $e');
        // fall through to Firebase check
      }
    }

    // Check if Firebase has a user
    if (_auth.currentUser != null) {
      _firebaseUser = _auth.currentUser;
      _isLoggedIn = true;
      _userEmail = _auth.currentUser?.email ?? '';
      _userName = _auth.currentUser?.displayName ??
          _auth.currentUser?.email?.split('@')[0] ??
          'User';
      await _saveUserToPrefs();
      notifyListeners();
      print('✅ Auth check: Firebase user found ($_userEmail)');
      return true;
    }

    print('❌ Auth check: no user found');
    return false;
  }

  // ── Private Helper Methods ──────────────────────────────────

  Future<void> _saveUserToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _userKey,
        jsonEncode({
          'email': _userEmail,
          'name': _userName,
        }));
  }

  Future<void> _clearUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters with letters and numbers.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
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
    if (!_isLoggedIn) {
      print('⚠️ loadExpenses called but user not logged in');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('📊 Loading expenses...');
      _expenses = await _repo.fetchAll();
      await _refreshAggregates();
      print('✅ Loaded ${_expenses.length} expenses');
    } catch (e, stack) {
      print('❌ Error loading expenses: $e');
      print(stack);
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
    _totalAmount = results[0] as double;
    _todayTotal = results[1] as double;
    _monthTotal = results[2] as double;
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
      print('➕ Adding expense: $title');
      final expense = await _repo.addExpense(
        title: title,
        amount: amount,
        category: category,
        date: date,
        note: note,
      );
      _expenses.insert(0, expense);
      await _refreshAggregates();
      notifyListeners();
      print('✅ Expense added with ID: ${expense.id}');
    } catch (e, stack) {
      print('❌ Error adding expense: $e');
      print(stack);
      _errorMessage = 'Failed to save expense.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpense(Expense updated) async {
    _errorMessage = null;
    try {
      print('✏️ Updating expense: ${updated.id}');
      final saved = await _repo.updateExpense(updated);
      final idx = _expenses.indexWhere((e) => e.id == saved.id);
      if (idx != -1) _expenses[idx] = saved;
      await _refreshAggregates();
      notifyListeners();
      print('✅ Expense updated');
    } catch (e, stack) {
      print('❌ Error updating expense: $e');
      print(stack);
      _errorMessage = 'Failed to update expense.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    _errorMessage = null;
    try {
      print('🗑️ Deleting expense: $id');
      await _repo.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      await _refreshAggregates();
      notifyListeners();
      print('✅ Expense deleted');
    } catch (e, stack) {
      print('❌ Error deleting expense: $e');
      print(stack);
      _errorMessage = 'Failed to delete expense.';
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<Expense>> searchExpenses(String query) => _repo.search(query);
  Future<List<Expense>> getExpensesForMonth(int y, int m) =>
      _repo.fetchForMonth(y, m);
  Future<Map<String, double>> getCategoryTotalsForMonth(int y, int m) =>
      _repo.categoryTotalsForMonth(y, m);
  Future<Map<int, double>> getDailyTotalsForMonth(int y, int m) =>
      _repo.dailyTotalsForMonth(y, m);
}
