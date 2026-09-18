import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_app/models/odometer_entry.dart';
import 'package:mileage_app/utils/ride_distance.dart';

OdometerEntry entry(int id, DateTime date, double reading) =>
    OdometerEntry(id: id, date: date, reading: reading);

void main() {
  final yesterday = DateTime(2026, 9, 17);
  final today = DateTime(2026, 9, 18);

  group('carrying a closing reading into the next day', () {
    // start / middle / end yesterday, then today opens on yesterday's close
    final yStart = entry(1, yesterday.add(const Duration(hours: 8)), 100);
    final yMiddle = entry(2, yesterday.add(const Duration(hours: 13)), 120);
    final yEnd = entry(3, yesterday.add(const Duration(hours: 19)), 150);
    final tStart = entry(4, today.add(const Duration(hours: 8)), 150);
    final entries = [yStart, yMiddle, yEnd, tStart];

    test('the 30 km belongs to yesterday\'s ending entry', () {
      expect(distanceFromPrevious(entries, yEnd), 30);
    });

    test("today's opening entry shows nothing", () {
      expect(distanceFromPrevious(entries, tStart), 0);
    });

    test('the earlier entries are unaffected', () {
      expect(distanceFromPrevious(entries, yStart), 0);
      expect(distanceFromPrevious(entries, yMiddle), 20);
    });

    test('list order does not change the result', () {
      final shuffled = [tStart, yEnd, yStart, yMiddle];
      expect(distanceFromPrevious(shuffled, yEnd), 30);
      expect(distanceFromPrevious(shuffled, tStart), 0);
    });
  });

  group('general behaviour', () {
    test('the very first entry has no predecessor', () {
      final only = entry(1, today, 100);
      expect(distanceFromPrevious([only], only), 0);
    });

    test('seconds break ties within the same minute', () {
      final a = entry(1, DateTime(2026, 9, 18, 8, 30, 10), 100);
      final b = entry(2, DateTime(2026, 9, 18, 8, 30, 50), 112);
      expect(distanceFromPrevious([a, b], b), 12);
      expect(distanceFromPrevious([a, b], a), 0);
    });

    test('identical timestamps fall back to id order', () {
      final at = DateTime(2026, 9, 18, 8, 30);
      final a = entry(1, at, 100);
      final b = entry(2, at, 105);
      expect(distanceFromPrevious([a, b], b), 5);
      expect(distanceFromPrevious([a, b], a), 0);
    });

    test('a reading that did not advance yields 0, never a negative', () {
      final a = entry(1, today.add(const Duration(hours: 8)), 150);
      final b = entry(2, today.add(const Duration(hours: 9)), 140);
      expect(distanceFromPrevious([a, b], b), 0);
    });

    test('an advance entry for tomorrow does not steal today\'s distance', () {
      final t = entry(1, today.add(const Duration(hours: 8)), 150);
      final tomorrow = entry(2, today.add(const Duration(days: 1, hours: 8)), 190);
      final earlier = entry(3, yesterday.add(const Duration(hours: 19)), 120);
      final entries = [earlier, t, tomorrow];
      expect(distanceFromPrevious(entries, t), 30);
      expect(distanceFromPrevious(entries, tomorrow), 40);
    });
  });


  group('lowestEntryAfterIn (advance-entry conflict check)', () {
    final now = DateTime(2026, 9, 18, 9);
    final advance = entry(9, DateTime(2026, 9, 19, 8), 4260);

    test('finds an advance entry dated after the new one', () {
      final past = entry(1, DateTime(2026, 9, 18, 8), 4200);
      final found = lowestEntryAfterIn([past, advance], now);
      expect(found?.id, 9);
    });

    test('ignores entries at or before the given time', () {
      final past = entry(1, DateTime(2026, 9, 18, 8), 4200);
      expect(lowestEntryAfterIn([past], now), isNull);
      expect(lowestEntryAfterIn([], now), isNull);
    });

    test('returns the lowest reading, not merely the earliest', () {
      final low = entry(2, DateTime(2026, 9, 21, 8), 4255);
      final high = entry(3, DateTime(2026, 9, 19, 8), 4300);
      final found = lowestEntryAfterIn([high, low], now);
      expect(found?.reading, 4255);
    });

    test('a reading at or below it raises no conflict', () {
      final found = lowestEntryAfterIn([advance], now);
      expect(found, isNotNull);
      // 4250 stays under the advance entry, 4270 overtakes it
      expect(4250 > found!.reading, isFalse);
      expect(4270 > found.reading, isTrue);
    });
  });
}
