import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';

import '../models/report_model.dart';
import '../models/tenant_model.dart';
import '../models/expense_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate Financial Summary
  Future<FinancialSummary> generateFinancialSummary(
    String buildingId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Get all tenants for the building
      QuerySnapshot tenantsSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('tenants')
          .get();

      List<Tenant> tenants = tenantsSnapshot.docs
          .map((doc) => Tenant.fromFirestore(doc))
          .toList();

      // Get all expenses for the period
      QuerySnapshot expensesSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      List<Expense> expenses = expensesSnapshot.docs
          .map((doc) => Expense.fromFirestore(doc))
          .toList();

      // Get SMS transactions (payments) for the period
      QuerySnapshot paymentsSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('smsTransactions')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      // Calculate totals
      double totalIncome = 0;
      Map<String, double> incomeByCategory = {'Rent': 0, 'Deposits': 0, 'Other': 0};

      for (var doc in paymentsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double amount = (data['amount'] ?? 0).toDouble();
        totalIncome += amount;
        incomeByCategory['Rent'] = (incomeByCategory['Rent'] ?? 0) + amount;
      }

      double totalExpenses = 0;
      Map<String, double> expensesByCategory = {};

      for (var expense in expenses) {
        totalExpenses += expense.amount;
        expensesByCategory[expense.category] = 
            (expensesByCategory[expense.category] ?? 0) + expense.amount;
      }

      // Calculate occupancy
      int totalUnits = tenants.length;
      int occupiedUnits = tenants.where((t) => t.status == 'active').length;
      int vacantUnits = totalUnits - occupiedUnits;
      double occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0;

      // Calculate average rent
      double totalRent = tenants.fold(0, (sum, tenant) => sum + tenant.rentAmount);
      double averageRent = totalUnits > 0 ? totalRent / totalUnits : 0;

      double netProfit = totalIncome - totalExpenses;

      return FinancialSummary(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        occupancyRate: occupancyRate,
        totalUnits: totalUnits,
        occupiedUnits: occupiedUnits,
        vacantUnits: vacantUnits,
        averageRent: averageRent,
        incomeByCategory: incomeByCategory,
        expensesByCategory: expensesByCategory,
        periodStart: startDate,
        periodEnd: endDate,
      );
    } catch (e) {
      throw Exception('Failed to generate financial summary: $e');
    }
  }

  // Generate Rent Collection Report
  Future<List<RentCollectionReport>> generateRentCollectionReport(
    String buildingId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Get all tenants
      QuerySnapshot tenantsSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('tenants')
          .get();

      List<Tenant> tenants = tenantsSnapshot.docs
          .map((doc) => Tenant.fromFirestore(doc))
          .toList();

      // Get payments for the period
      QuerySnapshot paymentsSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('smsTransactions')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, List<Map<String, dynamic>>> paymentsByUnit = {};
      for (var doc in paymentsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String unitRef = data['unitReference'] ?? '';
        if (unitRef.isNotEmpty) {
          paymentsByUnit[unitRef] = paymentsByUnit[unitRef] ?? [];
          paymentsByUnit[unitRef]!.add(data);
        }
      }

      List<RentCollectionReport> reports = [];

      for (var tenant in tenants) {
        String unitRef = '${tenant.unitNumber}'; // Simplified unit reference
        List<Map<String, dynamic>> unitPayments = paymentsByUnit[unitRef] ?? [];
        
        double paidAmount = unitPayments.fold(0, (sum, payment) => 
            sum + ((payment['amount'] ?? 0) as num).toDouble());
        
        double expectedRent = tenant.rentAmount;
        double outstandingAmount = expectedRent - paidAmount;
        
        DateTime dueDate = DateTime(endDate.year, endDate.month, 5); // Assume rent due on 5th
        DateTime? paymentDate = unitPayments.isNotEmpty 
            ? (unitPayments.last['date'] as Timestamp).toDate()
            : null;
        
        String status = 'overdue';
        if (paidAmount >= expectedRent) {
          status = 'paid';
        } else if (paidAmount > 0) {
          status = 'partial';
        }
        
        int daysOverdue = paymentDate == null 
            ? DateTime.now().difference(dueDate).inDays
            : 0;
        
        reports.add(RentCollectionReport(
          tenantId: tenant.id,
          tenantName: tenant.name,
          unitNumber: tenant.unitNumber,
          expectedRent: expectedRent,
          paidAmount: paidAmount,
          outstandingAmount: outstandingAmount,
          dueDate: dueDate,
          paymentDate: paymentDate,
          status: status,
          daysOverdue: daysOverdue > 0 ? daysOverdue : 0,
        ));
      }

      return reports;
    } catch (e) {
      throw Exception('Failed to generate rent collection report: $e');
    }
  }

  // Generate Arrears Report
  Future<List<RentCollectionReport>> generateArrearsReport(
    String buildingId,
    DateTime endDate,
  ) async {
    try {
      List<RentCollectionReport> allReports = await generateRentCollectionReport(
        buildingId,
        DateTime(endDate.year, endDate.month, 1),
        endDate,
      );

      // Filter only tenants with outstanding amounts
      return allReports.where((report) => report.outstandingAmount > 0).toList();
    } catch (e) {
      throw Exception('Failed to generate arrears report: $e');
    }
  }

  // Export to CSV
  String exportToCSV(List<Map<String, dynamic>> data, List<String> headers) {
    List<List<dynamic>> csvData = [headers];
    
    for (var row in data) {
      List<dynamic> csvRow = [];
      for (var header in headers) {
        csvRow.add(row[header] ?? '');
      }
      csvData.add(csvRow);
    }
    
    return const ListToCsvConverter().convert(csvData);
  }

  // Convert Financial Summary to exportable data
  List<Map<String, dynamic>> financialSummaryToExportData(FinancialSummary summary) {
    return [
      {
        'Metric': 'Total Income',
        'Amount': 'KES ${summary.totalIncome.toStringAsFixed(2)}',
        'Period': '${summary.periodStart.day}/${summary.periodStart.month}/${summary.periodStart.year} - ${summary.periodEnd.day}/${summary.periodEnd.month}/${summary.periodEnd.year}',
      },
      {
        'Metric': 'Total Expenses',
        'Amount': 'KES ${summary.totalExpenses.toStringAsFixed(2)}',
        'Period': '${summary.periodStart.day}/${summary.periodStart.month}/${summary.periodStart.year} - ${summary.periodEnd.day}/${summary.periodEnd.month}/${summary.periodEnd.year}',
      },
      {
        'Metric': 'Net Profit',
        'Amount': 'KES ${summary.netProfit.toStringAsFixed(2)}',
        'Period': '${summary.periodStart.day}/${summary.periodStart.month}/${summary.periodStart.year} - ${summary.periodEnd.day}/${summary.periodEnd.month}/${summary.periodEnd.year}',
      },
      {
        'Metric': 'Occupancy Rate',
        'Amount': '${summary.occupancyRate.toStringAsFixed(1)}%',
        'Period': 'Current',
      },
      {
        'Metric': 'Total Units',
        'Amount': '${summary.totalUnits}',
        'Period': 'Current',
      },
      {
        'Metric': 'Occupied Units',
        'Amount': '${summary.occupiedUnits}',
        'Period': 'Current',
      },
      {
        'Metric': 'Vacant Units',
        'Amount': '${summary.vacantUnits}',
        'Period': 'Current',
      },
      {
        'Metric': 'Average Rent',
        'Amount': 'KES ${summary.averageRent.toStringAsFixed(2)}',
        'Period': 'Current',
      },
    ];
  }

  // Convert Rent Collection Report to exportable data
  List<Map<String, dynamic>> rentCollectionToExportData(List<RentCollectionReport> reports) {
    return reports.map((report) => {
      'Tenant Name': report.tenantName,
      'Unit Number': report.unitNumber,
      'Expected Rent': 'KES ${report.expectedRent.toStringAsFixed(2)}',
      'Paid Amount': 'KES ${report.paidAmount.toStringAsFixed(2)}',
      'Outstanding Amount': 'KES ${report.outstandingAmount.toStringAsFixed(2)}',
      'Due Date': '${report.dueDate.day}/${report.dueDate.month}/${report.dueDate.year}',
      'Payment Date': report.paymentDate != null 
          ? '${report.paymentDate!.day}/${report.paymentDate!.month}/${report.paymentDate!.year}'
          : 'Not Paid',
      'Status': report.status.toUpperCase(),
      'Days Overdue': '${report.daysOverdue}',
    }).toList();
  }

  // Save report to Firestore
  Future<String> saveReport(Report report) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('reports')
          .add(report.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save report: $e');
    }
  }

  // Get reports for a building
  Future<List<Report>> getReports(String buildingId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reports')
          .where('propertyId', isEqualTo: buildingId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get reports: $e');
    }
  }

  // Get tenants with arrears (for SMS targeting)
  Future<List<Tenant>> getTenantsWithArrears(String buildingId) async {
    try {
      List<RentCollectionReport> arrearsReport = await generateArrearsReport(
        buildingId,
        DateTime.now(),
      );

      List<String> tenantIds = arrearsReport.map((r) => r.tenantId).toList();
      
      if (tenantIds.isEmpty) return [];

      QuerySnapshot tenantsSnapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('tenants')
          .where(FieldPath.documentId, whereIn: tenantIds)
          .get();

      return tenantsSnapshot.docs
          .map((doc) => Tenant.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get tenants with arrears: $e');
    }
  }
}