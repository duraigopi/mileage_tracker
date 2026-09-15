class OdometerEntry {
  final int? id;
  final DateTime date;
  final double reading;
  final String? note;
  final DateTime createdAt;

  OdometerEntry({
    this.id,
    required this.date,
    required this.reading,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'reading': reading,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OdometerEntry.fromMap(Map<String, dynamic> map) {
    return OdometerEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      reading: (map['reading'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  OdometerEntry copyWith({
    int? id,
    DateTime? date,
    double? reading,
    String? note,
    DateTime? createdAt,
  }) {
    return OdometerEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      reading: reading ?? this.reading,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
