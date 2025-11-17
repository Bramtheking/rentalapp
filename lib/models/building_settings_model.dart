class BuildingSettings {
  final int dueDate; // Day of month (1-28)
  final PenaltySettings penalties;

  BuildingSettings({
    required this.dueDate,
    required this.penalties,
  });

  factory BuildingSettings.fromMap(Map<String, dynamic> data) {
    return BuildingSettings(
      dueDate: data['dueDate'] ?? 5,
      penalties: PenaltySettings.fromMap(data['penalties'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dueDate': dueDate,
      'penalties': penalties.toMap(),
    };
  }

  factory BuildingSettings.defaultSettings() {
    return BuildingSettings(
      dueDate: 5,
      penalties: PenaltySettings.defaultPenalties(),
    );
  }
}

class PenaltySettings {
  final LateRentPenalty lateRent;
  final PartialPaymentPenalty partialPayment;

  PenaltySettings({
    required this.lateRent,
    required this.partialPayment,
  });

  factory PenaltySettings.fromMap(Map<String, dynamic> data) {
    return PenaltySettings(
      lateRent: LateRentPenalty.fromMap(data['lateRent'] ?? {}),
      partialPayment: PartialPaymentPenalty.fromMap(data['partialPayment'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lateRent': lateRent.toMap(),
      'partialPayment': partialPayment.toMap(),
    };
  }

  factory PenaltySettings.defaultPenalties() {
    return PenaltySettings(
      lateRent: LateRentPenalty(fixed: 200, perDay: 50),
      partialPayment: PartialPaymentPenalty(perDay: 50),
    );
  }
}

class LateRentPenalty {
  final double fixed; // Fixed penalty amount
  final double perDay; // Per day penalty

  LateRentPenalty({
    required this.fixed,
    required this.perDay,
  });

  factory LateRentPenalty.fromMap(Map<String, dynamic> data) {
    return LateRentPenalty(
      fixed: (data['fixed'] ?? 200).toDouble(),
      perDay: (data['perDay'] ?? 50).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fixed': fixed,
      'perDay': perDay,
    };
  }

  double calculate(int daysLate) {
    return fixed + (perDay * daysLate);
  }
}

class PartialPaymentPenalty {
  final double perDay; // Per day penalty (no fixed amount)

  PartialPaymentPenalty({
    required this.perDay,
  });

  factory PartialPaymentPenalty.fromMap(Map<String, dynamic> data) {
    return PartialPaymentPenalty(
      perDay: (data['perDay'] ?? 50).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'perDay': perDay,
    };
  }

  double calculate(int daysLate) {
    return perDay * daysLate;
  }
}
