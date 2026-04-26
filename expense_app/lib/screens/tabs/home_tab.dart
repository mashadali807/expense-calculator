import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/expense.dart';
import '../../theme/app_theme.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/loading_widget.dart';
import '../add_expense_screen.dart';
import '../expense_list_screen.dart';
import '../main_shell.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state     = context.watch<AppState>();
    final isDark    = state.isDarkMode;
    final bg        = isDark ? AppTheme.darkBg    : AppTheme.lightBg;
    final textColor = isDark ? AppTheme.darkText  : AppTheme.lightText;
    final fmt       = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (state.isLoading) {
      return Scaffold(backgroundColor: bg,
          body: const LoadingWidget(message: 'Loading your expenses…'));
    }
    if (state.errorMessage != null) {
      return Scaffold(backgroundColor: bg,
          body: ErrorWidget2(
              message: state.errorMessage!,
              onRetry: () => state.loadExpenses()));
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: _buildHeader(context, state, isDark, textColor, fmt)),
          SliverToBoxAdapter(
              child: _buildBudgetBanner(state, isDark)),
          SliverToBoxAdapter(
              child: _buildCategoryScroll(state, isDark, fmt)),
          SliverToBoxAdapter(
              child: _buildQuickActions(context, isDark, textColor)),
          SliverToBoxAdapter(
              child: _buildRecentHeader(context, state, textColor)),
          if (state.recentExpenses.isEmpty)
            SliverToBoxAdapter(
              child: EmptyStateWidget(
                emoji: '🧾',
                title: 'No expenses yet',
                subtitle: 'Tap + Add Expense to get started',
                action: ElevatedButton.icon(
                  onPressed: () => _goAdd(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add First Expense'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => ExpenseCard(
                    expense: state.recentExpenses[i],
                    isDark: isDark,
                    onEdit:   () => _goEdit(context, state.recentExpenses[i]),
                    onDelete: () =>
                        _confirmDelete(context, state, state.recentExpenses[i]),
                  ),
                  childCount: state.recentExpenses.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ),
      floatingActionButton: _fab(context),
    );
  }

  Widget _buildHeader(BuildContext ctx, AppState state, bool isDark,
      Color textColor, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3D35CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, ${state.userName} 👋',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w700)),
            Text(DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 13)),
          ]),
          Row(children: [
            IconButton(
              icon: Icon(
                state.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              onPressed: state.toggleDarkMode,
            ),
            GestureDetector(
              onTap: () async {
                await state.logout();
                if (ctx.mounted) {
                  Navigator.of(ctx)
                      .pushNamedAndRemoveUntil('/auth', (_) => false);
                }
              },
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ]),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Total Spent',
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                Text(fmt.format(state.totalExpenses),
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _miniStat('Today',      fmt.format(state.todayTotal)),
              const SizedBox(height: 8),
              _miniStat('This Month', fmt.format(state.monthTotal)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, String val) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
          Text(val,   style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _buildBudgetBanner(AppState state, bool isDark) {
    if (!state.hasBudget) return const SizedBox.shrink();
    final pct     = state.budgetUsedPct;
    final isOver  = state.isOverBudget;
    final color   = isOver
        ? AppTheme.error
        : pct > 0.8
            ? AppTheme.warning
            : AppTheme.accent;
    final fmt     = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(
                isOver
                    ? Icons.warning_amber_rounded
                    : Icons.savings_outlined,
                color: color, size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isOver ? 'Over Budget!' : 'Monthly Budget',
                style: GoogleFonts.poppins(
                    color: color, fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ]),
            Text(
              '${fmt.format(state.monthTotal)} / ${fmt.format(state.monthlyBudget)}',
              style: GoogleFonts.poppins(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0, 1),
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isOver
                  ? 'Over by ${fmt.format(state.monthTotal - state.monthlyBudget)}'
                  : '${fmt.format(state.budgetRemaining)} remaining',
              style: GoogleFonts.poppins(color: color, fontSize: 11),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCategoryScroll(AppState state, bool isDark, NumberFormat fmt) {
    final cats = state.categoryTotals;
    if (cats.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: cats.length,
        itemBuilder: (ctx, i) {
          final entry = cats.entries.elementAt(i);
          final color = AppTheme.categoryColors[entry.key] ?? AppTheme.lightSubText;
          final icon  = AppTheme.categoryIcons[entry.key]  ?? '📦';
          return Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(entry.key,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: color,
                          fontWeight: FontWeight.w500)),
                  Text(fmt.format(entry.value),
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: color)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext ctx, bool isDark, Color textColor) {
    final cardColor = isDark ? AppTheme.darkCard   : AppTheme.lightCard;
    final border    = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final shell     = ctx.findAncestorStateOfType<MainShellState>();

    final actions = [
      {'e': '📋', 'l': 'All\nExpenses',
        'fn': () => Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => const ExpenseListScreen()))},
      {'e': '➕', 'l': 'Add\nExpense', 'fn': () => _goAdd(ctx)},
      {'e': '📊', 'l': 'Analytics',   'fn': () => shell?.setTab(1)},
      {'e': '🎯', 'l': 'Budget',      'fn': () => shell?.setTab(2)},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 10, 8),
      child: Row(
        children: actions.map((a) => Expanded(
          child: GestureDetector(
            onTap: a['fn'] as VoidCallback,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Column(children: [
                Text(a['e'] as String,
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 5),
                Text(a['l'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 9.5, color: textColor,
                        fontWeight: FontWeight.w500, height: 1.3)),
              ]),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRecentHeader(
      BuildContext ctx, AppState state, Color textColor) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Expenses',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: textColor)),
            TextButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => const ExpenseListScreen())),
              child: Text('See All',
                  style: GoogleFonts.poppins(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Widget _fab(BuildContext ctx) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'home_fab',
          onPressed: () => _goAdd(ctx),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('Add Expense',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );

  void _goAdd(BuildContext ctx) =>
      Navigator.of(ctx).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const AddExpenseScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ));

  void _goEdit(BuildContext ctx, Expense e) =>
      Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => AddExpenseScreen(expense: e)));

  void _confirmDelete(BuildContext ctx, AppState state, Expense e) =>
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Expense',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Delete "${e.title}"?',
              style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: AppTheme.lightSubText)),
            ),
            ElevatedButton(
              onPressed: () {
                state.deleteExpense(e.id);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error),
              child: Text('Delete',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
}
