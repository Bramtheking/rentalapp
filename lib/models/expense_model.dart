import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String? receiptNumber;
  final String? receiptUrl;
  final bool isRecurring;
  final String? frequency; // 'monthly', 'quarterly', 'yearly'
  final DateTime? nextDueDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.receiptNumber,
    this.receiptUrl,
    required this.isRecurring,
    this.frequency,
    this.nextDueDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? '',
      receiptNumber: data['receiptNumber'],
      receiptUrl: data['receiptUrl'],
      isRecurring: data['isRecurring'] ?? false,
      frequency: data['frequency'],
      nextDueDate: data['nextDueDate'] != null 
          ? (data['nextDueDate'] as Timestamp).toDate() 
          : null,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'receiptNumber': receiptNumber,
      'receiptUrl': receiptUrl,
      'isRecurring': isRecurring,
      'frequency': frequency,
      'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Expense copyWith({
    String? description,
    double? amount,
    DateTime? date,
    String? category,
    String? receiptNumber,
    String? receiptUrl,
    bool? isRecurring,
    String? frequency,
    DateTime? nextDueDate,
    String? notes,
  }) {
    return Expense(
      id: id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class ExpenseCategory {
  final String id;
  final String name;
  final String description;
  final String color;
  final bool isActive;
  final DateTime createdAt;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.isActive,
    required this.createdAt,
  });

  factory ExpenseCategory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ExpenseCategory(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      color: data['color'] ?? '#9E9E9E',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}