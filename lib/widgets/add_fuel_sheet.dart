import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bike_provider.dart';
import '../models/fuel_entry.dart';
import '../utils/app_colors.dart';

class AddFuelSheet extends StatefulWidget {
  final FuelEntry? entry;

  const AddFuelSheet({super.key, this.entry});

  @override
  State<AddFuelSheet> createState() => _AddFuelSheetState();
}

class _AddFuelSheetState extends State<AddFuelSheet> {
  final _odometerController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _errorText;
  TextEditingController? _autocompleteController;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BikeProvider>();

    if (_isEditing) {
      _odometerController.text = widget.entry!.odometerReading.toString();
      _amountController.text = widget.entry!.totalCost.toString();
      _rateController.text = widget.entry!.pricePerLiter.toString();
      _noteController.text = widget.entry!.note ?? '';
      _selectedDate = widget.entry!.date;
      _selectedTime = TimeOfDay.fromDateTime(widget.entry!.date);
    } else {
      _rateController.text = provider.lastPetrolRate.toString();
      if (provider.currentOdometer > 0) {
        _odometerController.text = provider.currentOdometer.toStringAsFixed(1);
      }
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  double get _rate => double.tryParse(_rateController.text) ?? 0;
  double get _liters => _rate > 0 ? _amount / _rate : 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BikeProvider>();
    final lastReading = provider.currentOdometer;

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
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_gas_station, color: Color(0xFFFF6D00)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Fuel Entry' : 'Add Fuel Entry',
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
                'Last odometer: ${NumberFormat('#,##0.0').format(lastReading)} km',
                style: TextStyle(fontSize: 13, color: AppColors.of(context).textTertiary),
              ),
            const SizedBox(height: 24),

            // Date & Time
            Row(
              children: [
                Expanded(child: _buildDateTimePicker(
                  icon: Icons.calendar_today,
                  label: DateFormat('MMM dd, yyyy').format(_selectedDate),
                  onTap: _pickDate,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildDateTimePicker(
                  icon: Icons.access_time,
                  label: _selectedTime.format(context),
                  onTap: _pickTime,
                )),
              ],
            ),
            const SizedBox(height: 20),

            // Odometer reading (optional, auto-filled)
            _buildInputField(
              controller: _odometerController,
              label: 'Odometer Reading (optional)',
              suffix: 'km',
              icon: Icons.speed,
              color: const Color(0xFF2196F3),
            ),
            const SizedBox(height: 14),

            // Amount & Rate
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _amountController,
                    label: 'Amount Paid',
                    suffix: '₹',
                    icon: Icons.currency_rupee,
                    color: const Color(0xFFD32F2F),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _rateController,
                    label: 'Petrol Rate',
                    suffix: '₹/L',
                    icon: Icons.local_gas_station,
                    color: const Color(0xFFFF6D00),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Calculated liters & total display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.of(context).fuelCalcBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.of(context).fuelCalcBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388E3C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.water_drop, color: Color(0xFF388E3C), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fuel Quantity',
                        style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary),
                      ),
                      Text(
                        '${_liters.toStringAsFixed(2)} L',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF388E3C),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_amount > 0 && _rate > 0)
                    Text(
                      '₹${_amount.toStringAsFixed(0)} ÷ ₹${_rate.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Note with suggestions
            _buildNoteField(provider),

            // Error display
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

            // Buttons
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
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _isEditing ? 'Update Fuel Entry' : 'Save Fuel Entry',
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
    required Color color,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: AppColors.of(context).textTertiary),
        suffixText: suffix,
        suffixStyle: TextStyle(fontSize: 14, color: AppColors.of(context).textTertiary, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: color, size: 20),
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
          borderSide: BorderSide(color: color, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildNoteField(BikeProvider provider) {
    final suggestions = provider.fuelNoteSuggestions;
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
                  borderSide: const BorderSide(color: Color(0xFFFF6D00), width: 2),
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
        title: const Text('Delete Fuel Entry'),
        content: const Text('Are you sure you want to delete this fuel entry?'),
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
      context.read<BikeProvider>().deleteFuelEntry(widget.entry!.id!);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _save() {
    final odometer = double.tryParse(_odometerController.text);
    final amount = double.tryParse(_amountController.text);
    final rate = double.tryParse(_rateController.text);

    if (amount == null || amount <= 0) {
      _showError('Please enter the amount paid');
      return;
    }
    if (rate == null || rate <= 0) {
      _showError('Please enter the petrol rate');
      return;
    }

    final provider = context.read<BikeProvider>();
    final finalOdometer = (odometer != null && odometer > 0) ? odometer : provider.currentOdometer;

    setState(() => _errorText = null);

    final liters = amount / rate;
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final fuelEntry = FuelEntry(
      id: _isEditing ? widget.entry!.id : null,
      date: dateTime,
      odometerReading: finalOdometer,
      liters: liters,
      pricePerLiter: rate,
      totalCost: amount,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      createdAt: _isEditing ? widget.entry!.createdAt : null,
    );

    if (_isEditing) {
      provider.updateFuelEntry(fuelEntry);
    } else {
      provider.addFuelEntry(fuelEntry);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Fuel entry updated' : 'Fuel entry saved: ${liters.toStringAsFixed(2)} L for ₹${amount.toStringAsFixed(0)}'),
        backgroundColor: const Color(0xFF388E3C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    setState(() => _errorText = message);
  }
}
