class SMSFormat {
  final String id;
  final String name;
  final String paybill;
  final String format;
  final Map<String, String> extractors;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SMSFormat({
    required this.id,
    required this.name,
    required this.paybill,
    required this.format,
    required this.extractors,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SMSFormat.fromMap(Map<String, dynamic> map, String id) {
    return SMSFormat(
      id: id,
      name: map['name'] ?? '',
      paybill: map['paybill'] ?? '',
      format: map['format'] ?? '',
      extractors: Map<String, String>.from(map['extractors'] ?? {}),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'paybill': paybill,
      'format': format,
      'extractors': extractors,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  SMSFormat copyWith({
    String? id,
    String? name,
    String? paybill,
    String? format,
    Map<String, String>? extractors,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SMSFormat(
      id: id ?? this.id,
      name: name ?? this.name,
      paybill: paybill ?? this.paybill,
      format: format ?? this.format,
      extractors: extractors ?? this.extractors,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SMSTransaction {
  final String id;
  final String buildingId;
  final double amount;
  final String reference;
  final String building;
  final String unit;
  final DateTime date;
  final String status; // matched, pending, partial
  final Map<String, double> paymentBreakdown;
  final String rawSMS;
  final String bankId;

  SMSTransaction({
    required this.id,
    required this.buildingId,
    required this.amount,
    required this.reference,
    required this.building,
    required this.unit,
    required this.date,
    required this.status,
    required this.paymentBreakdown,
    required this.rawSMS,
    required this.bankId,
  });

  factory SMSTransaction.fromMap(Map<String, dynamic> map, String id) {
    return SMSTransaction(
      id: id,
      buildingId: map['buildingId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      reference: map['reference'] ?? '',
      building: map['building'] ?? '',
      unit: map['unit'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'pending',
      paymentBreakdown: Map<String, double>.from(map['paymentBreakdown'] ?? {}),
      rawSMS: map['rawSMS'] ?? '',
      bankId: map['bankId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buildingId': buildingId,
      'amount': amount,
      'reference': reference,
      'building': building,
      'unit': unit,
      'date': date.toIso8601String(),
      'status': status,
      'paymentBreakdown': paymentBreakdown,
      'rawSMS': rawSMS,
      'bankId': bankId,
    };
  }
}

class PaymentStructure {
  final String unitRef;
  final double totalRent;
  final Map<String, double> breakdown;
  final int dueDate;
  final Map<String, double> penalties;

  PaymentStructure({
    required this.unitRef,
    required this.totalRent,
    required this.breakdown,
    required this.dueDate,
    required this.penalties,
  });

  factory PaymentStructure.fromMap(Map<String, dynamic> map, String unitRef) {
    return PaymentStructure(
      unitRef: unitRef,
      totalRent: (map['totalRent'] ?? 0).toDouble(),
      breakdown: Map<String, double>.from(map['breakdown'] ?? {}),
      dueDate: map['dueDate'] ?? 5,
      penalties: Map<String, double>.from(map['penalties'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalRent': totalRent,
      'breakdown': breakdown,
      'dueDate': dueDate,
      'penalties': penalties,
    };
  }
}