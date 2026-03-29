import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_constants.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance.showLocalNotification(
    title: message.notification?.title ?? 'Aurbit',
    body: message.notification?.body ?? '',
    payload: message.data.toString(),
  );
}

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'aurbit_main';
  static const _channelName = 'Aurbit Notifications';

  Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel (Android)
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Aurbit app notifications',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      showLocalNotification(
        title: message.notification?.title ?? 'Aurbit',
        body: message.notification?.body ?? '',
        payload: message.data.toString(),
      );
    });

    // Save FCM token
    await saveFcmToken();

    // Token refresh
    _fcm.onTokenRefresh.listen((token) {
      _saveTokenToSupabase(token);
    });
  }

  Future<void> saveFcmToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToSupabase(token);
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;

    await SupabaseService.instance.client.from(AppConstants.fcmTokensTable).upsert({
      'user_id': userId,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Aurbit app notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap — navigate based on payload
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  Future<void> deleteFcmToken() async {
    await _fcm.deleteToken();
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;
    await SupabaseService.instance.client
        .from(AppConstants.fcmTokensTable)
        .delete()
        .eq('user_id', userId);
  }
}
