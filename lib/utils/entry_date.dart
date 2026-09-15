import 'package:flutter/material.dart';

/// Entries may be dated up to this many days ahead of today, so a reading can
/// be recorded in advance (e.g. logging tomorrow's start reading tonight).
const int kAdvanceEntryDays = 1;

/// Earliest date any entry can be dated.
final DateTime kFirstEntryDate = DateTime(2020);

/// Today with the time component stripped.
DateTime todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Latest date an entry can be dated — tomorrow, for advance entries.
DateTime latestEntryDate() =>
    todayStart().add(const Duration(days: kAdvanceEntryDays));

/// Exclusive upper bound for "today" — anything at or after this belongs to an
/// advance entry and must not be counted in today's totals.
DateTime tomorrowStart() => todayStart().add(const Duration(days: 1));

/// True when [date] falls after today, i.e. the entry is recorded in advance.
bool isAdvanceEntryDate(DateTime date) =>
    DateUtils.dateOnly(date).isAfter(todayStart());

/// Keeps [date] inside the range the date picker accepts.
DateTime _clampEntryDate(DateTime date) {
  final last = latestEntryDate();
  if (DateUtils.dateOnly(date).isAfter(last)) return last;
  if (date.isBefore(kFirstEntryDate)) return kFirstEntryDate;
  return date;
}

/// Builds the timestamp an entry is stored with.
///
/// The time picker only offers hours and minutes, so [second] carries the
/// precision it cannot: the clock reading at save time for a new entry, or the
/// original value when an existing entry's time was left untouched. It is 0
/// when the user picked a time by hand — they chose a whole minute.
DateTime composeEntryDateTime({
  required DateTime date,
  required TimeOfDay time,
  int second = 0,
}) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute, second);

/// Date picker shared by the add/edit sheets. Tomorrow is selectable so
/// readings can be recorded in advance.
Future<DateTime?> showEntryDatePicker(
  BuildContext context,
  DateTime initialDate,
) {
  return showDatePicker(
    context: context,
    initialDate: _clampEntryDate(initialDate),
    firstDate: kFirstEntryDate,
    lastDate: latestEntryDate(),
  );
}
