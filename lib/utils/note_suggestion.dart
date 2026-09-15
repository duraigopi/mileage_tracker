import '../models/odometer_entry.dart';

/// Hour from which a new entry is treated as the ride back, so the note from
/// the day's first ride is offered again.
const int kReturnRideHour = 20;

/// Note to pre-fill when adding an odometer entry at [now], or null for none.
///
/// Before the day's first entry this is the note from the first ride of the
/// most recent day that actually has entries — not merely yesterday — so a
/// Monday entry still picks up Friday's note across a weekend or any gap.
/// Once the day has entries, the note is only offered from [kReturnRideHour],
/// when the ride is assumed to be heading back to where the day started.
String? suggestedOdometerNote({
  required List<OdometerEntry> entries,
  required DateTime now,
}) {
  final dayStart = DateTime(now.year, now.month, now.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final today = entries
      .where((e) => !e.date.isBefore(dayStart) && e.date.isBefore(dayEnd))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  if (today.isNotEmpty) {
    return now.hour >= kReturnRideHour ? _clean(today.first.note) : null;
  }

  final previous = entries.where((e) => e.date.isBefore(dayStart)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (previous.isEmpty) return null;

  // Entries are ascending, so the last one marks the most recent day with data
  final mostRecent = previous.last.date;
  final mostRecentStart =
      DateTime(mostRecent.year, mostRecent.month, mostRecent.day);
  final firstRideThatDay =
      previous.firstWhere((e) => !e.date.isBefore(mostRecentStart));
  return _clean(firstRideThatDay.note);
}

String? _clean(String? note) {
  final text = note?.trim() ?? '';
  return text.isEmpty ? null : text;
}
