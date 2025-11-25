import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unit_model.dart';

class PaymentTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Process a payment and handle partial payment logic
  Future<PaymentResult> processPayment({
    required String buildingId,
    required String unitRef,
    required double amount,
    required DateTime paymentDate,
    required String reference,
    required String method,
  }) async {
    try {
      // Get unit data
      final unit = await _getUnit(buildingId, unitRef);
      if (unit == null) {
        return PaymentResult(
          success: false,
          message: 'Unit $unitRef not found',
          isComplete: false,
          remainingAmount: amount,
        );
      }

      // Calculate total required for this month
      final totalRequired = _calculateTotalRequired(unit);
      
      // Get existing partial payments for current month
      final currentMonth = DateTime(paymentDate.year, paymentDate.month);
      final existingPayments = await _getMonthlyPayments(buildingId, unitRef, currentMonth);
      
      // Calculate total paid so far (including credit balance)
      double totalPaidThisMonth = existingPayments.fold(0.0, (total, payment) => total + (payment['amount'] as num).toDouble());
      double effectiveAmount = amount + unit.creditBalance;
      double newTotal = totalPaidThisMonth + effectiveAmount;
      
      // Determine payment status
      bool isComplete = newTotal >= totalRequired;
      double remainingAmount = isComplete ? 0.0 : totalRequired - newTotal;
      double newCreditBalance = isComplete ? (newTotal - totalRequired) : 0.0;
      
      // Determine detailed status
      String detailedStatus = _determinePaymentStatus(newTotal, unit.baseRent, totalRequired);
      
      // Calculate payment breakdown based on amount
      Map<String, double> paymentBreakdown = _calculatePaymentBreakdown(
        unit, 
        effectiveAmount, 
        existingPayments,
      );

      // Create payment record
      final paymentData = {
        'unitRef': unitRef,
        'amount': amount,
        'totalPaid': newTotal,
        'requiredAmount': totalRequired,
        'remainingAmount': remainingAmount,
        'paymentDate': Timestamp.fromDate(paymentDate),
        'month': Timestamp.fromDate(currentMonth),
        'reference': reference,
        'method': method,
        'status': detailedStatus,
        'breakdown': paymentBreakdown,
        'creditUsed': unit.creditBalance,
        'newCreditBalance': newCreditBalance,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save payment
      await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('payments')
          .add(paymentData);

      // Update unit's payment status and credit balance
      await _updateUnitPaymentStatus(
        buildingId, 
        unit.id, 
        newTotal, 
        totalRequired, 
        paymentDate,
        detailedStatus,
        newCreditBalance,
      );

      // Calculate penalties if applicable
      if (isComplete) {
        await _clearPenalties(buildingId, unitRef, currentMonth);
      } else {
        await _calculatePenalties(buildingId, unitRef, unit, paymentDate, newTotal);
      }

      return PaymentResult(
        success: true,
        message: isComplete 
            ? 'Payment completed successfully!' + (newCreditBalance > 0 ? ' Credit: KES ${newCreditBalance.toStringAsFixed(0)}' : '')
            : 'Partial payment recorded. Remaining: KES ${remainingAmount.toStringAsFixed(0)}',
        isComplete: isComplete,
        remainingAmount: remainingAmount,
        totalPaid: newTotal,
        breakdown: paymentBreakdown,
      );

    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Error processing payment: $e',
        isComplete: false,
        remainingAmount: amount,
      );
    }
  }

  /// Get unit data
  Future<Unit?> _getUnit(String buildingId, String unitRef) async {
    try {
      final snapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('units')
          .where('unitNumber', isEqualTo: unitRef)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Unit.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  /// Calculate total required amount for the month
  double _calculateTotalRequired(Unit unit) {
    double total = unit.baseRent;
    
    // Add fixed bills
    unit.fixedBills.forEach((key, value) {
      total += value;
    });
    
    // Add current month bills (water, electricity)
    if (unit.currentMonthBills != null) {
      unit.currentMonthBills!.forEach((key, value) {
        total += value;
      });
    }
    
    return total;
  }

  /// Determine detailed payment status
  String _determinePaymentStatus(double totalPaid, double baseRent, double totalRequired) {
    if (totalPaid >= totalRequired) {
      return 'complete';
    } else if (totalPaid >= baseRent) {
      return 'rent_only'; // Paid rent but missing bills
    } else if (totalPaid > 0) {
      return 'partial_rent'; // Paid less than rent
    } else {
      return 'not_paid';
    }
  }

  /// Get existing payments for a specific month
  Future<List<Map<String, dynamic>>> _getMonthlyPayments(
    String buildingId, 
    String unitRef, 
    DateTime month,
  ) async {
    try {
      final startOfMonth = Timestamp.fromDate(month);

      final snapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('payments')
          .where('unitRef', isEqualTo: unitRef)
          .where('month', isEqualTo: startOfMonth)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Calculate how the payment amount should be distributed across breakdown items
  Map<String, double> _calculatePaymentBreakdown(
    Unit unit,
    double paymentAmount,
    List<Map<String, dynamic>> existingPayments,
  ) {
    Map<String, double> breakdown = {};
    
    // Calculate what's already been paid for each category
    Map<String, double> alreadyPaid = {};
    for (var payment in existingPayments) {
      final paymentBreakdown = Map<String, double>.from(payment['breakdown'] ?? {});
      paymentBreakdown.forEach((category, amount) {
        alreadyPaid[category] = (alreadyPaid[category] ?? 0) + amount;
      });
    }

    // Build complete breakdown structure
    Map<String, double> requiredAmounts = {
      'rent': unit.baseRent,
    };
    
    // Add fixed bills
    unit.fixedBills.forEach((key, value) {
      requiredAmounts[key] = value;
    });
    
    // Add current month bills
    if (unit.currentMonthBills != null) {
      unit.currentMonthBills!.forEach((key, value) {
        requiredAmounts[key] = value;
      });
    }

    // Distribute the new payment amount
    double remainingAmount = paymentAmount;
    
    // Priority order: rent, water, dustbin, electricity, others
    List<String> priorityOrder = ['rent', 'water', 'dustbin', 'electricity'];
    List<String> otherCategories = requiredAmounts.keys
        .where((key) => !priorityOrder.contains(key))
        .toList();
    
    List<String> allCategories = [...priorityOrder, ...otherCategories];
    
    for (String category in allCategories) {
      if (!requiredAmounts.containsKey(category)) continue;
      
      double required = requiredAmounts[category]!;
      double paid = alreadyPaid[category] ?? 0;
      double needed = required - paid;
      
      if (needed > 0 && remainingAmount > 0) {
        double toAllocate = remainingAmount >= needed ? needed : remainingAmount;
        breakdown[category] = toAllocate;
        remainingAmount -= toAllocate;
      }
    }
    
    return breakdown;
  }

  /// Update unit's payment status
  Future<void> _updateUnitPaymentStatus(
    String buildingId,
    String unitId,
    double totalPaid,
    double requiredAmount,
    DateTime paymentDate,
    String status,
    double creditBalance,
  ) async {
    try {
      await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('units')
          .doc(unitId)
          .update({
        'totalPaid': totalPaid,
        'totalRequired': requiredAmount,
        'lastPaymentAmount': totalPaid,
        'lastPaymentDate': Timestamp.fromDate(paymentDate),
        'paymentStatus': status,
        'remainingAmount': requiredAmount - totalPaid,
        'creditBalance': creditBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating unit payment status: $e');
    }
  }

  /// Calculate and apply penalties (simple per-day system)
  Future<void> _calculatePenalties(
    String buildingId,
    String unitRef,
    Unit unit,
    DateTime paymentDate,
    double totalPaid,
  ) async {
    try {
      // Get building settings for due date and penalties
      final buildingDoc = await _firestore.collection('rentals').doc(buildingId).get();
      final buildingData = buildingDoc.data();
      final paymentSettings = buildingData?['paymentSettings'] as Map<String, dynamic>?;
      
      final dueDate = paymentSettings?['dueDate'] ?? 5;
      final perDayAmount = (paymentSettings?['penalties']?['perDayAmount'] ?? 50).toDouble();
      
      final currentMonth = DateTime(paymentDate.year, paymentDate.month);
      final dueDateThisMonth = DateTime(currentMonth.year, currentMonth.month, dueDate);
      
      if (paymentDate.isAfter(dueDateThisMonth)) {
        // Calculate days late
        int daysLate = paymentDate.difference(dueDateThisMonth).inDays;
        
        // Simple per-day penalty
        double penaltyAmount = perDayAmount * daysLate;
        
        if (penaltyAmount > 0) {
          // Save penalty record
          await _firestore
              .collection('rentals')
              .doc(buildingId)
              .collection('penalties')
              .add({
            'unitRef': unitRef,
            'month': Timestamp.fromDate(currentMonth),
            'daysLate': daysLate,
            'penaltyAmount': penaltyAmount,
            'totalPaid': totalPaid,
            'baseRent': unit.baseRent,
            'calculatedDate': FieldValue.serverTimestamp(),
            'status': 'active',
          });
        }
      }
    } catch (e) {
      print('Error calculating penalties: $e');
    }
  }

  /// Clear penalties when payment is completed
  Future<void> _clearPenalties(String buildingId, String unitRef, DateTime month) async {
    try {
      final penaltiesSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('penalties')
          .where('unitRef', isEqualTo: unitRef)
          .where('month', isEqualTo: Timestamp.fromDate(month))
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in penaltiesSnapshot.docs) {
        await doc.reference.update({'status': 'cleared'});
      }
    } catch (e) {
      print('Error clearing penalties: $e');
    }
  }

  /// Get payment summary for a unit and month
  Future<PaymentSummary> getPaymentSummary(
    String buildingId,
    String unitRef,
    DateTime month,
  ) async {
    try {
      final unit = await _getUnit(buildingId, unitRef);
      if (unit == null) {
        return PaymentSummary(
          unitRef: unitRef,
          month: month,
          requiredAmount: 0,
          totalPaid: 0,
          remainingAmount: 0,
          isComplete: false,
          payments: [],
          penalties: [],
        );
      }

      final totalRequired = _calculateTotalRequired(unit);
      final payments = await _getMonthlyPayments(buildingId, unitRef, month);
      final penalties = await _getMonthlyPenalties(buildingId, unitRef, month);
      
      double totalPaid = payments.fold(0.0, (total, payment) => total + (payment['amount'] as num).toDouble());
      double remainingAmount = totalRequired - totalPaid;
      bool isComplete = remainingAmount <= 0;

      // Build breakdown
      Map<String, double> breakdown = {
        'rent': unit.baseRent,
      };
      unit.fixedBills.forEach((key, value) {
        breakdown[key] = value;
      });
      if (unit.currentMonthBills != null) {
        unit.currentMonthBills!.forEach((key, value) {
          breakdown[key] = value;
        });
      }

      return PaymentSummary(
        unitRef: unitRef,
        month: month,
        requiredAmount: totalRequired,
        totalPaid: totalPaid,
        remainingAmount: remainingAmount > 0 ? remainingAmount : 0,
        isComplete: isComplete,
        payments: payments,
        penalties: penalties,
        breakdown: breakdown,
      );
    } catch (e) {
      return PaymentSummary(
        unitRef: unitRef,
        month: month,
        requiredAmount: 0,
        totalPaid: 0,
        remainingAmount: 0,
        isComplete: false,
        payments: [],
        penalties: [],
      );
    }
  }

  /// Get penalties for a specific month
  Future<List<Map<String, dynamic>>> _getMonthlyPenalties(
    String buildingId,
    String unitRef,
    DateTime month,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('penalties')
          .where('unitRef', isEqualTo: unitRef)
          .where('month', isEqualTo: Timestamp.fromDate(month))
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }
}

class PaymentResult {
  final bool success;
  final String message;
  final bool isComplete;
  final double remainingAmount;
  final double? totalPaid;
  final Map<String, double>? breakdown;

  PaymentResult({
    required this.success,
    required this.message,
    required this.isComplete,
    required this.remainingAmount,
    this.totalPaid,
    this.breakdown,
  });
}

class PaymentSummary {
  final String unitRef;
  final DateTime month;
  final double requiredAmount;
  final double totalPaid;
  final double remainingAmount;
  final bool isComplete;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> penalties;
  final Map<String, double>? breakdown;

  PaymentSummary({
    required this.unitRef,
    required this.month,
    required this.requiredAmount,
    required this.totalPaid,
    required this.remainingAmount,
    required this.isComplete,
    required this.payments,
    required this.penalties,
    this.breakdown,
  });
}