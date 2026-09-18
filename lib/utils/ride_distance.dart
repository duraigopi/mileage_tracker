import '../models/odometer_entry.dart';

/// Chronological order, with a stable tiebreak on id so entries sharing a
/// timestamp still have a definite predecessor.
bool _isBefore(OdometerEntry a, OdometerEntry b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate < 0;
  return (a.id ?? 0) < (b.id ?? 0);
}

/// Distance covered to reach [entry] — the gap from the reading immediately
/// before it in time. Returns 0 for the earliest entry, or when the reading
/// did not advance.
///
/// Ordering is chronological, never by reading: carrying a day's closing
/// reading over as the next day's opening entry gives two entries the same
/// value, and ordering those by reading would hand the distance to whichever
/// happened to sort first rather than to the entry that actually earned it.
double distanceFromPrevious(List<OdometerEntry> entries, OdometerEntry entry) {
  OdometerEntry? previous;
  for (final candidate in entries) {
    if (identical(candidate, entry)) continue;
    if (candidate.id != null && candidate.id == entry.id) continue;
    if (!_isBefore(candidate, entry)) continue;
    if (previous == null || _isBefore(previous, candidate)) {
      previous = candidate;
    }
  }
  if (previous == null) return 0;
  final distance = entry.reading - previous.reading;
  return distance > 0 ? distance : 0;
}

/// The lowest-reading entry dated after [dateTime], or null if there is none.
///
/// A new reading above it would leave that later entry below an earlier one,
/// which an odometer cannot do. It is usually an advance entry whose value was
/// an estimate, so callers should flag this rather than refuse the save.
OdometerEntry? lowestEntryAfterIn(
  List<OdometerEntry> entries,
  DateTime dateTime,
) {
  OdometerEntry? lowest;
  for (final candidate in entries) {
    if (!candidate.date.isAfter(dateTime)) continue;
    if (lowest == null || candidate.reading < lowest.reading) {
      lowest = candidate;
    }
  }
  return lowest;
}
