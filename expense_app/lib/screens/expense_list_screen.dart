import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_card.dart';
import '../widgets/loading_widget.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  final bool isTab;
  const ExpenseListScreen({super.key, this.isTab = false});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _searchCtrl = TextEditingController();
  final _fmt        = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  String  _query            = '';
  String? _filterCategory;
  String  _sortBy           = 'date_desc'; // date_desc | date_asc | amount_desc | amount_asc
  bool    _isSearchMode     = false;
  bool    _isSearchLoading  = false;

  List<Expense> _searchResults = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String q, AppState state) async {
    setState(() { _query = q; _isSearchLoading = true; });
    if (q.isEmpty) {
      setState(() { _searchResults = []; _isSearchLoading = false; });
      return;
    }
    final res = await state.searchExpenses(q);
    setState(() { _searchResults = res; _isSearchLoading = false; });
  }

  List<Expense> _applyFiltersAndSort(List<Expense> src) {
    var list = src.where((e) {
      if (_filterCategory != null && e.category != _filterCategory) return false;
      if (_query.isNotEmpty && !_isSearchMode) {
        final q = _query.toLowerCase();
        if (!e.title.toLowerCase().contains(q) &&
            !e.category.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'date_asc':    list.sort((a, b) => a.date.compareTo(b.date)); break;
      case 'amount_desc': list.sort((a, b) => b.amount.compareTo(a.amount)); break;
      case 'amount_asc':  list.sort((a, b) => a.amount.compareTo(b.amount)); break;
      default:            list.sort((a, b) => b.date.compareTo(a.date)); break;
    }
    return list;
  }

  void _showSortSheet() {
    final isDark    = context.read<AppState>().isDarkMode;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        final opts = {
          'date_desc':   'Date (Newest First)',
          'date_asc':    'Date (Oldest First)',
          'amount_desc': 'Amount (High to Low)',
          'amount_asc':  'Amount (Low to High)',
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightSubText.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Sort By',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16, color: textColor)),
            const SizedBox(height: 12),
            ...opts.entries.map((e) => ListTile(
              onTap: () { setState(() => _sortBy = e.key); Navigator.pop(context); },
              title: Text(e.value, style: GoogleFonts.poppins(color: textColor)),
              trailing: _sortBy == e.key
                  ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                  : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )),
          ]),
        );
      },
    );
  }

  void _confirmDelete(BuildContext ctx, AppState state, Expense e) =>
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Expense',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to delete "${e.title}"?',
              style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AppTheme.lightSubText)),
            ),
            ElevatedButton(
              onPressed: () { state.deleteExpense(e.id); Navigator.pop(ctx); },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: Text('Delete',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state     = context.watch<AppState>();
    final isDark    = state.isDarkMode;
    final bg        = isDark ? AppTheme.darkBg      : AppTheme.lightBg;
    final textColor = isDark ? AppTheme.darkText    : AppTheme.lightText;
    final subColor  = isDark ? AppTheme.darkSubText : AppTheme.lightSubText;

    final src      = _query.isNotEmpty && _isSearchMode
        ? _searchResults
        : state.expenses;
    final filtered = _applyFiltersAndSort(src);

    // Group by date
    final grouped    = <String, List<Expense>>{};
    for (final e in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort((a, b) =>
        _sortBy == 'date_asc' ? a.compareTo(b) : b.compareTo(a));

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.isTab ? null : AppBar(
        backgroundColor: bg,
        title: Text('All Expenses',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [_sortButton(textColor), _countBadge(filtered.length)],
      ),
      body: SafeArea(
        child: Column(children: [
          if (widget.isTab)
            _buildTabHeader(textColor, filtered.length),

          // ── Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.poppins(color: textColor),
              onChanged: (v) {
                if (_isSearchMode) {
                  _doSearch(v, state);
                } else {
                  setState(() => _query = v);
                }
              },
              onTap: () => setState(() => _isSearchMode = true),
              decoration: InputDecoration(
                hintText: 'Search expenses…',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: subColor),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _query         = '';
                            _searchResults = [];
                            _isSearchMode  = false;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Category chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('All', null, subColor, isDark),
                ...AppTheme.categoryColors.keys
                    .map((cat) => _chip(cat, cat, subColor, isDark)),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── List
          Expanded(
            child: _isSearchLoading
                ? const LoadingWidget(message: 'Searching…')
                : filtered.isEmpty
                    ? EmptyStateWidget(
                        emoji: '🔍',
                        title: 'No results found',
                        subtitle: _query.isNotEmpty
                            ? 'Try a different search term'
                            : 'No expenses match the filter',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: keys.length,
                        itemBuilder: (ctx, i) {
                          final dateKey  = keys[i];
                          final items    = grouped[dateKey]!;
                          final date     = DateTime.parse(dateKey);
                          final dayTotal = items.fold(0.0, (s, e) => s + e.amount);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDate(date),
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12, color: subColor)),
                                    Text(_fmt.format(dayTotal),
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12, color: AppTheme.error)),
                                  ],
                                ),
                              ),
                              ...items.map((e) => ExpenseCard(
                                expense: e,
                                isDark: isDark,
                                onEdit: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => AddExpenseScreen(expense: e))),
                                onDelete: () => _confirmDelete(context, state, e),
                              )),
                            ],
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTabHeader(Color textColor, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('All Expenses',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 20, color: textColor)),
          Row(children: [
            _countBadge(count),
            const SizedBox(width: 4),
            _sortButton(textColor),
          ]),
        ]),
      );

  Widget _sortButton(Color textColor) => IconButton(
        icon: Icon(Icons.sort_rounded, color: textColor),
        onPressed: _showSortSheet,
        tooltip: 'Sort',
      );

  Widget _countBadge(int count) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count',
            style: GoogleFonts.poppins(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      );

  Widget _chip(String label, String? cat, Color subColor, bool isDark) {
    final isSelected = _filterCategory == cat;
    final color      = cat != null
        ? (AppTheme.categoryColors[cat] ?? AppTheme.primary)
        : AppTheme.primary;
    final icon       = cat != null ? (AppTheme.categoryIcons[cat] ?? '') : '🗂️';

    return GestureDetector(
      onTap: () => setState(() => _filterCategory = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(isDark ? 0.1 : 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
        ),
        child: Text('$icon $label',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : color)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d         = DateTime(date.year, date.month, date.day);
    if (d == today)     return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }
}
