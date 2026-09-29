import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around `flutter_local_notifications` for the one notification
/// this app sends: a service-due reminder, shown reactively when the app is
/// opened (or its data reloaded) while a reminder is overdue — there is no
/// background-scheduled alarm, so it only fires while the app is running.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _channelId = 'service_reminders';
  static const _channelName = 'Service Reminders';
  static const _notificationId = 1001;
  static const _enabledPrefKey = 'notifications_pref_enabled';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// App-level mute, independent of the OS permission — lets the user turn
  /// reminders off without revoking notification access entirely.
  bool _enabled = true;
  bool get isEnabled => _enabled;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefKey, value);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    // The status-bar icon must be a plain alpha-mask drawable, not the
    // full-color launcher icon (which Android can't render there).
    // Permission is deliberately not requested here — see [requestPermission],
    // which is only called after the user has seen a rationale dialog.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notify'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledPrefKey) ?? true;
    _initialized = true;
  }

  /// Requests the OS notification permission. Call only after showing the
  /// user a rationale for why the app wants it.
  Future<void> requestPermission() async {
    if (!_initialized) await initialize();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('requestPermission failed: $e');
    }
  }

  /// Whether the app is currently allowed to post notifications.
  ///
  /// Defaults to false on any platform-channel error, so a status row
  /// watching this can't get stuck waiting on a Future that never resolves.
  Future<bool> isPermissionGranted() async {
    if (!_initialized) await initialize();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.areNotificationsEnabled() ?? false;

      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    } catch (e) {
      debugPrint('isPermissionGranted failed: $e');
    }
    return false;
  }

  /// Opens the OS notification settings screen for this app, for when the
  /// permission was denied and a fresh request wouldn't prompt again.
  Future<void> openNotificationSettings() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.openAppNotificationSettings();
  }

  Future<void> showServiceDueNotification(String category) async {
    if (!_initialized) await initialize();
    if (!_enabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Reminders for overdue vehicle maintenance',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: _notificationId,
      title: 'Service due',
      body: '$category is overdue — time for a check-up.',
      notificationDetails: details,
    );
  }
}
