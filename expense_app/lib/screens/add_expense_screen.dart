// ─────────────────────────────────────────────────────────────────
//  AddExpenseScreen  –  Step 2: wired to SQLite via AppState
//
//  • Add a brand-new expense
//  • Edit an existing expense (pass `expense` constructor param)
//  • Full input validation with inline error messages
//  • Haptic feedback on success / error
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense; // null  ➜  Add mode  |  non-null  ➜  Edit mode

  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ─────────────────────────────────────────────────────
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  // ── State ─────────────────────────────────────────────────────
  String   _selectedCategory = 'Food';
  DateTime _selectedDate     = DateTime.now();
  bool     _isSubmitting     = false;

  bool get _isEditing => widget.expense != null;

  // ── Animation for the amount card ────────────────────────────
  late AnimationController _bounceCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut),
    );

    // Pre-fill when editing
    if (_isEditing) {
      final e            = widget.expense!;
      _titleCtrl.text    = e.title;
      _amountCtrl.text   = e.amount.toStringAsFixed(2);
      _noteCtrl.text     = e.note ?? '';
      _selectedCategory  = e.category;
      _selectedDate      = e.date;
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: context.read<AppState>().isDarkMode
                ? AppTheme.darkCard
                : AppTheme.lightCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _submit() async {
    // Animate the amount card
    await _bounceCtrl.forward();
    await _bounceCtrl.reverse();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final amount   = double.parse(_amountCtrl.text.replaceAll(',', '.'));
      final note     = _noteCtrl.text.trim().isEmpty
          ? null
          : _noteCtrl.text.trim();

      if (_isEditing) {
        await appState.updateExpense(
          widget.expense!.copyWith(
            title:    _titleCtrl.text.trim(),
            amount:   amount,
            category: _selectedCategory,
            date:     _selectedDate,
            note:     note,
          ),
        );
      } else {
        await appState.addExpense(
          title:    _titleCtrl.text.trim(),
          amount:   amount,
          category: _selectedCategory,
          date:     _selectedDate,
          note:     note,
        );
      }

      HapticFeedback.lightImpact();
      if (mounted) {
        _showSuccessSnackbar(_isEditing ? 'Expense updated!' : 'Expense added!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        _showErrorSnackbar('Something went wrong. Please try again.');
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
          ],
        ),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: GoogleFonts.poppins(color: Colors.white))),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark       = context.watch<AppState>().isDarkMode;
    final bg           = isDark ? AppTheme.darkBg       : AppTheme.lightBg;
    final cardColor    = isDark ? AppTheme.darkCard     : AppTheme.lightCard;
    final textColor    = isDark ? AppTheme.darkText     : AppTheme.lightText;
    final subColor     = isDark ? AppTheme.darkSubText  : AppTheme.lightSubText;
    final borderColor  = isDark ? AppTheme.darkBorder   : AppTheme.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Expense' : 'New Expense',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textColor,
          ),
        ),
        actions: [
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Amount hero card ─────────────────────────────
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3D35CC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'HOW MUCH?',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '\$',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IntrinsicWidth(
                            child: TextFormField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              textAlign: TextAlign.center,
                              autofocus: !_isEditing,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                ),
                                border: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                                errorStyle: TextStyle(color: Colors.orangeAccent),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter amount';
                                final parsed = double.tryParse(
                                    v.replaceAll(',', '.'));
                                if (parsed == null) return 'Invalid number';
                                if (parsed <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Title ─────────────────────────────────────────
              _label('Title', textColor),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                style: GoogleFonts.poppins(color: textColor, fontSize: 15),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'e.g. Lunch at Subway',
                  prefixIcon: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Title is required';
                  if (v.trim().length < 2) return 'Too short';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Category ──────────────────────────────────────
              _label('Category', textColor),
              const SizedBox(height: 12),
              _buildCategoryGrid(isDark),

              const SizedBox(height: 24),

              // ── Date ──────────────────────────────────────────
              _label('Date', textColor),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatSelectedDate(),
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(Icons.edit_calendar_outlined, color: subColor, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Note ──────────────────────────────────────────
              _label('Note  (optional)', textColor),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                maxLength: 200,
                style: GoogleFonts.poppins(color: textColor, fontSize: 14),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Add details about this expense…',
                  counterStyle: GoogleFonts.poppins(
                      color: subColor, fontSize: 11),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: const Icon(
                        Icons.notes_outlined, color: AppTheme.primary),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Submit button ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isSubmitting
                      ? Container(
                          key: const ValueKey('loading'),
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          key: const ValueKey('button'),
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: AppTheme.accent.withOpacity(0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isEditing
                                    ? Icons.save_alt_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isEditing
                                    ? 'Save Changes'
                                    : 'Add Expense',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _formatSelectedDate() {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sel       = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (sel == today)     return 'Today — ${DateFormat('MMMM d, yyyy').format(_selectedDate)}';
    if (sel == yesterday) return 'Yesterday — ${DateFormat('MMMM d, yyyy').format(_selectedDate)}';
    return DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
  }

  Widget _label(String text, Color color) => Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: color,
        ),
      );

  Widget _buildCategoryGrid(bool isDark) {
    final categories = AppTheme.categoryColors.keys.toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        final color      = AppTheme.categoryColors[cat]!;
        final icon       = AppTheme.categoryIcons[cat]!;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = cat);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : color.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : color.withOpacity(0.35),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  cat,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
