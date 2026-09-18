import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bike_provider.dart';
import '../models/odometer_entry.dart';
import '../models/fuel_entry.dart';
import '../models/maintenance_entry.dart';
import '../widgets/add_odometer_sheet.dart';
import '../widgets/add_fuel_sheet.dart';
import '../widgets/add_maintenance_sheet.dart';
import '../utils/app_colors.dart';
import '../widgets/advance_entry_notice.dart';
import '../widgets/tile_card.dart';
import '../utils/entry_date.dart';
import '../utils/ride_distance.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filter = 0; // 0=All, 1=Odometer, 2=Fuel, 3=Maintenance
  late DateTime _currentMonth;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime get _monthEnd => DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

  void _previousMonth() {
    _AnimatedListItem.resetAnimation();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    if (!next.isAfter(DateTime.now())) {
      _AnimatedListItem.resetAnimation();
      setState(() => _currentMonth = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BikeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final allEntries = provider.allEntriesSorted;

        if (allEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: AppColors.of(context).border),
                const SizedBox(height: 16),
                Text('No entries yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.of(context).textTertiary)),
                const SizedBox(height: 8),
                Text('Start by adding an odometer reading\nor a fuel entry',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.of(context).textHint)),
              ],
            ),
          );
        }

        // Filter by month
        final monthEntries = allEntries.where((e) {
          final date = e is OdometerEntry ? e.date : e is FuelEntry ? e.date : (e as MaintenanceEntry).date;
          return !date.isBefore(_currentMonth) && !date.isAfter(_monthEnd);
        }).toList();

        // Apply type filter
        final entries = _filter == 0
            ? monthEntries
            : monthEntries.where((e) {
                if (_filter == 1) return e is OdometerEntry;
                if (_filter == 2) return e is FuelEntry;
                return e is MaintenanceEntry;
              }).toList();

        // Group entries by date
        final grouped = <String, List<dynamic>>{};
        for (final entry in entries) {
          final date = entry is OdometerEntry ? entry.date : entry is FuelEntry ? entry.date : (entry as MaintenanceEntry).date;
          final key = DateFormat('yyyy-MM-dd').format(date);
          grouped.putIfAbsent(key, () => []).add(entry);
        }
        final groupedKeys = grouped.keys.toList();

        return Column(
          children: [
            // Month navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: AppColors.of(context).card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.of(context).cardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                    color: AppColors.of(context).textSecondary,
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth,
                    color: AppColors.of(context).textSecondary,
                  ),
                ],
              ),
            ),

            // Filter tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.of(context).surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildFilterTab('All', 0, monthEntries.length),
                    _buildFilterTab('Odometer', 1, monthEntries.whereType<OdometerEntry>().length),
                    _buildFilterTab('Fuel', 2, monthEntries.whereType<FuelEntry>().length),
                    _buildFilterTab('Service', 3, monthEntries.whereType<MaintenanceEntry>().length),
                  ],
                ),
              ),
            ),
            // Entry list
            Expanded(
              child: entries.isEmpty
                  ? Center(child: Text('No entries for this filter', style: TextStyle(color: AppColors.of(context).textHint)))
                  : RefreshIndicator(
          onRefresh: () => provider.loadData(),
          color: const Color(0xFF1B5E20),
          child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: groupedKeys.length,
          itemBuilder: (context, index) {
            final dateKey = groupedKeys[index];
            final dateEntries = grouped[dateKey]!;
            final date = DateTime.parse(dateKey);

            return _AnimatedListItem(
              key: ValueKey('${_filter}_${_currentMonth}_$dateKey'),
              index: index,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Expanded rather than a trailing Spacer: the weekday and
                      // the Advance badge need room to shrink before the day's
                      // distance is pushed off the right edge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    DateFormat('EEEE').format(date),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.of(context).textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Advance applies to the whole day, so it is
                                // stated once here rather than on every entry
                                if (isAdvanceEntryDate(date)) ...[
                                  const SizedBox(width: 8),
                                  const AdvanceEntryBadge(),
                                ],
                              ],
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(date),
                              style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_getDayDistance(dateEntries, provider).toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20),
                            ),
                          ),
                          Text(
                            '${dateEntries.length} ${dateEntries.length == 1 ? 'entry' : 'entries'}',
                            style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Entries for this date
                TileCard(
                  color: Theme.of(context).cardColor,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dateEntries.length,
                    separatorBuilder: (_, __) => Divider(height: 1, indent: 68, color: AppColors.of(context).divider),
                    itemBuilder: (context, entryIndex) {
                      final entry = dateEntries[entryIndex];
                      if (entry is OdometerEntry) {
                        return _buildOdometerTile(context, entry, provider);
                      } else if (entry is FuelEntry) {
                        return _buildFuelTile(context, entry, provider);
                      } else if (entry is MaintenanceEntry) {
                        return _buildMaintenanceTile(context, entry, provider);
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            );
          },
        ),
        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterTab(String label, int index, int count) {
    final isSelected = _filter == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20);
    return Expanded(
      child: GestureDetector(
        onTap: () { _AnimatedListItem.resetAnimation(); setState(() => _filter = index); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.of(context).card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : AppColors.of(context).textTertiary,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? activeColor : AppColors.of(context).textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOdometerTile(BuildContext context, OdometerEntry entry, BikeProvider provider) {
    // Distance covered to reach this reading, measured from the entry before
    // it in time (see distanceFromPrevious for why not by reading)
    final rideDistance =
        distanceFromPrevious(provider.odometerEntries, entry);

    return Dismissible(
      key: Key('odo_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) => _confirmDelete(context, 'odometer reading'),
      onDismissed: (_) => provider.deleteOdometerEntry(entry.id!),
      child: ListTile(
        onTap: () => _editOdometerEntry(context, entry),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.speed, color: Color(0xFF2196F3), size: 22),
        ),
        title: Row(
          children: [
            Text(
              '${NumberFormat('#,##0.0').format(entry.reading)} km',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (rideDistance > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF388E3C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${rideDistance.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF388E3C)),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          entry.note ?? 'Odometer reading',
          style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('hh:mm a').format(entry.date),
              style: TextStyle(fontSize: 12, color: AppColors.of(context).textHint),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 16, color: AppColors.of(context).border),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTile(BuildContext context, FuelEntry entry, BikeProvider provider) {
    return Dismissible(
      key: Key('fuel_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) => _confirmDelete(context, 'fuel entry'),
      onDismissed: (_) => provider.deleteFuelEntry(entry.id!),
      child: ListTile(
        onTap: () => _editFuelEntry(context, entry),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_gas_station, color: Color(0xFFFF6D00), size: 22),
        ),
        title: Text(
          '${entry.liters.toStringAsFixed(2)} L  •  ₹${entry.totalCost.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.speed, size: 12, color: AppColors.of(context).textHint),
            const SizedBox(width: 4),
            Text(
              '${NumberFormat('#,##0.0').format(entry.odometerReading)} km',
              style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
            ),
            if (entry.note != null && entry.note!.isNotEmpty) ...[
              Text('  •  ', style: TextStyle(color: AppColors.of(context).textHint)),
              Expanded(
                child: Text(
                  entry.note!,
                  style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${entry.pricePerLiter.toStringAsFixed(1)}/L',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.of(context).textSecondary),
                ),
                Text(
                  DateFormat('hh:mm a').format(entry.date),
                  style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 16, color: AppColors.of(context).border),
          ],
        ),
      ),
    );
  }

  double _getDayDistance(List<dynamic> dayEntries, BikeProvider provider) {
    final odoEntries = dayEntries.whereType<OdometerEntry>().toList();
    if (odoEntries.isEmpty) return 0;

    final readings = odoEntries.map((e) => e.reading).toList();
    final dayMax = readings.reduce((a, b) => a > b ? a : b);
    final dayMin = readings.reduce((a, b) => a < b ? a : b);

    if (dayMax == dayMin) {
      // Single reading — compare with previous day's latest
      final date = odoEntries.first.date;
      final dayStart = DateTime(date.year, date.month, date.day);
      final prevEntries = provider.odometerEntries
          .where((e) => e.date.isBefore(dayStart))
          .toList();
      if (prevEntries.isEmpty) return 0;
      final prevMax = prevEntries.map((e) => e.reading).reduce((a, b) => a > b ? a : b);
      return dayMax - prevMax;
    }
    return dayMax - dayMin;
  }

  void _editOdometerEntry(BuildContext context, OdometerEntry entry) {
    final provider = context.read<BikeProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: AddOdometerSheet(entry: entry),
      ),
    );
  }

  void _editFuelEntry(BuildContext context, FuelEntry entry) {
    final provider = context.read<BikeProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: AddFuelSheet(entry: entry),
      ),
    );
  }

  Widget _buildMaintenanceTile(BuildContext context, MaintenanceEntry entry, BikeProvider provider) {
    const categoryColors = <String, Color>{
      'General Service': Color(0xFF7B1FA2),
      'Air Checkup': Color(0xFF00897B),
      'Washing': Color(0xFF0288D1),
      'Other': Color(0xFF8D6E63),
    };
    const categoryIcons = <String, IconData>{
      'General Service': Icons.build,
      'Air Checkup': Icons.tire_repair,
      'Washing': Icons.water,
      'Other': Icons.more_horiz,
    };

    final color = categoryColors[entry.category] ?? const Color(0xFF757575);
    final icon = categoryIcons[entry.category] ?? Icons.build;

    return Dismissible(
      key: Key('maint_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) => _confirmDelete(context, 'maintenance entry'),
      onDismissed: (_) => provider.deleteMaintenanceEntry(entry.id!),
      child: ListTile(
        onTap: () => _editMaintenanceEntry(context, entry),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          '${entry.category}  •  ₹${entry.cost.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          entry.note ?? 'Maintenance',
          style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('hh:mm a').format(entry.date),
              style: TextStyle(fontSize: 12, color: AppColors.of(context).textHint),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 16, color: AppColors.of(context).border),
          ],
        ),
      ),
    );
  }

  void _editMaintenanceEntry(BuildContext context, MaintenanceEntry entry) {
    final provider = context.read<BikeProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: AddMaintenanceSheet(entry: entry),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String type) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${type[0].toUpperCase()}${type.substring(1)}'),
        content: Text('Are you sure you want to delete this $type?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  static int _animBatch = 0;

  static void resetAnimation() => _animBatch++;

  const _AnimatedListItem({super.key, required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // First 6 items get staggered delay, rest animate immediately
    final delay = widget.index < 6 ? widget.index * 80 : 0;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
        child: widget.child,
      ),
    );
  }
}
