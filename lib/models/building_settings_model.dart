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
  final double perDayAmount; // Single per-day penalty for any late payment

  PenaltySettings({
    required this.perDayAmount,
  });

  factory PenaltySettings.fromMap(Map<String, dynamic> data) {
    return PenaltySettings(
      perDayAmount: (data['perDayAmount'] ?? 50).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'perDayAmount': perDayAmount,
    };
  }

  factory PenaltySettings.defaultPenalties() {
    return PenaltySettings(
      perDayAmount: 50,
    );
  }

  double calculate(int daysLate) {
    return perDayAmount * daysLate;
  }
}
