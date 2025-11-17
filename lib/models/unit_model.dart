import 'package:cloud_firestore/cloud_firestore.dart';

class Unit {
  final String id;
  final String unitNumber;
  final String unitName;
  final String type;
  final String status; // 'occupied', 'vacant', 'under_maintenance'
  final double rent; // Base rent (fixed monthly)
  final String? tenantId;
  final String? tenantName;
  final String? description;
  final int bedrooms;
  final int bathrooms;
  final double? area; // in square feet/meters
  final List<String> amenities;
  
  // Payment Structure (NEW)
  final double baseRent; // Fixed monthly rent
  final Map<String, double> fixedBills; // Bills that don't change (e.g., dustbin)
  final Map<String, double>? currentMonthBills; // Variable bills (water, electricity)
  final String? currentBillsMonth; // Which month these bills are for
  final double depositAmount; // Security deposit amount
  
  // Payment Tracking (NEW)
  final double? totalRequired; // Total for current month
  final double? totalPaid; // Total paid for current month
  final double? remainingAmount; // Remaining for current month
  final String? paymentStatus; // 'not_paid', 'partial_rent', 'rent_only', 'partial_bills', 'complete', 'overpaid'
  final double creditBalance; // Overpayment from previous months
  final DateTime? lastPaymentDate;
  final double? lastPaymentAmount;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  Unit({
    required this.id,
    required this.unitNumber,
    required this.unitName,
    required this.type,
    required this.status,
    required this.rent,
    this.tenantId,
    this.tenantName,
    this.description,
    required this.bedrooms,
    required this.bathrooms,
    this.area,
    required this.amenities,
    required this.baseRent,
    Map<String, double>? fixedBills,
    this.currentMonthBills,
    this.currentBillsMonth,
    required this.depositAmount,
    this.totalRequired,
    this.totalPaid,
    this.remainingAmount,
    this.paymentStatus,
    double? creditBalance,
    this.lastPaymentDate,
    this.lastPaymentAmount,
    required this.createdAt,
    required this.updatedAt,
  }) : fixedBills = fixedBills ?? {},
       creditBalance = creditBalance ?? 0.0;

  factory Unit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle missing timestamps gracefully
    DateTime now = DateTime.now();
    DateTime createdAt = now;
    DateTime updatedAt = now;
    
