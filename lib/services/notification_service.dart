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
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notify'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
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
