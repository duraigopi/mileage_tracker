import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';

/// Shown in the add/edit sheets when the entry is dated ahead of today, so it
/// is obvious the reading is being recorded in advance.
class AdvanceEntryNotice extends StatelessWidget {
  final DateTime date;

  const AdvanceEntryNotice({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).reminderBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).reminderBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: Color(0xFFE65100)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Advance entry — saved for ${DateFormat('MMM dd').format(date)}',
              style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
