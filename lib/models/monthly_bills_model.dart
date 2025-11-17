import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyBills {
  final String id;
  final String buildingId;
  final DateTime month; // First day of the month
  final Map<String, UnitBills> bills; // unitNumber -> bills
  final DateTime enteredDate;
  final String enteredBy;
  final DateTime createdAt;

  MonthlyBills({
    required this.id,
    required this.buildingId,
    required this.month,
    required this.bills,
    required this.enteredDate,
    required this.enteredBy,
    required this.createdAt,
  });

  factory MonthlyBills.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse bills
    Map<String, UnitBills> bills = {};
    if (data['bills'] != null) {
      (data['bills'] as Map<String, dynamic>).forEach((unitNumber, billData) {
        bills[unitNumber] = UnitBills.fromMap(billData as Map<String, dynamic>);
      });
    }
    
    return MonthlyBills(
      id: doc.id,
      buildingId: data['buildingId'] ?? '',
      month: (data['month'] as Timestamp).toDate(),
      bills: bills,
      enteredDate: (data['enteredDate'] as Timestamp).toDate(),
      enteredBy: data['enteredBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> billsMap = {};
    bills.forEach((unitNumber, unitBills) {
      billsMap[unitNumber] = unitBills.toMap();
    });
    
    return {
      'buildingId': buildingId,
      'month': Timestamp.fromDate(month),
      'bills': billsMap,
      'enteredDate': Timestamp.fromDate(enteredDate),
      'enteredBy': enteredBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class UnitBills {
  final double water;
  final double electricity;
  final Map<String, double>? otherBills; // For any additional bills

  UnitBills({
    required this.water,
    required this.electricity,
    this.otherBills,
  });

  factory UnitBills.fromMap(Map<String, dynamic> data) {
    Map<String, double>? otherBills;
    if (data['otherBills'] != null) {
      otherBills = {};
      (data['otherBills'] as Map<String, dynamic>).forEach((key, value) {
        otherBills![key] = (value as num).toDouble();
      });
    }
    
    return UnitBills(
      water: (data['water'] ?? 0).toDouble(),
      electricity: (data['electricity'] ?? 0).toDouble(),
      otherBills: otherBills,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'water': water,
      'electricity': electricity,
      'otherBills': otherBills,
    };
  }

  double get total {
    double otherTotal = 0.0;
    if (otherBills != null) {
      otherTotal = otherBills!.values.fold(0.0, (sum, val) => sum + val);
    }
    return water + electricity + otherTotal;
  }
}
