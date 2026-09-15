import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/bike_provider.dart';
import 'screens/home_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/add_odometer_sheet.dart';
import 'widgets/add_fuel_sheet.dart';
import 'widgets/add_maintenance_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BikeProvider()..loadData(),
      child: MaterialApp(
        title: 'RideLog',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF1B5E20),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            titleTextStyle: TextStyle(
              color: Color(0xFF1B1B1B),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: IconThemeData(color: Color(0xFF1B1B1B)),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFF1B5E20),
            unselectedItemColor: Color(0xFF9E9E9E),
            type: BottomNavigationBarType.fixed,
            elevation: 8,
            selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 12),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF4CAF50),
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            surfaceTintColor: Color(0xFF1E1E1E),
            elevation: 0,
            scrolledUnderElevation: 1,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1E1E1E),
            selectedItemColor: Color(0xFF4CAF50),
            unselectedItemColor: Color(0xFF757575),
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),
          cardColor: const Color(0xFF1E1E1E),
        ),
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _locked = false;
  bool _authenticating = false;
  bool _wasInBackground = false;
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _checkLockOnStart();
    }
  }

  Future<void> _checkLockOnStart() async {
    if (_authenticating) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('fingerprint_enabled') ?? false;
    if (!enabled || !_locked && !_wasInBackground && prefs.getBool('fingerprint_enabled') == null) return;
    if (!enabled) return;

    setState(() => _locked = true);
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: ' ',
        options: const AuthenticationOptions(biometricOnly: true),
        authMessages: [
          const AndroidAuthMessages(
            biometricHint: '',
            biometricNotRecognized: 'Try again',
            biometricRequiredTitle: 'Unlock',
            biometricSuccess: 'Done',
            cancelButton: 'Cancel',
            deviceCredentialsRequiredTitle: 'Unlock',
            deviceCredentialsSetupDescription: '',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: '',
            signInTitle: 'Unlock',
          ),
        ],
      );
      if (authenticated && mounted) {
        setState(() => _locked = false);
      }
    } catch (_) {
      // Auth failed or cancelled — stay locked
    } finally {
      _authenticating = false;
    }
  }

  void _switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B5E20),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/icon.png', width: 80, height: 80),
                    ),
                    const SizedBox(height: 16),
                    const Text('RideLog', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: IconButton(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, size: 56, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    final screens = [
      HomeScreen(onViewAllHistory: () => _switchToTab(2)),
      const AnalyticsScreen(),
      const HistoryScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Exit RideLog?'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit')),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentIndex == 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/icon.png', width: 32, height: 32),
              ),
              const SizedBox(width: 10),
            ],
            Text(['RideLog', 'Analytics', 'History'][_currentIndex]),
          ],
        ),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              tooltip: 'Settings',
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.two_wheeler, size: 26, color: Color(0xFF1B5E20)),
            ),
          ],
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _switchToTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryOptions(context),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    ),
    );
  }

  void _showAddEntryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Text('New Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildEntryOption(
                  icon: Icons.speed, label: 'Odometer\nReading', color: const Color(0xFF2196F3),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 250));
                    if (mounted) _showOdometerSheet(context);
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildEntryOption(
                  icon: Icons.local_gas_station, label: 'Fuel\nEntry', color: const Color(0xFFFF6D00),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 250));
                    if (mounted) _showFuelSheet(context);
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildEntryOption(
                  icon: Icons.build, label: 'Maintenance', color: const Color(0xFF7B1FA2),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 250));
                    if (mounted) _showMaintenanceSheet(context);
                  },
                )),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryOption({
    required IconData icon, required String label, required Color color, required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.3)),
          ],
        ),
      ),
    );
  }

  void _showOdometerSheet(BuildContext context) {
    final provider = context.read<BikeProvider>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(value: provider, child: const AddOdometerSheet()),
    );
  }

  void _showFuelSheet(BuildContext context) {
    final provider = context.read<BikeProvider>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(value: provider, child: const AddFuelSheet()),
    );
  }

  void _showMaintenanceSheet(BuildContext context) {
    final provider = context.read<BikeProvider>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(value: provider, child: const AddMaintenanceSheet()),
    );
  }
}
