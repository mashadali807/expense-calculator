import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../theme/app_theme.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});
  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  final _fmt       = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _budgetCtrl = TextEditingController();
  bool  _isEditing = false;

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBudget(AppState state) async {
    final val = double.tryParse(_budgetCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid amount',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    await state.setBudget(val);
    setState(() => _isEditing = false);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final state      = context.watch<AppState>();
    final isDark     = state.isDarkMode;
    final bg         = isDark ? AppTheme.darkBg       : AppTheme.lightBg;
    final cardColor  = isDark ? AppTheme.darkCard     : AppTheme.lightCard;
    final textColor  = isDark ? AppTheme.darkText     : AppTheme.lightText;
    final subColor   = isDark ? AppTheme.darkSubText  : AppTheme.lightSubText;
    final border     = isDark ? AppTheme.darkBorder   : AppTheme.lightBorder;

    final hasBudget  = state.hasBudget;
    final pct        = state.budgetUsedPct;
    final isOver     = state.isOverBudget;
    final meterColor = isOver
        ? AppTheme.error
        : pct > 0.8
            ? AppTheme.warning
            : AppTheme.accent;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Page header
            Text('Budget Planner',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 22, color: textColor)),
            Text(DateFormat('MMMM yyyy').format(DateTime.now()),
                style: GoogleFonts.poppins(fontSize: 13, color: subColor)),
            const SizedBox(height: 24),

            // ── Budget Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOver
                      ? [AppTheme.error, const Color(0xFFCC3333)]
                      : pct > 0.8
                          ? [AppTheme.warning, const Color(0xFFCC8800)]
                          : [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: meterColor.withOpacity(0.35),
                    blurRadius: 20, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOver ? '⚠️ Over Budget!' : pct > 0.8 ? '🔶 Almost Full' : '✅ On Track',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),

                if (hasBudget) ...[
                  // Radial-style gauge using PieChart
                  SizedBox(
                    width: 160, height: 160,
                    child: Stack(alignment: Alignment.center, children: [
                      PieChart(PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 0,
                        centerSpaceRadius: 58,
                        sections: [
                          PieChartSectionData(
                            value: (pct * 100).clamp(0, 100),
                            color: Colors.white,
                            radius: 14,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: ((1 - pct) * 100).clamp(0, 100),
                            color: Colors.white.withOpacity(0.2),
                            radius: 14,
                            showTitle: false,
                          ),
                        ],
                      )),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${(pct * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 28,
                                fontWeight: FontWeight.w800)),
                        Text('used',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 12)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Numbers row
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _budgetStat('Spent',     _fmt.format(state.monthTotal)),
                    Container(width: 1, height: 36,
                        color: Colors.white.withOpacity(0.3)),
                    _budgetStat('Budget',    _fmt.format(state.monthlyBudget)),
                    Container(width: 1, height: 36,
                        color: Colors.white.withOpacity(0.3)),
                    _budgetStat(
                        isOver ? 'Over by' : 'Remaining',
                        _fmt.format(isOver
                            ? state.monthTotal - state.monthlyBudget
                            : state.budgetRemaining)),
                  ]),
                ] else ...[
                  const Text('💰', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('No budget set',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Set a monthly budget to track your spending',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 13)),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            // ── Set / Edit Budget
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text(hasBudget ? 'Edit Budget' : 'Set Monthly Budget',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15,
                          color: textColor)),
                  if (hasBudget && !_isEditing)
                    TextButton.icon(
                      onPressed: () {
                        _budgetCtrl.text =
                            state.monthlyBudget.toStringAsFixed(2);
                        setState(() => _isEditing = true);
                      },
                      icon: const Icon(Icons.edit_outlined,
                          size: 16, color: AppTheme.primary),
                      label: Text('Edit',
                          style: GoogleFonts.poppins(color: AppTheme.primary)),
                    ),
                ]),

                if (!hasBudget || _isEditing) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _budgetCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: _isEditing,
                    style: GoogleFonts.poppins(color: textColor, fontSize: 15),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: GoogleFonts.poppins(
                          color: AppTheme.primary, fontWeight: FontWeight.w600),
                      hintText: '1000.00',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    if (_isEditing) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _isEditing = false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.lightSubText),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(color: subColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _saveBudget(state),
                        child: Text(_isEditing ? 'Save Changes' : 'Set Budget'),
                      ),
                    ),
                  ]),
                ],

                if (hasBudget && !_isEditing) ...[
                  const SizedBox(height: 16),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: meterColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(meterColor),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Text(_fmt.format(state.monthTotal),
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: meterColor,
                            fontWeight: FontWeight.w600)),
                    Text(_fmt.format(state.monthlyBudget),
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: subColor)),
                  ]),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            // ── Budget tips
            _buildTips(state, cardColor, textColor, subColor, border, isDark),

            const SizedBox(height: 80),
          ]),
        ),
      ),
    );
  }

  Widget _budgetStat(String label, String value) => Column(children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
      ]);

  Widget _buildTips(AppState state, Color cardColor, Color textColor,
      Color subColor, Color border, bool isDark) {
    final tips = <Map<String, String>>[];

    if (!state.hasBudget) {
      tips.add({'icon': '💡', 'tip': 'Set a monthly budget to stay in control of your finances.'});
    } else if (state.isOverBudget) {
      tips.add({'icon': '🚨', 'tip': 'You\'ve exceeded your budget. Consider cutting discretionary spending.'});
    } else if (state.budgetUsedPct > 0.8) {
      tips.add({'icon': '⚠️', 'tip': 'You\'ve used over 80% of your budget with days remaining.'});
    } else {
      tips.add({'icon': '🌟', 'tip': 'Great job! You\'re on track with your budget this month.'});
    }

    tips.add({'icon': '📊', 'tip': 'Check Analytics to see where most of your money goes.'});
    tips.add({'icon': '🎯', 'tip': 'The 50/30/20 rule: 50% needs, 30% wants, 20% savings.'});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tips',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 16, color: textColor)),
        const SizedBox(height: 10),
        ...tips.map((t) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['icon']!, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t['tip']!,
                      style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                ),
              ]),
            )),
      ],
    );
  }
}