    try {
      if (data['createdAt'] != null) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      }
    } catch (e) {
      createdAt = now;
    }
    
    try {
      if (data['updatedAt'] != null) {
        updatedAt = (data['updatedAt'] as Timestamp).toDate();
      }
    } catch (e) {
      updatedAt = now;
    }
    
    // Parse fixed bills
    Map<String, double> fixedBills = {};
    if (data['fixedBills'] != null) {
      (data['fixedBills'] as Map<String, dynamic>).forEach((key, value) {
        fixedBills[key] = (value as num).toDouble();
      });
    }
    
    // Parse current month bills
    Map<String, double>? currentMonthBills;
    if (data['currentMonthBills'] != null) {
      currentMonthBills = {};
      (data['currentMonthBills'] as Map<String, dynamic>).forEach((key, value) {
        currentMonthBills![key] = (value as num).toDouble();
      });
    }
    
    // Parse last payment date
    DateTime? lastPaymentDate;
    if (data['lastPaymentDate'] != null) {
      try {
        lastPaymentDate = (data['lastPaymentDate'] as Timestamp).toDate();
      } catch (e) {
        lastPaymentDate = null;
      }
    }
    
    return Unit(
      id: doc.id,
      unitNumber: data['unitNumber'] ?? '',
      unitName: data['unitName'] ?? '',
      type: data['type'] ?? '',
      status: data['status'] ?? 'vacant',
      rent: (data['rent'] ?? data['baseRent'] ?? 0).toDouble(), // Backward compatibility
      tenantId: data['tenantId'],
      tenantName: data['tenantName'],
      description: data['description'],
      bedrooms: data['bedrooms'] ?? 1,
      bathrooms: data['bathrooms'] ?? 1,
      area: data['area']?.toDouble(),
      amenities: List<String>.from(data['amenities'] ?? []),
      baseRent: (data['baseRent'] ?? data['rent'] ?? 0).toDouble(),
      fixedBills: fixedBills,
      currentMonthBills: currentMonthBills,
      currentBillsMonth: data['currentBillsMonth'],
      depositAmount: (data['depositAmount'] ?? 0).toDouble(),
      totalRequired: data['totalRequired']?.toDouble(),
      totalPaid: data['totalPaid']?.toDouble(),
      remainingAmount: data['remainingAmount']?.toDouble(),
      paymentStatus: data['paymentStatus'],
      creditBalance: (data['creditBalance'] ?? 0).toDouble(),
      lastPaymentDate: lastPaymentDate,
      lastPaymentAmount: data['lastPaymentAmount']?.toDouble(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'unitNumber': unitNumber,
      'unitName': unitName,
      'type': type,
      'status': status,
      'rent': rent,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'description': description,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'area': area,
      'amenities': amenities,
      'baseRent': baseRent,
      'fixedBills': fixedBills,
      'currentMonthBills': currentMonthBills,
      'currentBillsMonth': currentBillsMonth,
      'depositAmount': depositAmount,
      'totalRequired': totalRequired,
      'totalPaid': totalPaid,
      'remainingAmount': remainingAmount,
      'paymentStatus': paymentStatus,
      'creditBalance': creditBalance,
      'lastPaymentDate': lastPaymentDate != null ? Timestamp.fromDate(lastPaymentDate!) : null,
      'lastPaymentAmount': lastPaymentAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Unit copyWith({
    String? unitNumber,
    String? unitName,
    String? type,
    String? status,
    double? rent,
    String? tenantId,
    String? tenantName,
    String? description,
    int? bedrooms,
    int? bathrooms,
    double? area,
    List<String>? amenities,
    double? baseRent,
    Map<String, double>? fixedBills,
    Map<String, double>? currentMonthBills,
    String? currentBillsMonth,
    double? depositAmount,
    double? totalRequired,
    double? totalPaid,
    double? remainingAmount,
    String? paymentStatus,
    double? creditBalance,
    DateTime? lastPaymentDate,
    double? lastPaymentAmount,
  }) {
    return Unit(
      id: id,
      unitNumber: unitNumber ?? this.unitNumber,
      unitName: unitName ?? this.unitName,
      type: type ?? this.type,
      status: status ?? this.status,
      rent: rent ?? this.rent,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      description: description ?? this.description,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      area: area ?? this.area,
      amenities: amenities ?? this.amenities,
      baseRent: baseRent ?? this.baseRent,
      fixedBills: fixedBills ?? this.fixedBills,
      currentMonthBills: currentMonthBills ?? this.currentMonthBills,
      currentBillsMonth: currentBillsMonth ?? this.currentBillsMonth,
      depositAmount: depositAmount ?? this.depositAmount,
      totalRequired: totalRequired ?? this.totalRequired,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      creditBalance: creditBalance ?? this.creditBalance,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      lastPaymentAmount: lastPaymentAmount ?? this.lastPaymentAmount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class DamageReport {
  final String id;
  final String damageId;
  final String description;
  final String unitNumber;
  final String unitName;
  final String reportedBy;
  final DateTime dateReported;
  final String status; // 'pending', 'in_progress', 'repaired'
  final String priority; // 'low', 'medium', 'high'
  final String? repairNotes;
  final DateTime? repairDate;
  final double? repairCost;
  final List<String> images;
  final DateTime createdAt;
  final DateTime updatedAt;

  DamageReport({
    required this.id,
    required this.damageId,
    required this.description,
    required this.unitNumber,
    required this.unitName,
    required this.reportedBy,
    required this.dateReported,
    required this.status,
    required this.priority,
    this.repairNotes,
    this.repairDate,
    this.repairCost,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DamageReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DamageReport(
      id: doc.id,
      damageId: data['damageId'] ?? '',
      description: data['description'] ?? '',
      unitNumber: data['unitNumber'] ?? '',
      unitName: data['unitName'] ?? '',
      reportedBy: data['reportedBy'] ?? '',
      dateReported: (data['dateReported'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      priority: data['priority'] ?? 'medium',
      repairNotes: data['repairNotes'],
      repairDate: data['repairDate'] != null 
          ? (data['repairDate'] as Timestamp).toDate() 
          : null,
      repairCost: data['repairCost']?.toDouble(),
      images: List<String>.from(data['images'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'damageId': damageId,
      'description': description,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'reportedBy': reportedBy,
      'dateReported': Timestamp.fromDate(dateReported),
      'status': status,
      'priority': priority,
      'repairNotes': repairNotes,
      'repairDate': repairDate != null ? Timestamp.fromDate(repairDate!) : null,
      'repairCost': repairCost,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DamageReport copyWith({
    String? damageId,
    String? description,
    String? unitNumber,
    String? unitName,
    String? reportedBy,
    DateTime? dateReported,
    String? status,
    String? priority,
    String? repairNotes,
    DateTime? repairDate,
    double? repairCost,
    List<String>? images,
  }) {
    return DamageReport(
      id: id,
      damageId: damageId ?? this.damageId,
      description: description ?? this.description,
      unitNumber: unitNumber ?? this.unitNumber,
      unitName: unitName ?? this.unitName,
      reportedBy: reportedBy ?? this.reportedBy,
      dateReported: dateReported ?? this.dateReported,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      repairNotes: repairNotes ?? this.repairNotes,
      repairDate: repairDate ?? this.repairDate,
      repairCost: repairCost ?? this.repairCost,
      images: images ?? this.images,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}