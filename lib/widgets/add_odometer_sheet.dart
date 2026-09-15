import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bike_provider.dart';
import '../models/odometer_entry.dart';
import '../utils/app_colors.dart';

class AddOdometerSheet extends StatefulWidget {
  final OdometerEntry? entry;

  const AddOdometerSheet({super.key, this.entry});

  @override
  State<AddOdometerSheet> createState() => _AddOdometerSheetState();
}

class _AddOdometerSheetState extends State<AddOdometerSheet> {
  final _readingController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _errorText;
  TextEditingController? _autocompleteController;
  final _readingFocusNode = FocusNode();

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // Show only last 3+decimal digits for editing
      final lastDigits = widget.entry!.reading % 1000;
      _readingController.text = lastDigits.toStringAsFixed(1);
      _noteController.text = widget.entry!.note ?? '';
      _selectedDate = widget.entry!.date;
      _selectedTime = TimeOfDay.fromDateTime(widget.entry!.date);
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();

      final provider = context.read<BikeProvider>();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEntries = provider.odometerEntries
          .where((e) => !e.date.isBefore(todayStart))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final hasTodayEntry = todayEntries.isNotEmpty;

      // Auto-fill odometer with previous day's last reading if no entry today
      if (!hasTodayEntry && provider.currentOdometer > 0) {
        final lastDigits = provider.currentOdometer % 1000;
        _readingController.text = lastDigits.toStringAsFixed(1);
      }

