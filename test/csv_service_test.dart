import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_app/models/fuel_entry.dart';
import 'package:mileage_app/models/maintenance_entry.dart';
import 'package:mileage_app/models/odometer_entry.dart';
import 'package:mileage_app/services/csv_service.dart';

void main() {
  group('splitCsvLine', () {
    test('splits plain fields', () {
      expect(splitCsvLine('a,b,c'), ['a', 'b', 'c']);
    });

    test('keeps commas inside quoted fields', () {
      expect(splitCsvLine('a,"b,c",d'), ['a', 'b,c', 'd']);
    });

    test('unescapes doubled quotes', () {
      expect(splitCsvLine('a,"say ""hi""",b'), ['a', 'say "hi"', 'b']);
    });

    test('preserves empty trailing field', () {
      expect(splitCsvLine('a,b,'), ['a', 'b', '']);
    });
  });

  group('round trip', () {
    final odometer = [
      OdometerEntry(date: DateTime(2026, 9, 14, 8, 30, 27), reading: 4206.0, note: 'Office, morning'),
      OdometerEntry(date: DateTime(2026, 9, 14, 19, 5, 3), reading: 4241.5),
    ];
    final fuel = [
      FuelEntry(
        date: DateTime(2026, 9, 13, 18, 45, 59),
        odometerReading: 4180.0,
        liters: 4.96,
        pricePerLiter: 100.8,
        totalCost: 500.0,
        note: 'Shell "highway" pump',
      ),
    ];
    final maintenance = [
      MaintenanceEntry(
        date: DateTime(2026, 9, 1, 10, 0),
        category: MaintenanceCategory.general,
        cost: 1250.0,
        odometerReading: 4000.0,
        note: 'Oil change',
      ),
      MaintenanceEntry(
        date: DateTime(2026, 9, 5, 16, 20),
        category: MaintenanceCategory.washing,
        cost: 80.0,
      ),
    ];

    late CsvImportData parsed;

    setUp(() {
      final csv = buildCsv(
        odometer: odometer,
        fuel: fuel,
        maintenance: maintenance,
        summary: {'Total Distance': '241.5 km'},
      );
      parsed = parseCsv(csv);
    });

    test('parses without errors', () {
      expect(parsed.errors, isEmpty);
      expect(parsed.total, 5);
    });

    test('restores odometer entries with date, time and note', () {
      expect(parsed.odometer.length, 2);
      final first = parsed.odometer.first;
      expect(first.date, DateTime(2026, 9, 14, 8, 30, 27));
      expect(first.reading, 4206.0);
      expect(first.note, 'Office, morning');
      expect(parsed.odometer[1].note, isNull);
    });

    test('restores fuel entries including quoted notes', () {
      final e = parsed.fuel.single;
      expect(e.date, DateTime(2026, 9, 13, 18, 45, 59));
      expect(e.odometerReading, 4180.0);
      expect(e.liters, closeTo(4.96, 0.001));
      expect(e.pricePerLiter, 100.8);
      expect(e.totalCost, 500.0);
      expect(e.note, 'Shell "highway" pump');
    });

    test('restores maintenance including a null odometer', () {
      expect(parsed.maintenance.length, 2);
      final service = parsed.maintenance.firstWhere((e) => e.category == MaintenanceCategory.general);
      expect(service.cost, 1250.0);
      expect(service.odometerReading, 4000.0);
      final wash = parsed.maintenance.firstWhere((e) => e.category == MaintenanceCategory.washing);
      expect(wash.odometerReading, isNull);
      expect(wash.note, isNull);
    });

    test('summary rows are not mistaken for entries', () {
      expect(parsed.total, 5);
    });
  });

  group('tolerance', () {
    test('reads an older HH:mm file with no seconds and no fuel Time column', () {
      const legacy = '''
=== ODOMETER READINGS ===
Date,Time,Reading (km),Note
14-09-2026,08:30,4206.0,Morning

=== FUEL ENTRIES ===
Date,Odometer (km),Liters,Rate,Amount,Note
13-09-2026,4180.0,4.96,100.8,500.0,Fill up

=== MAINTENANCE ===
Date,Category,Cost,Odometer (km),Note
01-09-2026,Washing,80.0,,
''';
      final parsed = parseCsv(legacy);
      expect(parsed.errors, isEmpty);
      expect(parsed.odometer.single.date, DateTime(2026, 9, 14, 8, 30));
      expect(parsed.fuel.single.date, DateTime(2026, 9, 13));
      expect(parsed.fuel.single.totalCost, 500.0);
      expect(parsed.maintenance.single.odometerReading, isNull);
    });

    test('collects bad rows instead of failing the whole import', () {
      const broken = '''
=== ODOMETER READINGS ===
Date,Time,Reading (km),Note
14-09-2026,08:30,4206.0,Good
not-a-date,08:30,4207.0,Bad date
15-09-2026,09:00,abc,Bad reading
15-09-2026,10:00,4300.0,Also good
''';
      final parsed = parseCsv(broken);
      expect(parsed.odometer.length, 2);
      expect(parsed.errors.length, 2);
    });

    test('empty content yields nothing', () {
      expect(parseCsv('').isEmpty, isTrue);
      expect(parseCsv('random text\nmore text').isEmpty, isTrue);
    });
  });

  group('seconds', () {
    test('second-level precision survives a round trip', () {
      final entries = [
        OdometerEntry(date: DateTime(2026, 9, 14, 8, 30, 1), reading: 100.0),
        OdometerEntry(date: DateTime(2026, 9, 14, 8, 30, 59), reading: 101.0),
      ];
      final parsed = parseCsv(buildCsv(odometer: entries, fuel: [], maintenance: []));
      expect(parsed.errors, isEmpty);
      expect(parsed.odometer.map((e) => e.date.second), [1, 59]);
    });

    test('two entries in the same minute stay distinct and ordered', () {
      final entries = [
        OdometerEntry(date: DateTime(2026, 9, 14, 8, 30, 45), reading: 101.0),
        OdometerEntry(date: DateTime(2026, 9, 14, 8, 30, 12), reading: 100.0),
      ];
      final parsed = parseCsv(buildCsv(odometer: entries, fuel: [], maintenance: []));
      expect(parsed.odometer.length, 2);
      // buildCsv sorts chronologically, so seconds drive the order
      expect(parsed.odometer.map((e) => e.reading), [100.0, 101.0]);
    });

    test('a time written without seconds still reads back', () {
      const legacy = '''
=== ODOMETER READINGS ===
Date,Time,Reading (km),Note
14-09-2026,08:30,4206.0,No seconds
''';
      final parsed = parseCsv(legacy);
      expect(parsed.errors, isEmpty);
      expect(parsed.odometer.single.date, DateTime(2026, 9, 14, 8, 30, 0));
    });
  });
}
