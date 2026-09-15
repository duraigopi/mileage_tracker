import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_app/models/odometer_entry.dart';
import 'package:mileage_app/utils/note_suggestion.dart';

OdometerEntry entry(DateTime date, double reading, [String? note]) =>
    OdometerEntry(date: date, reading: reading, note: note);

void main() {
  // 2026-09-11 is a Friday, 2026-09-14 the following Monday.
  final friday = DateTime(2026, 9, 11);
  final monday = DateTime(2026, 9, 14);

  group('first entry of the day', () {
    test('picks up Friday note when adding on Monday', () {
      final entries = [
        entry(friday.add(const Duration(hours: 8, minutes: 30)), 4100, 'Office'),
        entry(friday.add(const Duration(hours: 19)), 4135, 'Home'),
      ];
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 8, minutes: 40)),
      );
      expect(note, 'Office');
    });

    test('still works when the gap is weeks, not a weekend', () {
      final entries = [
        entry(DateTime(2026, 8, 20, 9), 3900, 'Office'),
      ];
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 9)),
      );
      expect(note, 'Office');
    });

    test('uses the most recent day, not the oldest', () {
      final entries = [
        entry(DateTime(2026, 9, 1, 9), 3800, 'Old route'),
        entry(friday.add(const Duration(hours: 8)), 4100, 'Office'),
      ];
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 8)),
      );
      expect(note, 'Office');
    });

    test('uses that day first ride, not its last', () {
      final entries = [
        entry(friday.add(const Duration(hours: 8)), 4100, 'Office'),
        entry(friday.add(const Duration(hours: 19)), 4135, 'Home'),
      ];
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 8)),
      );
      expect(note, 'Office');
    });

    test('yesterday still works', () {
      final entries = [
        entry(monday.subtract(const Duration(hours: 4)), 4100, 'Sunday ride'),
      ];
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 8)),
      );
      expect(note, 'Sunday ride');
    });

    test('returns null when there is no history at all', () {
      expect(suggestedOdometerNote(entries: [], now: monday), isNull);
    });

    test('returns null when the previous note is blank', () {
      final entries = [
        entry(friday.add(const Duration(hours: 8)), 4100),
        entry(friday.add(const Duration(hours: 19)), 4135, '   '),
      ];
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 8)),
      );
      expect(note, isNull);
    });
  });

  group('later entries the same day', () {
    final entries = [
      entry(monday.add(const Duration(hours: 8)), 4200, 'Office'),
      entry(friday.add(const Duration(hours: 8)), 4100, 'Friday note'),
    ];

    test('no suggestion during the day', () {
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 13)),
      );
      expect(note, isNull);
    });

    test('offers the morning note on the ride back after 8 PM', () {
      final note = suggestedOdometerNote(
        entries: entries,
        now: monday.add(const Duration(hours: 21)),
      );
      expect(note, 'Office');
    });

    test('an advance entry for tomorrow is not treated as today', () {
      final withAdvance = [
        entry(friday.add(const Duration(hours: 8)), 4100, 'Office'),
        entry(monday.add(const Duration(days: 1, hours: 8)), 4300, 'Tomorrow'),
      ];
      final note = suggestedOdometerNote(
        entries: withAdvance,
        now: monday.add(const Duration(hours: 8)),
      );
      expect(note, 'Office');
    });
  });
}