      // Auto-fill note
      if (!hasTodayEntry) {
        // First ride of the day → use previous day's first entry note
        final yesterday = todayStart.subtract(const Duration(days: 1));
        final yesterdayEntries = provider.odometerEntries
            .where((e) => !e.date.isBefore(yesterday) && e.date.isBefore(todayStart))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        if (yesterdayEntries.isNotEmpty && yesterdayEntries.first.note != null) {
          _noteController.text = yesterdayEntries.first.note!;
        }
      } else if (now.hour >= 20) {
        // After 8 PM → use today's first entry note (heading back to start)
        if (todayEntries.first.note != null) {
          _noteController.text = todayEntries.first.note!;
        }
      }
    }

    _readingFocusNode.addListener(() {
      if (!_readingFocusNode.hasFocus) {
        _autoFormatReading();
      }
    });
  }

  @override
  void dispose() {
    _readingFocusNode.dispose();
    _readingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Auto-insert decimal before last digit when 4+ digits entered
  /// e.g. "4200" → "420.0", "4185" → "418.5"
  void _autoFormatReading() {
    final text = _readingController.text.trim();
    if (text.isEmpty || text.contains('.')) return;

    if (text.length >= 4) {
      final formatted = '${text.substring(0, text.length - 1)}.${text[text.length - 1]}';
      _readingController.text = formatted;
      setState(() {});
    }
  }

  /// Get the entered value with auto-decimal applied
  double? _getEnteredValue() {
    final text = _readingController.text.trim();
    if (text.isEmpty) return null;
    // If no decimal and 4+ digits, insert before last digit
    if (!text.contains('.') && text.length >= 4) {
      return double.tryParse('${text.substring(0, text.length - 1)}.${text[text.length - 1]}');
    }
    return double.tryParse(text);
  }

  /// Calculate full reading from the entered last digits
  double? _getFullReading(BikeProvider provider) {
    final entered = _getEnteredValue();
    if (entered == null) return null;

    if (_isEditing) {
      // Use the original reading's prefix
      final prefix = (widget.entry!.reading / 1000).floor() * 1000;
      final full = prefix + entered;
      // If the result is less than (prefix), it means rollover
      if (full < widget.entry!.reading - 999) {
        return prefix + 1000 + entered;
      }
      return full;
    }

    final current = provider.currentOdometer;
    if (current <= 0) return entered; // No previous reading, use as-is

    final prefix = (current / 1000).floor() * 1000;
    final full = prefix + entered;

    // If calculated < current, the odometer rolled over to next thousand
    if (full < current) {
      return prefix + 1000 + entered;
    }
    return full;
  }

  bool get _isInputComplete {
    final text = _readingController.text.trim();
    return text.contains('.') || text.length >= 4;
  }

  String _getPrefix(BikeProvider provider) {
    if (_isEditing) {
      return (widget.entry!.reading / 1000).floor().toString();
    }
    final current = provider.currentOdometer;
    if (current <= 0) return '';
    // Only recalculate prefix when input is complete (4+ digits or has decimal)
    if (_isInputComplete) {
      final entered = _getEnteredValue();
      if (entered != null) {
        final prefix = (current / 1000).floor() * 1000;
        final full = prefix + entered;
        if (full < current) {
          return ((prefix / 1000).floor() + 1).toString();
        }
      }
    }
    return (current / 1000).floor().toString();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BikeProvider>();
    final lastReading = provider.currentOdometer;
    final fullReading = _getFullReading(provider);

    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.speed, color: Color(0xFF2196F3)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Odometer Reading' : 'Add Odometer Reading',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.of(context).textTertiary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.of(context).divider,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_isEditing && lastReading > 0)
              Text(
                'Last reading: ${NumberFormat('#,##0.0').format(lastReading)} km',
                style: TextStyle(fontSize: 13, color: AppColors.of(context).textTertiary),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDateTimePicker(
                    icon: Icons.calendar_today,
                    label: DateFormat('MMM dd, yyyy').format(_selectedDate),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateTimePicker(
                    icon: Icons.access_time,
                    label: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Odometer input with auto-prefix
            Row(
              children: [
                Text(
                  'Enter last 4 digits (with decimal)',
                  style: TextStyle(fontSize: 13, color: AppColors.of(context).textTertiary),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Row(
                          children: [
                            Icon(Icons.help_outline, color: Color(0xFF2196F3), size: 22),
                            SizedBox(width: 8),
                            Text('How it works', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        content: const Text(
                          'Just enter the last digits you see on your bike meter (e.g., 406.0).\n\n'
                          'The prefix number is auto-calculated from your current odometer reading.\n\n'
                          'If the digits are less than current, it automatically detects the rollover.',
                          style: TextStyle(fontSize: 14, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(Icons.help_outline, size: 18, color: AppColors.of(context).textHint),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Auto prefix
                if (lastReading > 0 || _isEditing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      _getPrefix(provider),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                if (lastReading > 0 || _isEditing)
                  const SizedBox(width: 8),
                // User input (last digits)
                Expanded(
                  child: TextField(
                    controller: _readingController,
                    focusNode: _readingFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '000.0',
                      hintStyle: TextStyle(color: AppColors.of(context).border, fontSize: 28, fontWeight: FontWeight.bold),
                      suffixText: 'km',
                      suffixStyle: TextStyle(fontSize: 16, color: AppColors.of(context).textTertiary, fontWeight: FontWeight.w500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.of(context).border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.of(context).border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    autofocus: false,
                  ),
                ),
              ],
            ),

            // Calculated full reading display
            if (fullReading != null && _isInputComplete) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.of(context).successBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.of(context).successBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: const Color(0xFF388E3C)),
                    const SizedBox(width: 8),
                    Text('Full reading: ', style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary)),
                    Text(
                      '${NumberFormat('#,##0.0').format(fullReading)} km',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF388E3C)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            _buildNoteField(provider),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.of(context).errorBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.of(context).errorBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (_isEditing) ...[
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteEntry(context),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _isEditing ? 'Update Reading' : 'Save Reading',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField(BikeProvider provider) {
    final suggestions = provider.odometerNoteSuggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return suggestions.take(5);
            }
            return suggestions.where(
              (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
            );
          },
          onSelected: (value) {
            _noteController.text = value;
          },
          initialValue: TextEditingValue(text: _noteController.text),
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            if (_autocompleteController != controller) {
              _autocompleteController = controller;
              controller.addListener(() => _noteController.text = controller.text);
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                hintStyle: TextStyle(color: AppColors.of(context).textHint),
                prefixIcon: Icon(Icons.note, color: AppColors.of(context).textHint, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.of(context).border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.of(context).border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  width: MediaQuery.of(context).size.width - 48,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.of(context).divider),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.history, size: 18, color: AppColors.of(context).textHint),
                        title: Text(option, style: const TextStyle(fontSize: 14)),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateTimePicker({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.of(context).border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.of(context).textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.of(context).textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _selectedTime);
    if (time != null) setState(() => _selectedTime = time);
  }

  void _deleteEntry(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Odometer Reading'),
        content: const Text('Are you sure you want to delete this reading?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      context.read<BikeProvider>().deleteOdometerEntry(widget.entry!.id!);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _save() {
    _autoFormatReading();
    final provider = context.read<BikeProvider>();
    final fullReading = _getFullReading(provider);

    if (fullReading == null || fullReading <= 0) {
      setState(() => _errorText = 'Please enter a valid reading');
      return;
    }

    if (!_isEditing && fullReading < provider.currentOdometer) {
      setState(() => _errorText = 'Reading ${fullReading.toStringAsFixed(1)} must be > current (${provider.currentOdometer.toStringAsFixed(1)} km)');
      return;
    }

    if (!_isEditing && provider.isDuplicateReadingForDate(fullReading, _selectedDate)) {
      setState(() => _errorText = 'Reading ${fullReading.toStringAsFixed(1)} already exists for this day');
      return;
    }

    setState(() => _errorText = null);

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (_isEditing) {
      provider.updateOdometerEntry(OdometerEntry(
        id: widget.entry!.id,
        date: dateTime,
        reading: fullReading,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        createdAt: widget.entry!.createdAt,
      ));
    } else {
      provider.addOdometerEntry(OdometerEntry(
        date: dateTime,
        reading: fullReading,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      ));
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Reading updated' : 'Reading saved: ${fullReading.toStringAsFixed(1)} km'),
        backgroundColor: const Color(0xFF388E3C),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
