import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String title;
  final String type; // 'rent_collection', 'expense', 'profit_loss', 'arrears'
  final DateTime startDate;
  final DateTime endDate;
  final String? propertyId;
  final String status; // 'generating', 'completed', 'failed'
  final String? fileUrl;
  final String format; // 'pdf', 'excel', 'csv'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String createdBy;

  Report({
    required this.id,
    required this.title,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.propertyId,
    required this.status,
    this.fileUrl,
    required this.format,
    required this.data,
    required this.createdAt,
    required this.createdBy,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      propertyId: data['propertyId'],
      status: data['status'] ?? 'generating',
      fileUrl: data['fileUrl'],
      format: data['format'] ?? 'pdf',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'propertyId': propertyId,
      'status': status,
      'fileUrl': fileUrl,
      'format': format,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}

class FinancialSummary {
  final double totalIncome;
  final double totalExpenses;
  final double netProfit;
  final double occupancyRate;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final double averageRent;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expensesByCategory;
  final DateTime periodStart;
  final DateTime periodEnd;

  FinancialSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netProfit,
    required this.occupancyRate,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.averageRent,
    required this.incomeByCategory,
    required this.expensesByCategory,
    required this.periodStart,
    required this.periodEnd,
  });

  factory FinancialSummary.fromMap(Map<String, dynamic> data) {
    return FinancialSummary(
      totalIncome: (data['totalIncome'] ?? 0).toDouble(),
      totalExpenses: (data['totalExpenses'] ?? 0).toDouble(),
      netProfit: (data['netProfit'] ?? 0).toDouble(),
      occupancyRate: (data['occupancyRate'] ?? 0).toDouble(),
      totalUnits: data['totalUnits'] ?? 0,
      occupiedUnits: data['occupiedUnits'] ?? 0,
      vacantUnits: data['vacantUnits'] ?? 0,
      averageRent: (data['averageRent'] ?? 0).toDouble(),
      incomeByCategory: Map<String, double>.from(data['incomeByCategory'] ?? {}),
      expensesByCategory: Map<String, double>.from(data['expensesByCategory'] ?? {}),
      periodStart: (data['periodStart'] as Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'occupancyRate': occupancyRate,
      'totalUnits': totalUnits,
      'occupiedUnits': occupiedUnits,
      'vacantUnits': vacantUnits,
      'averageRent': averageRent,
      'incomeByCategory': incomeByCategory,
      'expensesByCategory': expensesByCategory,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }
}

class RentCollectionReport {
  final String tenantId;
  final String tenantName;
  final String unitNumber;
  final double expectedRent;
  final double paidAmount;
  final double outstandingAmount;
  final DateTime dueDate;
  final DateTime? paymentDate;
  final String status; // 'paid', 'partial', 'overdue'
  final int daysOverdue;

  RentCollectionReport({
    required this.tenantId,
    required this.tenantName,
    required this.unitNumber,
    required this.expectedRent,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.dueDate,
    this.paymentDate,
    required this.status,
    required this.daysOverdue,
  });

  factory RentCollectionReport.fromMap(Map<String, dynamic> data) {
    return RentCollectionReport(
      tenantId: data['tenantId'] ?? '',
      tenantName: data['tenantName'] ?? '',
      unitNumber: data['unitNumber'] ?? '',
      expectedRent: (data['expectedRent'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      outstandingAmount: (data['outstandingAmount'] ?? 0).toDouble(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paymentDate: data['paymentDate'] != null 
          ? (data['paymentDate'] as Timestamp).toDate() 
          : null,
      status: data['status'] ?? 'overdue',
      daysOverdue: data['daysOverdue'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'tenantName': tenantName,
      'unitNumber': unitNumber,
      'expectedRent': expectedRent,
      'paidAmount': paidAmount,
      'outstandingAmount': outstandingAmount,
      'dueDate': Timestamp.fromDate(dueDate),
      'paymentDate': paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'status': status,
      'daysOverdue': daysOverdue,
    };
  }
}