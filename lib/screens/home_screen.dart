import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bike_provider.dart';
import '../models/odometer_entry.dart';
import '../models/fuel_entry.dart';
import '../models/maintenance_entry.dart';
import '../utils/app_colors.dart';
import '../widgets/tile_card.dart';
import '../utils/entry_date.dart';
import '../widgets/scroll_animated.dart';
import '../widgets/animated_number.dart';
import '../widgets/add_odometer_sheet.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onViewAllHistory;
  const HomeScreen({super.key, this.onViewAllHistory});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollAnimKeys = <GlobalKey<ScrollAnimatedState>>[];

  GlobalKey<ScrollAnimatedState> _getKey(int index) {
    while (_scrollAnimKeys.length <= index) {
      _scrollAnimKeys.add(GlobalKey<ScrollAnimatedState>());
    }
    return _scrollAnimKeys[index];
  }

  Widget _animated(int index, Widget child) {
    return ScrollAnimated(
      key: _getKey(index),
      delay: Duration(milliseconds: index * 80),
      child: child,
    );
  }

  void _onScroll() {
    for (final key in _scrollAnimKeys) {
      key.currentState?.checkVisibility();
    }
    // Trigger all animated widgets visibility checks
    void visitAll(Element element) {
      if (element is StatefulElement) {
        final state = element.state;
        if (state is AnimatedNumberState) {
          state.checkVisibility();
        } else if (state is _AnimatedProgressBarState) {
          state.checkVisibility();
        }
      }
      element.visitChildren(visitAll);
    }
    context.visitChildElements(visitAll);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BikeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SizedBox.shrink();
        }

        if (provider.odometerEntries.isEmpty && provider.fuelEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.two_wheeler, size: 72, color: AppColors.of(context).border),
                const SizedBox(height: 16),
                Text('Welcome to Bike Tracker',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.of(context).textSecondary)),
                const SizedBox(height: 8),
                Text('Tap + to add your first odometer reading',
                    style: TextStyle(fontSize: 14, color: AppColors.of(context).textHint)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadData(),
          color: const Color(0xFF1B5E20),
          child: NotificationListener<ScrollNotification>(
          onNotification: (_) { _onScroll(); return false; },
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
              // Current Odometer Card
              _animated(0, _buildOdometerCard(provider)),
              const SizedBox(height: 16),

              // Today's Summary Card
              _animated(1, _buildTodaySummaryCard(provider)),

              // Distance Stats Grid
              _animated(2, Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Ride Distance'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnimatedStatCard('Today', provider.todayDistance, 'km', Icons.today, const Color(0xFF2196F3)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAnimatedStatCard('This Week', provider.weekDistance, 'km', Icons.date_range, const Color(0xFF7C4DFF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnimatedStatCard('This Month', provider.monthDistance, 'km', Icons.calendar_month, const Color(0xFF00897B)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAnimatedStatCard('Total', provider.totalDistance, 'km', Icons.route, const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ],
              )),
              const SizedBox(height: 24),

              // Fuel Efficiency Section
              _animated(3, Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Fuel Efficiency'),
                  const SizedBox(height: 12),
                  _buildFuelCard(provider),
                ],
              )),
              const SizedBox(height: 24),

              // Fuel Cost Summary
              _animated(4, Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Fuel Costs'),
                  const SizedBox(height: 12),
                  _buildCostCard(provider),
                ],
              )),

              // Maintenance Summary
              if (provider.maintenanceEntries.isNotEmpty) ...[
                const SizedBox(height: 24),
                _animated(5, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Maintenance'),
                    const SizedBox(height: 12),
                    _buildMaintenanceCard(provider),
                  ],
                )),
              ],

              // Service Reminder
              if (provider.isServiceDue) ...[
                const SizedBox(height: 24),
                _animated(6, _buildServiceReminder(provider)),
              ],

              // Monthly Spending Chart
              const SizedBox(height: 24),
              _animated(7, Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Monthly Spending'),
                  const SizedBox(height: 12),
                  _buildMonthlySpendingChart(provider),
                ],
              )),
              const SizedBox(height: 24),

              // Recent Entries
              if (provider.allEntriesSorted.isNotEmpty) ...[
                _animated(8, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Recent Entries'),
                        if (widget.onViewAllHistory != null)
                          TextButton(
                            onPressed: widget.onViewAllHistory,
                            child: const Text('View All', style: TextStyle(fontSize: 13, color: Color(0xFF1B5E20))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecentEntries(provider),
                  ],
                )),
              ],
            ],
        ),
        ),
        );
      },
    );
  }

  Widget _buildTodaySummaryCard(BikeProvider provider) {
    final start = todayStart();
    final end = tomorrowStart();
    final todayEntries = provider.odometerEntries
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();

    if (todayEntries.isEmpty) return const SizedBox();

    todayEntries.sort((a, b) => a.date.compareTo(b.date));
    final startReading = todayEntries.first.reading;
    final endReading = todayEntries.last.reading;
    final distance = endReading - startReading;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.of(context).card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.of(context).cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Summary",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.of(context).textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTodayAnimStat('Start', startReading, Icons.play_arrow_rounded, const Color(0xFF2196F3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTodayAnimStat('End', endReading, Icons.stop_rounded, const Color(0xFFE65100)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTodayAnimStat('Distance', distance, Icons.route, const Color(0xFF1B5E20)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTodayAnimStat(String label, double value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        AnimatedNumber(
          value: value,
          suffix: ' km',
          decimals: 1,
          useCommas: true,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.of(context).textTertiary)),
      ],
    );
  }

  void _openOdometerSheet(BikeProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const AddOdometerSheet(),
      ),
    );
  }

  Widget _buildAnimatedStatCard(String title, double value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.of(context).cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          AnimatedNumber(
            value: value,
            suffix: ' $unit',
            decimals: 1,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: AppColors.of(context).textTertiary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.of(context).textPrimary,
      ),
    );
  }

  Widget _buildOdometerCard(BikeProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Current Odometer',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  provider.odometerEntries.isNotEmpty
                      ? DateFormat('MMM dd').format(provider.odometerEntries.first.date)
                      : '--',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openOdometerSheet(provider),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedNumber(
                value: provider.currentOdometer,
                decimals: 1,
                useCommas: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  'km',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (provider.todayDistance > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 4),
                AnimatedNumber(
                  value: provider.todayDistance,
                  suffix: ' km today',
                  decimals: 1,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFuelCard(BikeProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.of(context).cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildAnimFuelStat('This Month', provider.currentMonthMileage ?? 0, ' km/l', Icons.local_gas_station, const Color(0xFFFF6D00)),
              const SizedBox(width: 20),
              _buildAnimFuelStat('Overall', provider.averageMileage ?? 0, ' km/l', Icons.analytics, const Color(0xFF2196F3)),
            ],
          ),
          const Divider(height: 32),
          () {
            final now = DateTime.now();
            final monthStart = DateTime(now.year, now.month, 1);
            final monthFuel = provider.getLitersForRange(monthStart, now);
            final monthFillUps = provider.getFuelCountForRange(monthStart, now).toDouble();
            return Column(
              children: [
                Row(
                  children: [
                    _buildAnimFuelStat('This Month', monthFuel, ' L', Icons.water_drop, const Color(0xFF00897B)),
                    const SizedBox(width: 20),
                    _buildAnimFuelStat('Total Fuel', provider.totalLiters, ' L', Icons.water_drop, const Color(0xFF0288D1)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildAnimFuelStat('This Month', monthFillUps, ' fill-ups', Icons.ev_station, const Color(0xFF7C4DFF), decimals: 0),
                    const SizedBox(width: 20),
                    _buildAnimFuelStat('Total', provider.fuelEntries.length.toDouble(), ' fill-ups', Icons.ev_station, const Color(0xFF8D6E63), decimals: 0),
                  ],
                ),
              ],
            );
          }(),
          if (provider.fuelEntries.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.of(context).textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mileage is accurate only if all fuel fill-ups are logged',
                    style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimFuelStat(String label, double value, String suffix, IconData icon, Color color, {String prefix = '', int decimals = 1}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedNumber(
                  value: value,
                  prefix: prefix,
                  suffix: suffix,
                  decimals: decimals,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.of(context).textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostCard(BikeProvider provider) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthSpent = provider.getFuelSpentForRange(monthStart, now);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.of(context).cardShadow,
      ),
      child: Column(
        children: [
          _buildAnimatedCostRow('This Month', monthSpent, '₹', 0, const Color(0xFFFF6D00), Icons.calendar_month),
          const SizedBox(height: 16),
          _buildAnimatedCostRow('Total Fuel Spent', provider.totalFuelSpent, '₹', 0, const Color(0xFFD32F2F), Icons.account_balance_wallet),
          const SizedBox(height: 16),
          _buildAnimatedCostRow('Cost per Km', provider.costPerKm ?? 0, '₹', 2, const Color(0xFFE65100), Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildAnimatedCostRow(String label, double value, String prefix, int decimals, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.of(context).textSecondary, fontWeight: FontWeight.w500)),
        const Spacer(),
        AnimatedNumber(
          value: value,
          prefix: prefix,
          decimals: decimals,
          useCommas: true,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildMaintenanceCard(BikeProvider provider) {
    final byCategory = provider.maintenanceCostByCategory;
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const categoryColors = <String, Color>{
      'General Service': Color(0xFF1976D2),
      'Washing': Color(0xFF0288D1),
      'Other': Color(0xFF757575),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.of(context).cardShadow,
      ),
      child: Column(
        children: [
          _buildAnimatedCostRow('Total Maintenance', provider.totalMaintenanceCost, '₹', 0, const Color(0xFF7B1FA2), Icons.build),
          if (sorted.isNotEmpty) ...[
            const Divider(height: 20),
            ...sorted.take(4).map((e) {
              final color = categoryColors[e.key] ?? const Color(0xFF757575);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(e.key, style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary)),
                    const Spacer(),
                    AnimatedNumber(
                      value: e.value,
                      prefix: '₹',
                      decimals: 0,
                      useCommas: true,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceReminder(BikeProvider provider) {
    final days = provider.daysSinceLastService;
    final km = provider.kmSinceLastService;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC02)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Service Due', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                const SizedBox(height: 4),
                Text(
                  [
                    if (days != null) '$days days ago',
                    if (km != null) '${km.toStringAsFixed(0)} km since last service',
                  ].join(' • '),
                  style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySpendingChart(BikeProvider provider) {
    final spending = provider.getMonthlySpending(months: 6);
    final maxVal = spending.values.isEmpty ? 0.0 : spending.values.reduce((a, b) => a > b ? a : b);

    if (maxVal == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.of(context).card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.of(context).cardShadow,
        ),
        child: Center(child: Text('No expenses yet', style: TextStyle(color: AppColors.of(context).textHint))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.of(context).cardShadow,
      ),
      child: Column(
        children: spending.entries.map((e) {
          final ratio = maxVal > 0 ? e.value / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text(e.key, style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary))),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _AnimatedProgressBar(
                      ratio: ratio,
                      color: e.value > 0 ? const Color(0xFFFF6D00) : AppColors.of(context).border,
                      bgColor: AppColors.of(context).divider,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 65,
                  child: AnimatedNumber(
                    value: e.value,
                    prefix: '₹',
                    decimals: 0,
                    useCommas: true,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentEntries(BikeProvider provider) {
    final recent = provider.allEntriesSorted.take(5).toList();
    return TileCard(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recent.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.of(context).divider),
        itemBuilder: (context, index) {
          final entry = recent[index];
          if (entry is OdometerEntry) {
            return _buildOdometerTile(entry);
          } else if (entry is FuelEntry) {
            return _buildFuelTile(entry);
          } else if (entry is MaintenanceEntry) {
            return _buildMaintenanceTile(entry);
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildOdometerTile(OdometerEntry entry) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.speed, color: Color(0xFF2196F3), size: 22),
      ),
      title: Text(
        '${NumberFormat('#,##0.0').format(entry.reading)} km',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        entry.note ?? 'Odometer reading',
        style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
      ),
      trailing: Text(
        DateFormat('MMM dd, hh:mm a').format(entry.date),
        style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
      ),
    );
  }

  Widget _buildFuelTile(FuelEntry entry) {
    // Find previous fuel entry for price comparison
    final provider = context.read<BikeProvider>();
    final fuelEntries = provider.fuelEntries; // sorted by date DESC
    final currentIndex = fuelEntries.indexWhere((e) => e.id == entry.id);
    Widget? priceArrow;
    if (currentIndex >= 0 && currentIndex < fuelEntries.length - 1) {
      final prevEntry = fuelEntries[currentIndex + 1];
      final diff = entry.pricePerLiter - prevEntry.pricePerLiter;
      if (diff.abs() > 0.01) {
        priceArrow = Icon(
          diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12,
          color: diff > 0 ? Colors.red.shade400 : Colors.green.shade600,
        );
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.local_gas_station, color: Color(0xFFFF6D00), size: 22),
      ),
      title: Text(
        '${entry.liters.toStringAsFixed(2)} L  •  ₹${entry.totalCost.toStringAsFixed(0)}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Row(
        children: [
          Text(
            'at ${NumberFormat('#,##0.0').format(entry.odometerReading)} km',
            style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
          ),
          if (priceArrow != null) ...[
            const SizedBox(width: 6),
            Text(
              '₹${entry.pricePerLiter.toStringAsFixed(1)}/L',
              style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
            ),
            const SizedBox(width: 2),
            priceArrow,
          ],
        ],
      ),
      trailing: Text(
        DateFormat('MMM dd, hh:mm a').format(entry.date),
        style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
      ),
    );
  }

  Widget _buildMaintenanceTile(MaintenanceEntry entry) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.build, color: Color(0xFF7B1FA2), size: 22),
      ),
      title: Text(
        '${entry.category}  •  ₹${entry.cost.toStringAsFixed(0)}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        entry.note ?? 'Maintenance',
        style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
      ),
      trailing: Text(
        DateFormat('MMM dd, hh:mm a').format(entry.date),
        style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
      ),
    );
  }
}

class _AnimatedProgressBar extends StatefulWidget {
  final double ratio;
  final Color color;
  final Color bgColor;

  const _AnimatedProgressBar({
    required this.ratio,
    required this.color,
    required this.bgColor,
  });

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.ratio)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => checkVisibility());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void checkVisibility() {
    if (_started || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final pos = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size.height;
    if (pos.dy < screen + 50) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => LinearProgressIndicator(
        value: _animation.value,
        minHeight: 16,
        backgroundColor: widget.bgColor,
        valueColor: AlwaysStoppedAnimation(widget.color),
      ),
    );
  }
}
