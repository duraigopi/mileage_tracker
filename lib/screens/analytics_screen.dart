import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/bike_provider.dart';
import '../models/fuel_entry.dart';
import '../utils/app_colors.dart';
import '../widgets/tile_card.dart';
import '../widgets/scroll_animated.dart';
import '../widgets/animated_number.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedTab = 0; // 0 = Distance, 1 = Fuel, 2 = Expenses
  int _periodType = 1; // 0 = Week, 1 = Month
  late DateTime _currentPeriodStart;
  final _scrollAnimKeys = <GlobalKey<ScrollAnimatedState>>[];
  bool _chartAnimating = true;

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
    void visitAll(Element element) {
      if (element is StatefulElement && element.state is AnimatedNumberState) {
        (element.state as AnimatedNumberState).checkVisibility();
      }
      element.visitChildren(visitAll);
    }
    context.visitChildElements(visitAll);
  }

  @override
  void initState() {
    super.initState();
    _setCurrentPeriod();
    _triggerChartAnimation();
  }

  void _setCurrentPeriod() {
    final now = DateTime.now();
    if (_periodType == 0) {
      // Week: Monday to Sunday
      _currentPeriodStart = now.subtract(Duration(days: now.weekday - 1));
    } else {
      // Month: 1st of current month
      _currentPeriodStart = DateTime(now.year, now.month, 1);
    }
    _currentPeriodStart = DateTime(_currentPeriodStart.year, _currentPeriodStart.month, _currentPeriodStart.day);
  }

  DateTime get _periodEnd {
    if (_periodType == 0) {
      return _currentPeriodStart.add(const Duration(days: 6));
    } else {
      return DateTime(_currentPeriodStart.year, _currentPeriodStart.month + 1, 0);
    }
  }

  String get _periodLabel {
    if (_periodType == 0) {
      final end = _periodEnd;
      return '${DateFormat('MMM dd').format(_currentPeriodStart)} - ${DateFormat('MMM dd').format(end)}';
    } else {
      return DateFormat('MMMM yyyy').format(_currentPeriodStart);
    }
  }

  void _triggerChartAnimation() {
    setState(() => _chartAnimating = true);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _chartAnimating = false);
    });
  }

  void _previousPeriod() {
    setState(() {
      if (_periodType == 0) {
        _currentPeriodStart = _currentPeriodStart.subtract(const Duration(days: 7));
      } else {
        _currentPeriodStart = DateTime(_currentPeriodStart.year, _currentPeriodStart.month - 1, 1);
      }
    });
    _triggerChartAnimation();
  }

  void _nextPeriod() {
    final next = _periodType == 0
        ? _currentPeriodStart.add(const Duration(days: 7))
        : DateTime(_currentPeriodStart.year, _currentPeriodStart.month + 1, 1);
    if (!next.isAfter(DateTime.now())) {
      setState(() => _currentPeriodStart = next);
      _triggerChartAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BikeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (_) { _onScroll(); return false; },
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
              // Service reminder
              if (provider.isServiceDue)
                _animated(0, _buildServiceBanner(provider)),

              // Period selector
              _animated(1, _buildPeriodSelector()),
              const SizedBox(height: 16),

              // Tab selector
              _animated(2, _buildTabSelector()),
              const SizedBox(height: 20),

              // Chart
              _animated(3, _buildChart(provider)),
              const SizedBox(height: 24),

              // Summary
              _animated(4, _buildSummaryCard(provider)),
              const SizedBox(height: 24),

              // Details
              _animated(5, _buildDetailsCard(provider)),

              // Insights (distance tab)
              if (_selectedTab == 0) ...[
                const SizedBox(height: 24),
                _animated(6, _buildInsightsCard(provider)),
              ],

              // Fuel history (only on fuel tab)
              if (_selectedTab == 1 && provider.fuelEntries.isNotEmpty) ...[
                const SizedBox(height: 24),
                _animated(6, Text('Fuel Fill-up History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary))),
                const SizedBox(height: 12),
                _animated(7, _buildFuelHistoryList(provider)),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- Period Selector ---

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Week / Month toggle
          Row(
            children: [
              _buildPeriodToggle('Week', 0),
              _buildPeriodToggle('Month', 1),
            ],
          ),
          const SizedBox(height: 8),
          // Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousPeriod,
                color: AppColors.of(context).textSecondary,
              ),
              Text(
                _periodLabel,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextPeriod,
                color: AppColors.of(context).textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle(String label, int index) {
    final isSelected = _periodType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _periodType = index;
            _setCurrentPeriod();
          });
          _triggerChartAnimation();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF388E3C) : const Color(0xFF1B5E20))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.of(context).textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  // --- Tab Selector ---

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTab('Distance', 0),
          _buildTab('Fuel', 1),
          _buildTab('Expenses', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _selectedTab = index); _triggerChartAnimation(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.of(context).card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20))
                  : AppColors.of(context).textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  // --- Charts ---

  Widget _buildChart(BikeProvider provider) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: _selectedTab == 0
          ? _buildDistanceChart(provider)
          : _selectedTab == 1
              ? _buildMileageChart(provider)
              : _buildExpensesChart(provider),
    );
  }

  Widget _buildDistanceChart(BikeProvider provider) {
    final dailyDistances = provider.getDailyDistancesForRange(_currentPeriodStart, _periodEnd);
    final entries = dailyDistances.entries.toList();

    if (entries.every((e) => e.value == 0)) {
      return const Center(
        child: Text('No ride data for this period.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    final maxY = entries.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    final barWidth = _periodType == 0 ? 24.0 : 8.0;

    return BarChart(
      swapAnimationDuration: const Duration(milliseconds: 800),
      swapAnimationCurve: Curves.easeOutCubic,
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _chartAnimating ? 1 : maxY * 1.3,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = entries[group.x.toInt()].key;
              return BarTooltipItem(
                '${DateFormat('MMM dd').format(date)}\n${rod.toY.toStringAsFixed(1)} km',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox();
                if (_periodType == 1 && idx % 5 != 0 && idx != entries.length - 1) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _periodType == 0
                        ? DateFormat('E').format(entries[idx].key)
                        : DateFormat('dd').format(entries[idx].key),
                    style: TextStyle(fontSize: 10, color: AppColors.of(context).textTertiary),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(fontSize: 10, color: AppColors.of(context).textHint),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 10,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.of(context).divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: _chartAnimating ? 0 : e.value.value,
                color: const Color(0xFF388E3C),
                width: barWidth,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMileageChart(BikeProvider provider) {
    final mileage = provider.getMileageForRange(_currentPeriodStart, _periodEnd);
    final distance = provider.getDistanceForRange(_currentPeriodStart, _periodEnd);
    final liters = provider.getLitersForRange(_currentPeriodStart, _periodEnd);
    final overallMileage = provider.averageMileage;

    if (liters <= 0 || distance <= 0) {
      return const Center(
        child: Text('No fuel data for this period.\nAdd fuel entries to see mileage.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_periodType == 0 ? "Week" : "Month"} Mileage',
          style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedNumber(
              key: ValueKey('big_mileage_$mileage'),
              value: mileage!,
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Color(0xFFFF6D00)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text(' km/l', style: TextStyle(fontSize: 14, color: Color(0xFFFF6D00), fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        Text(
          '${distance.toStringAsFixed(1)} km ÷ ${liters.toStringAsFixed(2)} L',
          style: TextStyle(fontSize: 10, color: AppColors.of(context).textHint),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _animMileageStat('Distance', distance, ' km', const Color(0xFF1B5E20)),
            Container(width: 1, height: 24, color: AppColors.of(context).border, margin: const EdgeInsets.symmetric(horizontal: 12)),
            _animMileageStat('Fuel', liters, ' L', const Color(0xFF0288D1), decimals: 2),
            if (overallMileage != null) ...[
              Container(width: 1, height: 24, color: AppColors.of(context).border, margin: const EdgeInsets.symmetric(horizontal: 12)),
              _animMileageStat('Overall', overallMileage, ' km/l', const Color(0xFF2196F3)),
            ],
          ],
        ),
        if (overallMileage != null) ...[
          const SizedBox(height: 8),
          Text(
            'Overall: ${provider.totalDistance.toStringAsFixed(1)} km ÷ ${provider.totalLiters.toStringAsFixed(2)} L',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.of(context).textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _animMileageStat(String label, double value, String suffix, Color color, {int decimals = 1}) {
    return Column(
      children: [
        AnimatedNumber(key: ValueKey('mileage_${label}_$value'), value: value, suffix: suffix, decimals: decimals,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.of(context).textTertiary)),
      ],
    );
  }

  Widget _buildExpensesChart(BikeProvider provider) {
    final fuelSpent = provider.getFuelSpentForRange(_currentPeriodStart, _periodEnd);
    final maintSpent = provider.getMaintenanceSpentForRange(_currentPeriodStart, _periodEnd);
    final total = fuelSpent + maintSpent;

    if (total == 0) {
      return const Center(
        child: Text('No expenses for this period.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 180,
            child: PieChart(
              swapAnimationDuration: const Duration(milliseconds: 800),
              swapAnimationCurve: Curves.easeOutCubic,
              PieChartData(
                sectionsSpace: _chartAnimating ? 0 : 3,
                centerSpaceRadius: _chartAnimating ? 80 : 45,
                sections: [
                  if (fuelSpent > 0)
                    PieChartSectionData(
                      value: fuelSpent,
                      color: const Color(0xFFFF6D00),
                      radius: _chartAnimating ? 0 : 40,
                      title: '${(fuelSpent / total * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (maintSpent > 0)
                    PieChartSectionData(
                      value: maintSpent < total * 0.05 ? total * 0.05 : maintSpent,
                      color: const Color(0xFF9C27B0),
                      radius: _chartAnimating ? 0 : 40,
                      title: '${(maintSpent / total * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendItem('Fuel', fuelSpent, const Color(0xFFFF6D00)),
            const SizedBox(height: 12),
            _buildLegendItem('Maintenance', maintSpent, const Color(0xFF7B1FA2)),
            const SizedBox(height: 16),
            Text('Total', style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary)),
            AnimatedNumber(key: ValueKey('exp_total_$total'), value: total, prefix: '₹', decimals: 0, useCommas: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary)),
            AnimatedNumber(key: ValueKey('legend_${label}_$value'), value: value, prefix: '₹', decimals: 0, useCommas: true,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ],
    );
  }

  // --- Summary Card ---

  Widget _buildSummaryCard(BikeProvider provider) {
    if (_selectedTab == 0) return _buildDistanceSummary(provider);
    if (_selectedTab == 1) return _buildFuelSummary(provider);
    return _buildExpensesSummary(provider);
  }

  Widget _buildDistanceSummary(BikeProvider provider) {
    final distance = provider.getDistanceForRange(_currentPeriodStart, _periodEnd);
    final dailyDistances = provider.getDailyDistancesForRange(_currentPeriodStart, _periodEnd);
    final activeDays = dailyDistances.values.where((v) => v > 0).length;
    final nonZero = dailyDistances.values.where((v) => v > 0).toList();
    final avgDaily = nonZero.isNotEmpty ? nonZero.reduce((a, b) => a + b) / nonZero.length : 0.0;

    return _buildCard('Ride Summary', [
      _animSummaryRow('Total Distance', distance, ' km', const Color(0xFF1B5E20)),
      _animSummaryRow('Active Days', activeDays.toDouble(), '', const Color(0xFF2196F3), decimals: 0),
      _animSummaryRow('Daily Average', avgDaily, ' km', const Color(0xFF7C4DFF)),
    ]);
  }

  Widget _buildFuelSummary(BikeProvider provider) {
    final fuelSpent = provider.getFuelSpentForRange(_currentPeriodStart, _periodEnd);
    final liters = provider.getLitersForRange(_currentPeriodStart, _periodEnd);
    final fillUps = provider.getFuelCountForRange(_currentPeriodStart, _periodEnd);

    final periodMileage = provider.getMileageForRange(_currentPeriodStart, _periodEnd);
    final distance = provider.getDistanceForRange(_currentPeriodStart, _periodEnd);

    return _buildCard('Fuel Summary', [
      _animSummaryRow('Total Spent', fuelSpent, '', const Color(0xFFD32F2F), prefix: '₹', decimals: 0),
      _animSummaryRow('Total Fuel', liters, ' L', const Color(0xFF00897B), decimals: 2),
      _animSummaryRow('Distance', distance, ' km', const Color(0xFF1B5E20)),
      _animSummaryRow('Fill-ups', fillUps.toDouble(), '', const Color(0xFF7C4DFF), decimals: 0),
      _buildDivider(),
      _animSummaryRow(
        '${_periodType == 0 ? "Week" : "Month"} Mileage',
        periodMileage ?? 0,
        ' km/l',
        const Color(0xFFFF6D00),
      ),
      if (periodMileage != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${distance.toStringAsFixed(1)} km ÷ ${liters.toStringAsFixed(2)} L',
            style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
          ),
        ),
      _buildDivider(),
      // Overall mileage: total distance all time / total liters all time
      _animSummaryRow('Overall Mileage', provider.averageMileage ?? 0, ' km/l', const Color(0xFF2196F3)),
      if (provider.averageMileage != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${provider.totalDistance.toStringAsFixed(1)} km ÷ ${provider.totalLiters.toStringAsFixed(2)} L',
            style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint),
          ),
        ),
      const SizedBox(height: 8),
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
    ]);
  }

  Widget _buildExpensesSummary(BikeProvider provider) {
    final fuelSpent = provider.getFuelSpentForRange(_currentPeriodStart, _periodEnd);
    final maintSpent = provider.getMaintenanceSpentForRange(_currentPeriodStart, _periodEnd);
    final total = fuelSpent + maintSpent;
    final distance = provider.getDistanceForRange(_currentPeriodStart, _periodEnd);
    final costPerKm = distance > 0 ? total / distance : 0.0;

    return _buildCard('Expense Summary', [
      _animSummaryRow('Fuel', fuelSpent, '', const Color(0xFFFF6D00), prefix: '₹', decimals: 0),
      _animSummaryRow('Maintenance', maintSpent, '', const Color(0xFF7B1FA2), prefix: '₹', decimals: 0),
      _buildDivider(),
      _animSummaryRow('Total', total, '', const Color(0xFFD32F2F), prefix: '₹', decimals: 0),
      if (distance > 0)
        _animSummaryRow('Cost / km', costPerKm, '', const Color(0xFFE65100), prefix: '₹', decimals: 2),
    ]);
  }

  // --- Details Card ---

  Widget _buildDetailsCard(BikeProvider provider) {
    if (_selectedTab == 0) {
      // Compare with previous period
      late DateTime prevStart, prevEnd;
      if (_periodType == 0) {
        prevStart = _currentPeriodStart.subtract(const Duration(days: 7));
        prevEnd = _currentPeriodStart.subtract(const Duration(days: 1));
      } else {
        prevStart = DateTime(_currentPeriodStart.year, _currentPeriodStart.month - 1, 1);
        prevEnd = _currentPeriodStart.subtract(const Duration(days: 1));
      }
      final currentDist = provider.getDistanceForRange(_currentPeriodStart, _periodEnd);
      final prevDist = provider.getDistanceForRange(prevStart, prevEnd);
      final diff = currentDist - prevDist;
      final diffPercent = prevDist > 0 ? (diff / prevDist * 100) : 0.0;

      return _buildCard('Compare', [
        _buildCompareRow(
          _periodType == 0 ? 'vs. Previous Week' : 'vs. Previous Month',
          currentDist,
          prevDist,
          diff,
          diffPercent,
        ),
      ]);
    }
    if (_selectedTab == 1) {
      return _buildCard('Efficiency Insight', [
        _animSummaryRow('Cost per Km', provider.costPerKm ?? 0, '', const Color(0xFFE65100), prefix: '₹', decimals: 2),
        _animSummaryRow('Total Fuel (all time)', provider.totalFuelSpent, '', const Color(0xFFD32F2F), prefix: '₹', decimals: 0),
        _animSummaryRow('Total Litres (all time)', provider.totalLiters, ' L', const Color(0xFF00897B)),
      ]);
    }
    // Expenses: all-time totals
    return _buildCard('All Time', [
      _animSummaryRow('Fuel', provider.totalFuelSpent, '', const Color(0xFFFF6D00), prefix: '₹', decimals: 0),
      _animSummaryRow('Maintenance', provider.totalMaintenanceCost, '', const Color(0xFF7B1FA2), prefix: '₹', decimals: 0),
      _buildDivider(),
      _animSummaryRow('Grand Total', provider.totalFuelSpent + provider.totalMaintenanceCost, '', const Color(0xFFD32F2F), prefix: '₹', decimals: 0),
    ]);
  }

  // --- Shared Widgets ---

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary)),
          const SizedBox(height: 16),
          ...children.expand((w) => [w, const SizedBox(height: 10)]).toList()..removeLast(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.of(context).textSecondary)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _animSummaryRow(String label, double value, String suffix, Color color, {String prefix = '', int decimals = 1}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.of(context).textSecondary)),
        AnimatedNumber(
          key: ValueKey('${_selectedTab}_${_periodType}_${label}_$value'),
          value: value,
          prefix: prefix,
          suffix: suffix,
          decimals: decimals,
          useCommas: true,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildDivider() => Divider(height: 4, color: AppColors.of(context).divider);

  Widget _buildCompareRow(String label, double current, double previous, double diff, double diffPercent) {
    final isUp = diff >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.of(context).textTertiary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current', style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary)),
                  AnimatedNumber(key: ValueKey('cmp_cur_$current'), value: current, suffix: ' km',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Previous', style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary)),
                  AnimatedNumber(key: ValueKey('cmp_prev_$previous'), value: previous, suffix: ' km',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.of(context).textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isUp ? Colors.green : Colors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14, color: isUp ? Colors.green : Colors.red),
                  const SizedBox(width: 2),
                  AnimatedNumber(key: ValueKey('cmp_pct_$diffPercent'), value: diffPercent.abs(), suffix: '%', decimals: 0,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: isUp ? Colors.green : Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceBanner(BikeProvider provider) {
    final days = provider.daysSinceLastService;
    final km = provider.kmSinceLastService;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC02)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Service due — ${[
                if (days != null) '${days}d ago',
                if (km != null) '${km.toStringAsFixed(0)} km',
              ].join(' • ')}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Insights ---

  Widget _buildInsightsCard(BikeProvider provider) {
    final bestDay = provider.getBestDay(_currentPeriodStart, _periodEnd);
    final ridingDays = provider.getRidingDaysForRange(_currentPeriodStart, _periodEnd);
    final totalDays = _periodEnd.difference(_currentPeriodStart).inDays + 1;
    final currentStreak = provider.currentStreak;
    final longestStreak = provider.longestStreak;
    return _buildCard('Insights', [
      // Best day
      if (bestDay != null)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF388E3C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events, color: Color(0xFF388E3C), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Best Day', style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary)),
                  Row(
                    children: [
                      AnimatedNumber(key: ValueKey('best_${bestDay.value}'), value: bestDay.value, suffix: ' km', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF388E3C))),
                      Text(' on ${DateFormat('MMM dd').format(bestDay.key)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF388E3C))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

      // Riding days
      _buildSummaryRow(
        'Riding Days',
        '$ridingDays / $totalDays days',
        const Color(0xFF2196F3),
      ),

      // Streaks
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Streak', style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary)),
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 18, color: currentStreak > 0 ? const Color(0xFFFF6D00) : AppColors.of(context).border),
                    const SizedBox(width: 4),
                    AnimatedNumber(
                      key: ValueKey('streak_cur_$currentStreak'),
                      value: currentStreak.toDouble(),
                      suffix: ' days',
                      decimals: 0,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: currentStreak > 0 ? const Color(0xFFFF6D00) : AppColors.of(context).textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Longest Streak', style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary)),
                Row(
                  children: [
                    const Icon(Icons.military_tech, size: 18, color: Color(0xFFFFA000)),
                    const SizedBox(width: 4),
                    AnimatedNumber(
                      key: ValueKey('streak_long_$longestStreak'),
                      value: longestStreak.toDouble(),
                      suffix: ' days',
                      decimals: 0,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFFFA000)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),

      // Avg fuel price
      if (provider.avgFuelPrice != null)
        _animSummaryRow('Avg Fuel Price', provider.avgFuelPrice!, '/L', const Color(0xFFE65100), prefix: '₹', decimals: 2),

      // Total expenses
      if (provider.totalExpenses > 0)
        _animSummaryRow('Total Expenses', provider.totalExpenses, '', const Color(0xFFD32F2F), prefix: '₹', decimals: 0),
    ]);
  }

  // --- Fuel History ---

  Widget _buildFuelHistoryList(BikeProvider provider) {
    final entries = provider.fuelEntries;

    return TileCard(
      color: Theme.of(context).cardColor,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.of(context).divider),
        itemBuilder: (context, index) => _buildFuelHistoryTile(entries[index]),
      ),
    );
  }

  Widget _buildFuelHistoryTile(FuelEntry entry) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.local_gas_station, color: Color(0xFFFF6D00), size: 22),
      ),
      title: Text('${entry.liters.toStringAsFixed(2)} L  •  ₹${entry.totalCost.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
          '₹${entry.pricePerLiter.toStringAsFixed(1)}/L  •  at ${NumberFormat('#,##0').format(entry.odometerReading)} km',
          style: TextStyle(fontSize: 12, color: AppColors.of(context).textTertiary)),
      trailing: Text(DateFormat('MMM dd').format(entry.date),
          style: TextStyle(fontSize: 12, color: AppColors.of(context).textHint)),
    );
  }
}
