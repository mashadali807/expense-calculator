import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDate;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final color       = AppTheme.categoryColors[expense.category] ?? AppTheme.lightSubText;
    final icon        = AppTheme.categoryIcons[expense.category]  ?? '📦';
    final cardColor   = isDark ? AppTheme.darkCard    : AppTheme.lightCard;
    final textColor   = isDark ? AppTheme.darkText    : AppTheme.lightText;
    final subColor    = isDark ? AppTheme.darkSubText : AppTheme.lightSubText;
    final borderColor = isDark ? AppTheme.darkBorder  : AppTheme.lightBorder;
    final fmt         = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Dismissible(
      key: Key(expense.id),
      background: _swipeBackground(
        color: AppTheme.primary,
        icon: Icons.edit_rounded,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
      ),
      secondaryBackground: _swipeBackground(
        color: AppTheme.error,
        icon: Icons.delete_rounded,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
      ),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        if (dir == DismissDirection.startToEnd) { onEdit(); return false; }
        else                                    { onDelete(); return false; }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Category icon bubble
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),

            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _chip(expense.category, color),
                    if (showDate) ...[
                      const SizedBox(width: 6),
                      Text(DateFormat('MMM d').format(expense.date),
                          style: GoogleFonts.poppins(fontSize: 11, color: subColor)),
                    ],
                    if (expense.note != null && expense.note!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.notes_rounded, size: 12, color: subColor),
                    ],
                  ]),
                ],
              ),
            ),

            // Amount + actions
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(expense.amount),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.error)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _iconBtn(Icons.edit_outlined,   AppTheme.primary, onEdit),
                const SizedBox(width: 4),
                _iconBtn(Icons.delete_outlined, AppTheme.error,   onDelete),
              ]),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Icon(icon, size: 18, color: color),
      );

  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
    required EdgeInsets padding,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
        alignment: alignment,
        padding: padding,
        child: Icon(icon, color: color),
      );
}
