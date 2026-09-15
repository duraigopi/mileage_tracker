import 'package:intl/intl.dart';
import '../models/odometer_entry.dart';
import '../models/fuel_entry.dart';
import '../models/maintenance_entry.dart';

/// Section markers. These double as the anchors the importer looks for, so an
/// exported file round-trips back into the app.
const String kOdometerSection = '=== ODOMETER READINGS ===';
const String kFuelSection = '=== FUEL ENTRIES ===';
const String kMaintenanceSection = '=== MAINTENANCE ===';
const String kSummarySection = '=== SUMMARY ===';

final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');
final DateFormat _timeFormat = DateFormat('HH:mm:ss');
final DateFormat _dateTimeFormat = DateFormat('dd-MM-yyyy HH:mm:ss');
// Files exported before entries carried seconds
final DateFormat _legacyDateTimeFormat = DateFormat('dd-MM-yyyy HH:mm');

/// Everything parsed out of a backup file, plus any rows that could not be read.
class CsvImportData {
  final List<OdometerEntry> odometer;
  final List<FuelEntry> fuel;
  final List<MaintenanceEntry> maintenance;
  final List<String> errors;

  const CsvImportData({
    this.odometer = const [],
    this.fuel = const [],
    this.maintenance = const [],
    this.errors = const [],
  });

  int get total => odometer.length + fuel.length + maintenance.length;
  bool get isEmpty => total == 0;
}

/// Quotes a field if it contains a comma or quote. Newlines are folded to
/// spaces so every record stays on one line and can be parsed line by line.
String _escape(Object? value) {
  var s = value?.toString() ?? '';
  s = s.replaceAll(RegExp(r'[\r\n]+'), ' ');
  if (s.contains(',') || s.contains('"')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Splits one CSV line, honouring quoted fields and doubled-quote escapes.
List<String> splitCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(ch);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

/// Builds the backup file. Readable in a spreadsheet, and complete enough to
/// restore from — every entry carries its own date and time.
String buildCsv({
  required List<OdometerEntry> odometer,
  required List<FuelEntry> fuel,
  required List<MaintenanceEntry> maintenance,
  Map<String, String> summary = const {},
}) {
  final buffer = StringBuffer();

  buffer.writeln(kOdometerSection);
  buffer.writeln('Date,Time,Reading (km),Note');
  final odoSorted = List<OdometerEntry>.from(odometer)
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final e in odoSorted) {
    buffer.writeln([
      _dateFormat.format(e.date),
      _timeFormat.format(e.date),
      e.reading,
      _escape(e.note),
    ].join(','));
  }

  buffer.writeln();
  buffer.writeln(kFuelSection);
  buffer.writeln('Date,Time,Odometer (km),Liters,Rate,Amount,Note');
  final fuelSorted = List<FuelEntry>.from(fuel)
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final e in fuelSorted) {
    buffer.writeln([
      _dateFormat.format(e.date),
      _timeFormat.format(e.date),
      e.odometerReading,
      e.liters.toStringAsFixed(2),
      e.pricePerLiter,
      e.totalCost,
      _escape(e.note),
    ].join(','));
  }

  buffer.writeln();
  buffer.writeln(kMaintenanceSection);
  buffer.writeln('Date,Time,Category,Cost,Odometer (km),Note');
  final maintSorted = List<MaintenanceEntry>.from(maintenance)
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final e in maintSorted) {
    buffer.writeln([
      _dateFormat.format(e.date),
      _timeFormat.format(e.date),
      _escape(e.category),
      e.cost,
      e.odometerReading ?? '',
      _escape(e.note),
    ].join(','));
  }

  if (summary.isNotEmpty) {
    buffer.writeln();
    buffer.writeln(kSummarySection);
    summary.forEach((key, value) {
      buffer.writeln('${_escape(key)},${_escape(value)}');
    });
  }

  return buffer.toString();
}

/// Parses a file produced by [buildCsv]. Rows that cannot be read land in
/// [CsvImportData.errors] instead of aborting the whole import.
CsvImportData parseCsv(String content) {
  final odometer = <OdometerEntry>[];
  final fuel = <FuelEntry>[];
  final maintenance = <MaintenanceEntry>[];
  final errors = <String>[];

  final lines = content.split(RegExp(r'\r?\n'));
  String? section;
  var hasTimeColumn = true;
  var expectingHeader = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    if (line.startsWith('===')) {
      section = line;
      expectingHeader = true;
      continue;
    }
    if (section == null || section == kSummarySection) continue;

    // The column-header row tells us whether this file carries a Time column
    if (expectingHeader) {
      expectingHeader = false;
      if (line.toLowerCase().startsWith('date,')) {
        hasTimeColumn = line.toLowerCase().contains(',time,');
        continue;
      }
    }

    final fields = splitCsvLine(line);
    final lineNo = i + 1;
    try {
      final date = _parseDateTime(fields, hasTimeColumn);
      // Skip past the date (and time, when present) to the value columns
      final v = fields.sublist(hasTimeColumn ? 2 : 1);

      if (section == kOdometerSection) {
        odometer.add(OdometerEntry(
          date: date,
          reading: _requireDouble(_at(v, 0), 'reading'),
          note: _nullIfBlank(_at(v, 1)),
        ));
      } else if (section == kFuelSection) {
        fuel.add(FuelEntry(
          date: date,
          odometerReading: _requireDouble(_at(v, 0), 'odometer'),
          liters: _requireDouble(_at(v, 1), 'liters'),
          pricePerLiter: _requireDouble(_at(v, 2), 'rate'),
          totalCost: _requireDouble(_at(v, 3), 'amount'),
          note: _nullIfBlank(_at(v, 4)),
        ));
      } else if (section == kMaintenanceSection) {
        final category = (_at(v, 0) ?? '').trim();
        maintenance.add(MaintenanceEntry(
          date: date,
          category: category.isEmpty ? MaintenanceCategory.other : category,
          cost: _requireDouble(_at(v, 1), 'cost'),
          odometerReading: _optionalDouble(_at(v, 2)),
          note: _nullIfBlank(_at(v, 3)),
        ));
      }
    } catch (e) {
      errors.add('Line $lineNo: ${e is FormatException ? e.message : e}');
    }
  }

  return CsvImportData(
    odometer: odometer,
    fuel: fuel,
    maintenance: maintenance,
    errors: errors,
  );
}

String? _at(List<String> fields, int index) =>
    index < fields.length ? fields[index] : null;

DateTime _parseDateTime(List<String> fields, bool hasTimeColumn) {
  if (fields.isEmpty || fields[0].trim().isEmpty) {
    throw const FormatException('missing date');
  }
  final date = fields[0].trim();
  final time = hasTimeColumn && fields.length > 1 && fields[1].trim().isNotEmpty
      ? fields[1].trim()
      : '00:00:00';
  try {
    return _dateTimeFormat.parse('$date $time');
  } on FormatException {
    // A file exported before seconds were recorded carries HH:mm only
    try {
      return _legacyDateTimeFormat.parse('$date $time');
    } on FormatException {
      // Tolerate an ISO-8601 date written by another tool
      final iso = DateTime.tryParse(date);
      if (iso != null) return iso;
      throw FormatException('unreadable date "$date"');
    }
  }
}

double _requireDouble(String? raw, String field) {
  final value = double.tryParse((raw ?? '').trim());
  if (value == null) throw FormatException('invalid $field "${raw ?? ''}"');
  return value;
}

double? _optionalDouble(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String? _nullIfBlank(String? raw) {
  final text = (raw ?? '').trim();
  return text.isEmpty ? null : text;
}
