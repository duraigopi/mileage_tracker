import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/bike_provider.dart';
import '../utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _fingerprintEnabled = false;
  bool _biometricAvailable = false;
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricAvailable = canAuth;
      _fingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;
    });
  }

  Future<void> _toggleFingerprint(bool value) async {
    if (value) {
      // Verify fingerprint before enabling
      final authenticated = await _auth.authenticate(
        localizedReason: ' ',
        options: const AuthenticationOptions(biometricOnly: true),
        authMessages: [
          const AndroidAuthMessages(
            biometricHint: '',
            biometricNotRecognized: 'Try again',
            biometricRequiredTitle: 'Enable Fingerprint Lock',
            biometricSuccess: 'Done',
            cancelButton: 'Cancel',
            signInTitle: 'Enable Fingerprint Lock',
          ),
        ],
      );
      if (!authenticated) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fingerprint_enabled', value);
    setState(() => _fingerprintEnabled = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Fingerprint lock enabled' : 'Fingerprint lock disabled'),
          backgroundColor: const Color(0xFF388E3C),
        ),
      );
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Export Data'),
        content: const Text('Export all odometer, fuel, and maintenance data as a CSV file?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Export')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<BikeProvider>();
    try {
      final path = await provider.exportToCsv();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Export ready'),
          backgroundColor: const Color(0xFF388E3C),
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () => Share.shareXFiles([XFile(path)], text: 'RideLog Data'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Security section
          Text('Security', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textTertiary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: c.cardShadow,
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fingerprint, color: Color(0xFF1B5E20), size: 24),
                  ),
                  title: const Text('Fingerprint Lock', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _biometricAvailable
                        ? 'Require fingerprint to open app'
                        : 'Biometric not available on this device',
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
                  trailing: Switch(
                    value: _fingerprintEnabled,
                    onChanged: _biometricAvailable ? _toggleFingerprint : null,
                    activeColor: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data section
          Text('Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textTertiary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: c.cardShadow,
            ),
            child: ListTile(
              onTap: () => _exportData(context),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.file_download_outlined, color: Color(0xFFFF6D00), size: 24),
              ),
              title: const Text('Export Data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Export all data as CSV', style: TextStyle(fontSize: 12, color: c.textTertiary)),
              trailing: Icon(Icons.chevron_right, color: c.textHint),
            ),
          ),

          const SizedBox(height: 24),

          // App info
          Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textTertiary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: c.cardShadow,
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 24),
                  ),
                  title: const Text('RideLog', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Version 2.0.0', style: TextStyle(fontSize: 12, color: c.textTertiary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
