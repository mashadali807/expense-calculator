import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _fmt    = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final _fmtFull = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;

  Map<int, double>    _dailyTotals    = {};
  Map<String, double> _categoryTotals = {};
  double              _monthTotal     = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final state = context.read<AppState>();
    final y = _selectedMonth.year;
    final m = _selectedMonth.month;
    final results = await Future.wait([
      state.getDailyTotalsForMonth(y, m),
      state.getCategoryTotalsForMonth(y, m),
      state.getExpensesForMonth(y, m),
    ]);
    _dailyTotals    = results[0] as Map<int, double>;
    _categoryTotals = results[1] as Map<String, double>;
    final expenses  = results[2] as List;
    _monthTotal     = expenses.fold(0.0, (s, e) => s + (e.amount as double));
    setState(() => _isLoading = false);
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now  = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month + 1))) return;
    setState(() => _selectedMonth = next);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = context.watch<AppState>().isDarkMode;
    final bg         = isDark ? AppTheme.darkBg    : AppTheme.lightBg;
    final textColor  = isDark ? AppTheme.darkText  : AppTheme.lightText;
    final subColor   = isDark ? AppTheme.darkSubText : AppTheme.lightSubText;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _isLoading
            ? const LoadingWidget(message: 'Loading analytics…')
            : CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _buildMonthPicker(textColor, subColor, isDark)),
                SliverToBoxAdapter(child: _buildMonthSummary(isDark, textColor, subColor)),
                if (_dailyTotals.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionHeader('Daily Spending', textColor)),
                  SliverToBoxAdapter(child: _buildBarChart(isDark, subColor)),
                ],
                if (_categoryTotals.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionHeader('Category Breakdown', textColor)),
                  SliverToBoxAdapter(child: _buildPieChart(isDark, textColor, subColor)),
                  SliverToBoxAdapter(child: _buildCategoryList(isDark, textColor, subColor)),
                ],
                if (_dailyTotals.isEmpty && _categoryTotals.isEmpty)
                  SliverFillRemaining(
                    child: EmptyStateWidget(
                      emoji: '📊',
                      title: 'No data yet',
                      subtitle: 'Add expenses this month to see your analytics',
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ]),
      ),
    );
  }

  Widget _buildMonthPicker(Color textColor, Color subColor, bool isDark) {
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: textColor),
          onPressed: _prevMonth,
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 16, color: textColor),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded, color: textColor),
          onPressed: _nextMonth,
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _buildMonthSummary(bool isDark, Color textColor, Color subColor) {
    final appState  = context.read<AppState>();
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final isCurrentMonth =
        _selectedMonth.year  == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(children: [
        Expanded(child: _statCard('Month Total', _fmtFull.format(_monthTotal),
            AppTheme.primary, '🗓️', cardColor, isDark)),
        const SizedBox(width: 12),
        if (isCurrentMonth) ...[
          Expanded(child: _statCard('Today', _fmtFull.format(appState.todayTotal),
              AppTheme.accent, '📅', cardColor, isDark)),
          const SizedBox(width: 12),
        ],
        Expanded(child: _statCard('Transactions',
            _categoryTotals.values.fold(0, (s, _) => s + 1).toString(),
            AppTheme.warning, '🔢', cardColor, isDark)),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color,
      String icon, Color cardColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.lightSubText)),
      ]),
    );
  }

  Widget _sectionHeader(String title, Color textColor) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 16, color: textColor)),
      );

  Widget _buildBarChart(bool isDark, Color subColor) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final maxY = _dailyTotals.values.isEmpty
        ? 100.0
        : (_dailyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2);
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  'Day ${group.x + 1}\n${_fmt.format(rod.toY)}',
                  GoogleFonts.poppins(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (v, _) => Text(
                    _fmt.format(v),
                    style: GoogleFonts.poppins(fontSize: 9, color: subColor),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final day = v.toInt() + 1;
                    if (day % 5 != 0 && day != 1) return const SizedBox.shrink();
                    return Text('$day',
                        style: GoogleFonts.poppins(fontSize: 9, color: subColor));
                  },
                ),
              ),
              rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: subColor.withOpacity(0.15), strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(daysInMonth, (i) {
              final day   = i + 1;
              final value = _dailyTotals[day] ?? 0;
              return BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: value,
                  width: (MediaQuery.of(context).size.width - 100) / daysInMonth - 1.5,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: value > 0
                      ? const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter)
                      : null,
                  color: value == 0 ? subColor.withOpacity(0.15) : null,
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(bool isDark, Color textColor, Color subColor) {
    final total     = _categoryTotals.values.fold(0.0, (s, v) => s + v);
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final entries   = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(children: [
        SizedBox(
          width: 160, height: 160,
          child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 44,
            sections: entries.map((e) {
              final color = AppTheme.categoryColors[e.key] ?? AppTheme.lightSubText;
              final pct   = total > 0 ? (e.value / total * 100) : 0;
              return PieChartSectionData(
                color: color,
                value: e.value,
                title: '${pct.toStringAsFixed(0)}%',
                radius: 52,
                titleStyle: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white),
                badgeWidget: pct < 8
                    ? null
                    : Text(AppTheme.categoryIcons[e.key] ?? '',
                        style: const TextStyle(fontSize: 14)),
                badgePositionPercentageOffset: 1.3,
              );
            }).toList(),
          )),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.take(5).map((e) {
              final color = AppTheme.categoryColors[e.key] ?? AppTheme.lightSubText;
              final icon  = AppTheme.categoryIcons[e.key] ?? '📦';
              final pct   = total > 0 ? (e.value / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(e.key,
                          style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w500,
                              color: textColor)),
                      LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Text('${pct.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildCategoryList(bool isDark, Color textColor, Color subColor) {
    final entries = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: entries.map((e) {
          final color = AppTheme.categoryColors[e.key] ?? AppTheme.lightSubText;
          final icon  = AppTheme.categoryIcons[e.key] ?? '📦';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(e.key,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: textColor)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _monthTotal > 0 ? (e.value / _monthTotal) : 0,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Text(_fmtFull.format(e.value),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}
