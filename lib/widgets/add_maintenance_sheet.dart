import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bike_provider.dart';
import '../models/maintenance_entry.dart';
import '../utils/app_colors.dart';

class AddMaintenanceSheet extends StatefulWidget {
  final MaintenanceEntry? entry;

  const AddMaintenanceSheet({super.key, this.entry});

  @override
  State<AddMaintenanceSheet> createState() => _AddMaintenanceSheetState();
}

class _AddMaintenanceSheetState extends State<AddMaintenanceSheet> {
  final _costController = TextEditingController();
  final _odometerController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedCategory;
  String? _errorText;
  TextEditingController? _autocompleteController;

  bool get _isEditing => widget.entry != null;

  static const _categoryIcons = <String, IconData>{
    'General Service': Icons.build,
    'Air Checkup': Icons.tire_repair,
    'Washing': Icons.water,
    'Other': Icons.more_horiz,
  };

  static const _categoryColors = <String, Color>{
    'General Service': Color(0xFF1976D2),
    'Air Checkup': Color(0xFF00897B),
    'Washing': Color(0xFF0288D1),
    'Other': Color(0xFF757575),
  };

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _costController.text = widget.entry!.cost.toString();
      _odometerController.text = widget.entry!.odometerReading?.toString() ?? '';
      _noteController.text = widget.entry!.note ?? '';
      _selectedDate = widget.entry!.date;
      _selectedTime = TimeOfDay.fromDateTime(widget.entry!.date);
      _selectedCategory = widget.entry!.category;
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _selectedCategory = MaintenanceCategory.general;
    }
  }

  @override
  void dispose() {
    _costController.dispose();
    _odometerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BikeProvider>();

    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
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
            // Title + Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.build, color: Color(0xFF7B1FA2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Maintenance' : 'Add Maintenance',
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

            // Category
            Text(
              'Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MaintenanceCategory.all.map((cat) {
                final isSelected = _selectedCategory == cat;
                final color = _categoryColors[cat] ?? Colors.grey;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.15) : AppColors.of(context).surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : AppColors.of(context).border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcons[cat] ?? Icons.more_horiz,
                          size: 16,
                          color: isSelected ? color : AppColors.of(context).textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? color : AppColors.of(context).textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Cost
            TextField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Cost',
                labelStyle: TextStyle(fontSize: 14, color: AppColors.of(context).textTertiary),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
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
                  borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(height: 14),

            // Odometer (optional)
            TextField(
              controller: _odometerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: InputDecoration(
                labelText: 'Odometer Reading (optional)',
                labelStyle: TextStyle(fontSize: 13, color: AppColors.of(context).textTertiary),
                suffixText: 'km',
                suffixStyle: TextStyle(fontSize: 14, color: AppColors.of(context).textTertiary),
                prefixIcon: Icon(Icons.speed, color: AppColors.of(context).textHint, size: 20),
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
                  borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),

            // Note with suggestions
            _buildNoteField(provider),

            // Error
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
                        backgroundColor: const Color(0xFF7B1FA2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _isEditing ? 'Update Maintenance' : 'Save Maintenance',
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
    final suggestions = provider.maintenanceNoteSuggestions;
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return suggestions.take(5);
        return suggestions.where(
          (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      initialValue: TextEditingValue(text: _noteController.text),
      onSelected: (value) => _noteController.text = value,
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
              borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
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
        title: const Text('Delete Maintenance Entry'),
        content: const Text('Are you sure you want to delete this maintenance entry?'),
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
      context.read<BikeProvider>().deleteMaintenanceEntry(widget.entry!.id!);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _save() {
    final cost = double.tryParse(_costController.text);
    if (cost == null || cost <= 0) {
      setState(() => _errorText = 'Please enter the cost');
      return;
    }

    final odometer = double.tryParse(_odometerController.text);

    setState(() => _errorText = null);

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final entry = MaintenanceEntry(
      id: _isEditing ? widget.entry!.id : null,
      date: dateTime,
      category: _selectedCategory,
      cost: cost,
      odometerReading: odometer,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      createdAt: _isEditing ? widget.entry!.createdAt : null,
    );

    final provider = context.read<BikeProvider>();
    if (_isEditing) {
      provider.updateMaintenanceEntry(entry);
    } else {
      provider.addMaintenanceEntry(entry);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Maintenance updated' : '${_selectedCategory} saved: ₹${cost.toStringAsFixed(0)}'),
        backgroundColor: const Color(0xFF388E3C),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
