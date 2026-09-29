import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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
    _initialized = true;
  }

  /// Requests the OS notification permission. Call only after showing the
  /// user a rationale for why the app wants it.
  Future<void> requestPermission() async {
    if (!_initialized) await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Whether the app is currently allowed to post notifications.
  Future<bool> isPermissionGranted() async {
    if (!_initialized) await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.areNotificationsEnabled() ?? false;

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;

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
