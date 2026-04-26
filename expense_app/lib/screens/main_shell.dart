import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';
import 'tabs/home_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/budget_tab.dart';
import 'expense_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void setTab(int index) => setState(() => _currentIndex = index);

  static final _tabs = [
    const HomeTab(),
    const AnalyticsTab(),
    const BudgetTab(),
    const ExpenseListScreen(isTab: true),
  ];

  static const _tabItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home_rounded),       label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded),  label: 'Analytics'),
    BottomNavigationBarItem(icon: Icon(Icons.savings_outlined),   label: 'Budget'),
    BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded),   label: 'Expenses'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark      = context.watch<AppState>().isDarkMode;
    final bg          = isDark ? AppTheme.darkBg   : AppTheme.lightBg;
    final navBg       = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final border      = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: border, width: 1)),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: isDark ? AppTheme.darkSubText : AppTheme.lightSubText,
          selectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          items: _tabItems,
        ),
      ),
    );
  }
}
