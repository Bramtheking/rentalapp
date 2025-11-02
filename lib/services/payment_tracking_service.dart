import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sms_format_model.dart';

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
      // Get payment structure for the unit
      final paymentStructure = await _getPaymentStructure(buildingId, unitRef);
      if (paymentStructure == null) {
        return PaymentResult(
          success: false,
          message: 'No payment structure found for unit $unitRef',
          isComplete: false,
          remainingAmount: amount,
        );
      }

      // Get existing partial payments for current month
      final currentMonth = DateTime(paymentDate.year, paymentDate.month);
      final existingPayments = await _getMonthlyPayments(buildingId, unitRef, currentMonth);
      
      // Calculate total paid so far
      double totalPaid = existingPayments.fold(0.0, (sum, payment) => sum + payment['amount']);
      double newTotal = totalPaid + amount;
      
      // Determine payment status
      bool isComplete = newTotal >= paymentStructure.totalRent;
      double remainingAmount = isComplete ? 0.0 : paymentStructure.totalRent - newTotal;
      
      // Calculate payment breakdown based on amount
      Map<String, double> paymentBreakdown = _calculatePaymentBreakdown(
        paymentStructure, 
        amount, 
        existingPayments,
      );

      // Create payment record
      final paymentData = {
        'unitRef': unitRef,
        'amount': amount,
        'totalPaid': newTotal,
        'requiredAmount': paymentStructure.totalRent,
        'remainingAmount': remainingAmount,
        'paymentDate': Timestamp.fromDate(paymentDate),
        'month': Timestamp.fromDate(currentMonth),
        'reference': reference,
        'method': method,
        'status': isComplete ? 'complete' : 'partial',
        'breakdown': paymentBreakdown,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save payment
      await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('payments')
          .add(paymentData);

      // Update unit's payment status
      await _updateUnitPaymentStatus(buildingId, unitRef, newTotal, paymentStructure.totalRent, paymentDate);

      // Calculate penalties if applicable
      if (isComplete) {
        await _clearPenalties(buildingId, unitRef, currentMonth);
      } else {
        await _calculatePenalties(buildingId, unitRef, paymentStructure, paymentDate);
      }

      return PaymentResult(
        success: true,
        message: isComplete 
            ? 'Payment completed successfully!'
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

  /// Get payment structure for a unit
  Future<PaymentStructure?> _getPaymentStructure(String buildingId, String unitRef) async {
    try {
      final doc = await _firestore.collection('rentals').doc(buildingId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final paymentStructures = data['paymentStructure'] as Map<String, dynamic>?;
      
      if (paymentStructures == null || !paymentStructures.containsKey(unitRef)) {
        return null;
      }

      return PaymentStructure.fromMap(paymentStructures[unitRef], unitRef);
    } catch (e) {
      return null;
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
      final endOfMonth = Timestamp.fromDate(DateTime(month.year, month.month + 1, 0, 23, 59, 59));

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
    PaymentStructure structure,
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

    // Distribute the new payment amount
    double remainingAmount = paymentAmount;
    
    // Priority order: rent, water, bin, electricity, others
    List<String> priorityOrder = ['rent', 'water', 'bin', 'electricity'];
    List<String> otherCategories = structure.breakdown.keys
        .where((key) => !priorityOrder.contains(key))
        .toList();
    
    List<String> allCategories = [...priorityOrder, ...otherCategories];
    
    for (String category in allCategories) {
      if (!structure.breakdown.containsKey(category)) continue;
      
      double required = structure.breakdown[category]!;
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
    String unitRef,
    double totalPaid,
    double requiredAmount,
    DateTime paymentDate,
  ) async {
    try {
      // Find the unit document
      final unitsSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('units')
          .where('unitNumber', isEqualTo: unitRef)
          .limit(1)
          .get();

      if (unitsSnapshot.docs.isNotEmpty) {
        final unitDoc = unitsSnapshot.docs.first;
        await unitDoc.reference.update({
          'lastPaymentAmount': totalPaid,
          'lastPaymentDate': Timestamp.fromDate(paymentDate),
          'paymentStatus': totalPaid >= requiredAmount ? 'complete' : 'partial',
          'remainingAmount': requiredAmount - totalPaid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating unit payment status: $e');
    }
  }

  /// Calculate and apply penalties
  Future<void> _calculatePenalties(
    String buildingId,
    String unitRef,
    PaymentStructure structure,
    DateTime paymentDate,
  ) async {
    try {
      final currentMonth = DateTime(paymentDate.year, paymentDate.month);
      final dueDate = DateTime(currentMonth.year, currentMonth.month, structure.dueDate);
      
      if (paymentDate.isAfter(dueDate)) {
        // Calculate days late
        int daysLate = paymentDate.difference(dueDate).inDays;
        
        // Get existing payments to determine penalty type
        final existingPayments = await _getMonthlyPayments(buildingId, unitRef, currentMonth);
        double totalPaid = existingPayments.fold(0.0, (sum, payment) => sum + payment['amount']);
        
        double penaltyAmount = 0;
        String penaltyType = '';
        
        if (totalPaid == 0) {
          // No payment at all - late rent penalty
          penaltyAmount = (structure.penalties['lateRentPerDay'] ?? 0) * daysLate;
          penaltyType = 'lateRent';
        } else if (totalPaid < structure.totalRent) {
          // Partial payment - partial payment penalty
          penaltyAmount = (structure.penalties['partialPaymentPerDay'] ?? 0) * daysLate;
          penaltyType = 'partialPayment';
        }
        
        if (penaltyAmount > 0) {
          // Save penalty record
          await _firestore
              .collection('rentals')
              .doc(buildingId)
              .collection('penalties')
              .add({
            'unitRef': unitRef,
            'month': Timestamp.fromDate(currentMonth),
            'penaltyType': penaltyType,
            'daysLate': daysLate,
            'penaltyAmount': penaltyAmount,
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
      final paymentStructure = await _getPaymentStructure(buildingId, unitRef);
      if (paymentStructure == null) {
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

      final payments = await _getMonthlyPayments(buildingId, unitRef, month);
      final penalties = await _getMonthlyPenalties(buildingId, unitRef, month);
      
      double totalPaid = payments.fold(0.0, (sum, payment) => sum + payment['amount']);
      double remainingAmount = paymentStructure.totalRent - totalPaid;
      bool isComplete = remainingAmount <= 0;

      return PaymentSummary(
        unitRef: unitRef,
        month: month,
        requiredAmount: paymentStructure.totalRent,
        totalPaid: totalPaid,
        remainingAmount: remainingAmount > 0 ? remainingAmount : 0,
        isComplete: isComplete,
        payments: payments,
        penalties: penalties,
        breakdown: paymentStructure.breakdown,
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