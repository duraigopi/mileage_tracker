import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/odometer_entry.dart';
import '../models/fuel_entry.dart';
import '../models/maintenance_entry.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../utils/entry_date.dart';

/// Outcome of a CSV import, for the confirmation snackbar.
class ImportResult {
  final int added;
  final int skipped;
  final List<String> errors;

  const ImportResult({
    required this.added,
    this.skipped = 0,
    this.errors = const [],
  });
}

class BikeProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<OdometerEntry> _odometerEntries = [];
  List<FuelEntry> _fuelEntries = [];
  List<MaintenanceEntry> _maintenanceEntries = [];
  bool _isLoading = true;
  bool _hasExported = false;

  List<OdometerEntry> get odometerEntries => _odometerEntries;
  List<FuelEntry> get fuelEntries => _fuelEntries;
  List<MaintenanceEntry> get maintenanceEntries => _maintenanceEntries;
  bool get isLoading => _isLoading;

  List<String> get odometerNoteSuggestions {
    final notes = _odometerEntries
        .where((e) => e.note != null && e.note!.isNotEmpty)
        .map((e) => e.note!)
        .toList();
    // Deduplicate, most recent first
    final seen = <String>{};
    return notes.where((n) => seen.add(n)).toList();
  }

  List<String> get fuelNoteSuggestions {
    final notes = _fuelEntries
        .where((e) => e.note != null && e.note!.isNotEmpty)
        .map((e) => e.note!)
        .toList();
    final seen = <String>{};
    return notes.where((n) => seen.add(n)).toList();
  }

  List<String> get maintenanceNoteSuggestions {
    final notes = _maintenanceEntries
        .where((e) => e.note != null && e.note!.isNotEmpty)
        .map((e) => e.note!)
        .toList();
    final seen = <String>{};
    return notes.where((n) => seen.add(n)).toList();
  }

  double get totalMaintenanceCost {
    return _maintenanceEntries.fold<double>(0, (s, e) => s + e.cost);
  }

  Map<String, double> get maintenanceCostByCategory {
    final map = <String, double>{};
    for (final entry in _maintenanceEntries) {
      map[entry.category] = (map[entry.category] ?? 0) + entry.cost;
    }
    return map;
  }

  /// Returns the last used petrol rate, or Chennai's default rate
  double get lastPetrolRate {
    if (_fuelEntries.isNotEmpty) {
      return _fuelEntries.first.pricePerLiter;
    }
    return 100.80; // Chennai petrol rate default
  }

  // --- Computed Properties ---

  double get currentOdometer {
    if (_odometerEntries.isEmpty) return 0;
    return _odometerEntries
        .map((e) => e.reading)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Highest reading recorded at or before [dateTime].
  ///
  /// Used as the baseline when adding an entry, so an advance (future-dated)
  /// entry does not become the reference point for an earlier day's entry.
  double odometerAsOf(DateTime dateTime) {
    final readings = _odometerEntries
        .where((e) => !e.date.isAfter(dateTime))
        .map((e) => e.reading);
    if (readings.isEmpty) return 0;
    return readings.reduce((a, b) => a > b ? a : b);
  }

  /// Lowest reading recorded after [dateTime], if any.
  ///
  /// A new entry must not exceed it, otherwise an already-recorded advance
  /// entry would end up below an earlier reading.
  double? odometerAfter(DateTime dateTime) {
    final readings = _odometerEntries
        .where((e) => e.date.isAfter(dateTime))
        .map((e) => e.reading);
    if (readings.isEmpty) return null;
    return readings.reduce((a, b) => a < b ? a : b);
  }

  double get firstOdometer {
    if (_odometerEntries.isEmpty) return 0;
    return _odometerEntries
        .map((e) => e.reading)
        .reduce((a, b) => a < b ? a : b);
  }

  double get totalDistance => currentOdometer - firstOdometer;

  double get todayDistance {
    final start = todayStart();
    final end = tomorrowStart();
    final todayEntries = _odometerEntries
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();
    if (todayEntries.length < 2) return 0;

    final todayMax = todayEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
    final todayMin = todayEntries.map((e) => e.reading).reduce((a, b) => a < b ? a : b);
    return todayMax - todayMin;
  }

  double get weekDistance {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _getDistanceForPeriod(weekStartDate, now);
  }

  double get monthDistance {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _getDistanceForPeriod(monthStart, now);
  }

  /// Exclusive upper bound for a range ending on [end] — midnight after that
  /// day, so entries dated later (advance entries) stay out of the range.
  DateTime _endBound(DateTime end) =>
      DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

  double _getDistanceForPeriod(DateTime start, DateTime end) {
    final periodEntries = _odometerEntries
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(_endBound(end)))
        .toList();
    if (periodEntries.length < 2) {
      if (periodEntries.length == 1) {
        // Find the entry just before this period
        final beforeEntries = _odometerEntries
            .where((e) => e.date.isBefore(start))
            .toList();
        if (beforeEntries.isEmpty) return 0;
        final prevMax = beforeEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
        return periodEntries.first.reading - prevMax;
      }
      return 0;
    }
    final maxReading = periodEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
    final minReading = periodEntries.map((e) => e.reading).reduce((a, b) => a < b ? a : b);
    return maxReading - minReading;
  }

  // --- Fuel Efficiency (total km / total liters for period) ---

  /// Mileage for current month: total km / total liters
  double? get currentMonthMileage {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return getMileageForRange(monthStart, now);
  }

  /// Mileage for a date range: total km / total liters
  double? getMileageForRange(DateTime start, DateTime end) {
    final distance = getDistanceForRange(start, end);
    final liters = getLitersForRange(start, end);
    if (liters <= 0 || distance <= 0) return null;
    return distance / liters;
  }

  /// Overall mileage: total km / total liters (all time)
  double? get averageMileage {
    if (totalLiters <= 0 || totalDistance <= 0) return null;
    return totalDistance / totalLiters;
  }

  double get totalFuelSpent {
    return _fuelEntries.fold<double>(0, (s, e) => s + e.totalCost);
  }

  double get totalLiters {
    return _fuelEntries.fold<double>(0, (s, e) => s + e.liters);
  }

  double? get costPerKm {
    if (totalDistance <= 0) return null;
    return totalFuelSpent / totalDistance;
  }

  // --- Period-based analytics ---

  double getDistanceForRange(DateTime start, DateTime end) {
    return _getDistanceForPeriod(start, end);
  }

  double getFuelSpentForRange(DateTime start, DateTime end) {
    return _fuelEntries
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(_endBound(end)))
        .fold<double>(0, (s, e) => s + e.totalCost);
  }

  double getLitersForRange(DateTime start, DateTime end) {
    return _fuelEntries
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(_endBound(end)))
        .fold<double>(0, (s, e) => s + e.liters);
  }

  double getMaintenanceSpentForRange(DateTime start, DateTime end) {
    return _maintenanceEntries
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(_endBound(end)))
        .fold<double>(0, (s, e) => s + e.cost);
  }

  int getFuelCountForRange(DateTime start, DateTime end) {
    return _fuelEntries
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(_endBound(end)))
        .length;
  }

  Map<DateTime, double> getDailyDistancesForRange(DateTime start, DateTime end) {
    final result = <DateTime, double>{};
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      final nextDate = current.add(const Duration(days: 1));
      final dayEntries = _odometerEntries
          .where((e) => !e.date.isBefore(current) && e.date.isBefore(nextDate))
          .toList();

      if (dayEntries.isEmpty) {
        result[current] = 0;
      } else {
        final dayMax = dayEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
        final dayMin = dayEntries.map((e) => e.reading).reduce((a, b) => a < b ? a : b);
        if (dayMax == dayMin) {
          final prevEntries = _odometerEntries.where((e) => e.date.isBefore(current)).toList();
          if (prevEntries.isEmpty) {
            result[current] = 0;
          } else {
            final prevMax = prevEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
            result[current] = dayMax - prevMax;
          }
        } else {
          result[current] = dayMax - dayMin;
        }
      }
      current = nextDate;
    }
    return result;
  }

  // --- Daily distances for chart ---

  Map<DateTime, double> getDailyDistances({int days = 7}) {
    final now = DateTime.now();
    final result = <DateTime, double>{};

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));

      final dayEntries = _odometerEntries
          .where((e) => !e.date.isBefore(date) && e.date.isBefore(nextDate))
          .toList();

      if (dayEntries.isEmpty) {
        result[date] = 0;
        continue;
      }

      final dayMax = dayEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
      final dayMin = dayEntries.map((e) => e.reading).reduce((a, b) => a < b ? a : b);

      if (dayMax == dayMin) {
        // Single entry - compare with previous day
        final prevEntries = _odometerEntries
            .where((e) => e.date.isBefore(date))
            .toList();
        if (prevEntries.isEmpty) {
          result[date] = 0;
        } else {
          final prevMax = prevEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
          result[date] = dayMax - prevMax;
        }
      } else {
        result[date] = dayMax - dayMin;
      }
    }
    return result;
  }

  // --- Advanced Analytics ---

  /// Best riding day (max distance) in a range
  MapEntry<DateTime, double>? getBestDay(DateTime start, DateTime end) {
    final daily = getDailyDistancesForRange(start, end);
    final nonZero = daily.entries.where((e) => e.value > 0).toList();
    if (nonZero.isEmpty) return null;
    return nonZero.reduce((a, b) => a.value > b.value ? a : b);
  }

  /// Total riding days in a range
  int getRidingDaysForRange(DateTime start, DateTime end) {
    final daily = getDailyDistancesForRange(start, end);
    return daily.values.where((v) => v > 0).length;
  }

  /// Current ride streak (consecutive days with rides ending today)
  int get currentStreak {
    int streak = 0;
    var date = DateTime.now();
    date = DateTime(date.year, date.month, date.day);

    while (true) {
      final nextDate = date.add(const Duration(days: 1));
      final dayEntries = _odometerEntries
          .where((e) => !e.date.isBefore(date) && e.date.isBefore(nextDate))
          .toList();
      if (dayEntries.isEmpty) {
        // Allow skipping today if it's still early
        if (streak == 0) {
          date = date.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest ever ride streak
  int get longestStreak {
    if (_odometerEntries.isEmpty) return 0;

    final sorted = List<OdometerEntry>.from(_odometerEntries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final firstDate = DateTime(sorted.first.date.year, sorted.first.date.month, sorted.first.date.day);
    final lastDate = DateTime(sorted.last.date.year, sorted.last.date.month, sorted.last.date.day);

    int longest = 0;
    int current = 0;
    var date = firstDate;

    while (!date.isAfter(lastDate)) {
      final nextDate = date.add(const Duration(days: 1));
      final hasEntry = _odometerEntries.any(
        (e) => !e.date.isBefore(date) && e.date.isBefore(nextDate),
      );
      if (hasEntry) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
      date = nextDate;
    }
    return longest;
  }

  /// Ride frequency by day of week (0=Mon, 6=Sun) → count
  Map<int, int> get rideFrequencyByWeekday {
    final freq = <int, int>{};
    final daily = getDailyDistances(days: 90);
    for (final entry in daily.entries) {
      if (entry.value > 0) {
        final weekday = entry.key.weekday; // 1=Mon, 7=Sun
        freq[weekday] = (freq[weekday] ?? 0) + 1;
      }
    }
    return freq;
  }

  /// Average fuel price over time
  double? get avgFuelPrice {
    if (_fuelEntries.isEmpty) return null;
    final sum = _fuelEntries.fold<double>(0, (s, e) => s + e.pricePerLiter);
    return sum / _fuelEntries.length;
  }

  /// Total expenses (fuel + maintenance)
  double get totalExpenses => totalFuelSpent + totalMaintenanceCost;

  // --- Combined entries for history ---

  List<dynamic> get allEntriesSorted {
    final all = <dynamic>[..._odometerEntries, ..._fuelEntries, ..._maintenanceEntries];
    all.sort((a, b) {
      final dateA = a is OdometerEntry ? a.date : a is FuelEntry ? a.date : (a as MaintenanceEntry).date;
      final dateB = b is OdometerEntry ? b.date : b is FuelEntry ? b.date : (b as MaintenanceEntry).date;
      return dateB.compareTo(dateA);
    });
    return all;
  }

  // --- CRUD Operations ---

  Future<void> loadData() async {
    final isInitialLoad = _odometerEntries.isEmpty && _fuelEntries.isEmpty && _maintenanceEntries.isEmpty;
    if (isInitialLoad) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _odometerEntries = await _db.getOdometerEntries();
      _fuelEntries = await _db.getFuelEntries();
      _maintenanceEntries = await _db.getMaintenanceEntries();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOdometerEntry(OdometerEntry entry) async {
    await _db.insertOdometerEntry(entry);
    await loadData();
  }

  Future<void> addFuelEntry(FuelEntry entry) async {
    await _db.insertFuelEntry(entry);
    await loadData();
  }

  Future<void> updateOdometerEntry(OdometerEntry entry) async {
    await _db.updateOdometerEntry(entry);
    await loadData();
  }

  Future<void> updateFuelEntry(FuelEntry entry) async {
    await _db.updateFuelEntry(entry);
    await loadData();
  }

  Future<void> deleteOdometerEntry(int id) async {
    await _db.deleteOdometerEntry(id);
    await loadData();
  }

  Future<void> deleteFuelEntry(int id) async {
    await _db.deleteFuelEntry(id);
    await loadData();
  }

  Future<void> addMaintenanceEntry(MaintenanceEntry entry) async {
    await _db.insertMaintenanceEntry(entry);
    await loadData();
  }

  Future<void> updateMaintenanceEntry(MaintenanceEntry entry) async {
    await _db.updateMaintenanceEntry(entry);
    await loadData();
  }

  Future<void> deleteMaintenanceEntry(int id) async {
    await _db.deleteMaintenanceEntry(id);
    await loadData();
  }

  // --- Maintenance Reminders ---

  int? get daysSinceLastService {
    final services = _maintenanceEntries
        .where((e) => e.category == 'General Service')
        .toList();
    if (services.isEmpty) return null;
    services.sort((a, b) => b.date.compareTo(a.date));
    return DateTime.now().difference(services.first.date).inDays;
  }

  double? get kmSinceLastService {
    final services = _maintenanceEntries
        .where((e) => e.category == 'General Service' && e.odometerReading != null)
        .toList();
    if (services.isEmpty) return null;
    services.sort((a, b) => b.date.compareTo(a.date));
    return currentOdometer - services.first.odometerReading!;
  }

  bool get isServiceDue {
    final days = daysSinceLastService;
    final km = kmSinceLastService;
    if (days == null && km == null) return false;
    return (days != null && days >= 90) || (km != null && km >= 3000);
  }

  /// Check if an odometer reading already exists for the same day
  bool isDuplicateReadingForDate(double reading, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _odometerEntries.any((e) =>
        e.reading == reading &&
        !e.date.isBefore(dayStart) &&
        e.date.isBefore(dayEnd));
  }

  // --- Monthly spending for chart ---

  Map<String, double> getMonthlySpending({int months = 6}) {
    final result = <String, double>{};
    final now = DateTime.now();
    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final end = DateTime(month.year, month.month + 1, 0);
      final fuel = getFuelSpentForRange(month, end);
      final maint = getMaintenanceSpentForRange(month, end);
      result[DateFormat('MMM').format(month)] = fuel + maint;
    }
    return result;
  }

  // --- Backup Reminder ---

  bool get shouldRemindBackup {
    final totalEntries = _odometerEntries.length + _fuelEntries.length + _maintenanceEntries.length;
    return totalEntries > 50 && !_hasExported;
  }

  // --- CSV Export / Import ---

  /// Builds the backup file contents. Writing is left to the caller so the
  /// export can be saved wherever the user chooses.
  String buildCsvContent() {
    return buildCsv(
      odometer: _odometerEntries,
      fuel: _fuelEntries,
      maintenance: _maintenanceEntries,
      summary: {
        'Total Distance': '${totalDistance.toStringAsFixed(1)} km',
        'Total Fuel Spent': '₹${totalFuelSpent.toStringAsFixed(2)}',
        'Total Fuel': '${totalLiters.toStringAsFixed(2)} L',
        'Overall Mileage': '${averageMileage?.toStringAsFixed(1) ?? 'N/A'} km/l',
        'Total Maintenance': '₹${totalMaintenanceCost.toStringAsFixed(2)}',
        'Total Expenses': '₹${totalExpenses.toStringAsFixed(2)}',
      },
    );
  }

  /// Suggested file name for an export.
  String exportFileName() =>
      'ridelog_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

  void markExported() {
    _hasExported = true;
    notifyListeners();
  }

  /// Restores [data] into the database.
  ///
  /// With [replaceExisting] every current entry is wiped first; otherwise the
  /// import is merged and entries already present are skipped, so importing the
  /// same file twice does not duplicate anything.
  Future<ImportResult> importData(
    CsvImportData data, {
    required bool replaceExisting,
  }) async {
    if (replaceExisting) {
      await _db.deleteAllEntries();
      await _db.insertAll(
        odometer: data.odometer,
        fuel: data.fuel,
        maintenance: data.maintenance,
      );
      await loadData();
      return ImportResult(added: data.total, errors: data.errors);
    }

    final existingOdo = _odometerEntries.map(_odometerKey).toSet();
    final existingFuel = _fuelEntries.map(_fuelKey).toSet();
    final existingMaint = _maintenanceEntries.map(_maintenanceKey).toSet();

    final odometer = data.odometer.where((e) => existingOdo.add(_odometerKey(e))).toList();
    final fuel = data.fuel.where((e) => existingFuel.add(_fuelKey(e))).toList();
    final maintenance = data.maintenance.where((e) => existingMaint.add(_maintenanceKey(e))).toList();

    await _db.insertAll(odometer: odometer, fuel: fuel, maintenance: maintenance);
    await loadData();

    final added = odometer.length + fuel.length + maintenance.length;
    return ImportResult(
      added: added,
      skipped: data.total - added,
      errors: data.errors,
    );
  }

  /// Entries are considered the same when they land on the same minute with the
  /// same values — the CSV carries no ids to match on.
  ///
  /// Deliberately coarser than the stored timestamp, which keeps seconds: a
  /// backup taken before seconds were recorded still de-duplicates against
  /// entries that have them.
  String _minuteKey(DateTime d) =>
      '${d.year}-${d.month}-${d.day}-${d.hour}-${d.minute}';

  String _odometerKey(OdometerEntry e) => '${_minuteKey(e.date)}|${e.reading}';

  String _fuelKey(FuelEntry e) =>
      '${_minuteKey(e.date)}|${e.totalCost}|${e.odometerReading}';

  String _maintenanceKey(MaintenanceEntry e) =>
      '${_minuteKey(e.date)}|${e.category}|${e.cost}';
}
