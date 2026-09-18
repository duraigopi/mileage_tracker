import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/bike_provider.dart';
import '../services/csv_service.dart';
import '../utils/app_colors.dart';
import '../widgets/tile_card.dart';

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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF388E3C),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Saves the backup outside the app's private storage — the system dialog
  /// opens on Downloads — so the file survives an uninstall or reinstall.
  Future<void> _exportData(BuildContext context) async {
    final provider = context.read<BikeProvider>();
    if (provider.odometerEntries.isEmpty &&
        provider.fuelEntries.isEmpty &&
        provider.maintenanceEntries.isEmpty) {
      _showMessage('There is nothing to export yet', isError: true);
      return;
    }

    try {
      final bytes = utf8.encode(provider.buildCsvContent());
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save RideLog backup',
        fileName: provider.exportFileName(),
        bytes: bytes,
      );
      if (path == null) return; // cancelled

      // On mobile the picker writes the bytes itself; on desktop it only
      // hands back the chosen path.
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(bytes);
      }

      provider.markExported();
      _showMessage('Backup saved (${provider.odometerEntries.length + provider.fuelEntries.length + provider.maintenanceEntries.length} entries)');
    } catch (e) {
      _showMessage('Export failed: $e', isError: true);
    }
  }

  /// Restores entries from a previously exported CSV.
  Future<void> _importData(BuildContext context) async {
    final provider = context.read<BikeProvider>();

    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Select a RideLog backup',
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return; // cancelled

      final file = picked.files.first;
      final String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        _showMessage('Could not read that file', isError: true);
        return;
      }

      final data = parseCsv(content);
      if (data.isEmpty) {
        _showMessage(
          data.errors.isEmpty
              ? 'No entries found in that file'
              : 'Could not read any entries (${data.errors.length} bad rows)',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      final replace = await _askImportMode(data);
      if (replace == null) return; // cancelled

      final result = await provider.importData(data, replaceExisting: replace);
      final parts = <String>['${result.added} entries imported'];
      if (result.skipped > 0) parts.add('${result.skipped} already present');
      if (result.errors.isNotEmpty) parts.add('${result.errors.length} rows skipped');
      _showMessage(parts.join(' • '));
    } catch (e) {
      _showMessage('Import failed: $e', isError: true);
    }
  }

  /// Returns true to replace everything, false to merge, null to cancel.
  Future<bool?> _askImportMode(CsvImportData data) {
    final c = AppColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Import Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found in this file:', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 8),
            Text('• ${data.odometer.length} odometer readings'),
            Text('• ${data.fuel.length} fuel entries'),
            Text('• ${data.maintenance.length} maintenance entries'),
            if (data.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${data.errors.length} rows could not be read and will be skipped.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Merge keeps your current data and skips anything already present. '
              'Replace deletes everything currently in the app first.',
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Replace All'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
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
          TileCard(
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
          TileCard(
            child: Column(
              children: [
                ListTile(
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
                  subtitle: Text('Save a CSV backup to Downloads', style: TextStyle(fontSize: 12, color: c.textTertiary)),
                  trailing: Icon(Icons.chevron_right, color: c.textHint),
                ),
                Divider(height: 1, color: c.divider),
                ListTile(
                  onTap: () => _importData(context),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_upload_outlined, color: Color(0xFF2196F3), size: 24),
                  ),
                  title: const Text('Import Data', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Restore entries from a CSV backup', style: TextStyle(fontSize: 12, color: c.textTertiary)),
                  trailing: Icon(Icons.chevron_right, color: c.textHint),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // App info
          Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textTertiary)),
          const SizedBox(height: 8),
          TileCard(
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
