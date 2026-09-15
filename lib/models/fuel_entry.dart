class FuelEntry {
  final int? id;
  final DateTime date;
  final double odometerReading;
  final double liters;
  final double pricePerLiter;
  final double totalCost;
  final String? note;
  final DateTime createdAt;

  FuelEntry({
    this.id,
    required this.date,
    required this.odometerReading,
    required this.liters,
    required this.pricePerLiter,
    required this.totalCost,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'odometer_reading': odometerReading,
      'liters': liters,
      'price_per_liter': pricePerLiter,
      'total_cost': totalCost,
      'full_tank': 1,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FuelEntry.fromMap(Map<String, dynamic> map) {
    return FuelEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      odometerReading: (map['odometer_reading'] as num).toDouble(),
      liters: (map['liters'] as num).toDouble(),
      pricePerLiter: (map['price_per_liter'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
