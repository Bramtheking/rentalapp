import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all expenses for a rental
  Stream<List<Expense>> getExpenses(String rentalId) {
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Expense.fromFirestore(doc))
            .toList());
  }

  // Get recurring expenses only
  Stream<List<Expense>> getRecurringExpenses(String rentalId) {
    print('DEBUG: Querying recurring expenses with isRecurring=true + orderBy nextDueDate');
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .where('isRecurring', isEqualTo: true)
        .orderBy('nextDueDate')
        .snapshots()
        .handleError((error) {
          print('ERROR in getRecurringExpenses: $error');
          if (error.toString().contains('index')) {
            print('INDEX REQUIRED: Create composite index for isRecurring (Ascending) + nextDueDate (Ascending)');
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Expense.fromFirestore(doc))
            .toList());
  }

  // Get one-time expenses only
  Stream<List<Expense>> getOneTimeExpenses(String rentalId) {
    print('DEBUG: Querying one-time expenses with isRecurring=false + orderBy date desc');
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .where('isRecurring', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .handleError((error) {
          print('ERROR in getOneTimeExpenses: $error');
          if (error.toString().contains('index')) {
            print('INDEX REQUIRED: Create composite index for isRecurring (Ascending) + date (Descending)');
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Expense.fromFirestore(doc))
            .toList());
  }

  // Add new expense
  Future<void> addExpense(String rentalId, Expense expense) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .add(expense.toFirestore());
  }

  // Update expense
  Future<void> updateExpense(String rentalId, Expense expense) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .doc(expense.id)
        .update(expense.toFirestore());
  }

  // Delete expense
  Future<void> deleteExpense(String rentalId, String expenseId) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  // Get expense statistics
  Future<Map<String, dynamic>> getExpenseStats(String rentalId) async {
    final expensesSnapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .get();

    double totalExpenses = 0;
    double recurringExpenses = 0;
    double oneTimeExpenses = 0;
    Map<String, double> expensesByCategory = {};
    int totalCount = expensesSnapshot.docs.length;

    for (var doc in expensesSnapshot.docs) {
      final expense = Expense.fromFirestore(doc);
      totalExpenses += expense.amount;
      
      if (expense.isRecurring) {
        recurringExpenses += expense.amount;
      } else {
        oneTimeExpenses += expense.amount;
      }

      // Group by category
      expensesByCategory[expense.category] = 
          (expensesByCategory[expense.category] ?? 0) + expense.amount;
    }

    return {
      'totalExpenses': totalExpenses,
      'recurringExpenses': recurringExpenses,
      'oneTimeExpenses': oneTimeExpenses,
      'expensesByCategory': expensesByCategory,
      'totalCount': totalCount,
    };
  }

  // Generate receipt number
  Future<String> generateReceiptNumber(String rentalId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .where('isRecurring', isEqualTo: false)
        .get();
    
    int nextNumber = snapshot.docs.length + 1;
    return 'RCP-${nextNumber.toString().padLeft(3, '0')}';
  }

  // Calculate next due date for recurring expenses
  DateTime calculateNextDueDate(DateTime currentDate, String frequency) {
    switch (frequency.toLowerCase()) {
      case 'monthly':
        return DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
      case 'quarterly':
        return DateTime(currentDate.year, currentDate.month + 3, currentDate.day);
      case 'yearly':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
      default:
        return DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
    }
  }
}