// ─────────────────────────────────────────────
//  Expense Model  –  Step 2: SQLite-ready
// ─────────────────────────────────────────────

class Expense {
  final String id;          // UUID primary key
  final String title;       // short label
  final double amount;      // positive value
  final String category;    // Food / Travel / Bills / …
  final DateTime date;      // day of expense
  final String? note;       // optional longer description
  final DateTime createdAt; // row creation timestamp

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    required this.createdAt,
  });

  // ── SQLite row → Expense ───────────────────
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  // ── Expense → SQLite row ───────────────────
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.millisecondsSinceEpoch,       // stored as INTEGER
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  // ── Non-destructive update ─────────────────
  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Expense(id: $id, title: $title, amount: \$${amount.toStringAsFixed(2)}, '
      'category: $category, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Expense && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
