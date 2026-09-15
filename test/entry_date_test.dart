import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_app/utils/entry_date.dart';

void main() {
  group('entry date bounds', () {
    test('latest selectable date is tomorrow', () {
      expect(latestEntryDate(), todayStart().add(const Duration(days: 1)));
    });

    test('today and earlier are not advance entries', () {
      expect(isAdvanceEntryDate(DateTime.now()), isFalse);
      expect(isAdvanceEntryDate(todayStart()), isFalse);
      expect(isAdvanceEntryDate(todayStart().add(const Duration(hours: 23))), isFalse);
      expect(isAdvanceEntryDate(todayStart().subtract(const Duration(days: 1))), isFalse);
    });

    test('tomorrow is an advance entry', () {
      expect(isAdvanceEntryDate(latestEntryDate()), isTrue);
      expect(isAdvanceEntryDate(latestEntryDate().add(const Duration(hours: 9))), isTrue);
    });

    test('tomorrowStart is the exclusive end of today', () {
      expect(tomorrowStart().isAfter(todayStart()), isTrue);
      expect(tomorrowStart().difference(todayStart()), const Duration(days: 1));
    });
  });
}
