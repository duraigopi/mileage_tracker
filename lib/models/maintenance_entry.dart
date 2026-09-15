class MaintenanceCategory {
  static const String general = 'General Service';
  static const String airCheckup = 'Air Checkup';
  static const String washing = 'Washing';
  static const String other = 'Other';

  static const List<String> all = [
    general,
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

  MaintenanceEntry({
    this.id,
    required this.date,
    required this.category,
    required this.cost,
    this.odometerReading,
    this.note,
    DateTime? createdAt,
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
  }) {
    return MaintenanceEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      cost: cost ?? this.cost,
      odometerReading: odometerReading ?? this.odometerReading,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
