class MaintenanceCategory {
  static const String general = 'General Service';
  static const String oilChange = 'Oil Change';
  static const String airCheckup = 'Air Checkup';
  static const String washing = 'Washing';
  static const String other = 'Other';

  static const List<String> all = [
    general,
    oilChange,
    airCheckup,
    washing,
    other,
  ];
}

class MaintenanceEntry {
  final int? id;
  final DateTime date;
  final String category;
  final double cost;
  final double? odometerReading;
  final String? note;
  final DateTime createdAt;

  /// Optional reminder set on this entry: "remind me again after this many
  /// days / this many km." Either, both, or neither may be set.
  final int? reminderDays;
  final double? reminderKm;

  MaintenanceEntry({
    this.id,
    required this.date,
    required this.category,
    required this.cost,
    this.odometerReading,
    this.note,
    DateTime? createdAt,
    this.reminderDays,
    this.reminderKm,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'category': category,
      'cost': cost,
      'odometer_reading': odometerReading,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'reminder_days': reminderDays,
      'reminder_km': reminderKm,
    };
  }

  factory MaintenanceEntry.fromMap(Map<String, dynamic> map) {
    return MaintenanceEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      cost: (map['cost'] as num).toDouble(),
      odometerReading: map['odometer_reading'] != null
          ? (map['odometer_reading'] as num).toDouble()
          : null,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      reminderDays: map['reminder_days'] as int?,
      reminderKm: map['reminder_km'] != null ? (map['reminder_km'] as num).toDouble() : null,
    );
  }

  MaintenanceEntry copyWith({
    int? id,
    DateTime? date,
    String? category,
    double? cost,
    double? odometerReading,
    String? note,
    DateTime? createdAt,
    int? reminderDays,
    double? reminderKm,
  }) {
    return MaintenanceEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      cost: cost ?? this.cost,
      odometerReading: odometerReading ?? this.odometerReading,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderKm: reminderKm ?? this.reminderKm,
    );
  }
}
