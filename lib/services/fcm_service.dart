import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart'; // Needed for NavigatorState and MaterialPageRoute
import '../main.dart';
import '../chat/chat_message_screen.dart';
import '../notifications/notification_screen.dart';
import '../community/community_post_detail_screen.dart';
import '../space/post_detail_screen.dart';

// Background handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're using other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed in background: $e');
  }
  debugPrint("Handling a background message: ${message.messageId}");
}

class FcmService {
  final _supabase = Supabase.instance.client;
  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
  
  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static final Set<String> _processedMessageIds = {};

  // Initialize FCM
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('Firebase not initialized, skipping FCM configuration.');
      return;
    }

    if (_isInitialized) {
      debugPrint('FCMService already initialized, update token only.');
      await saveToken();
      return;
    }
    _isInitialized = true;

    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Setup Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Setup Foreground Handler (Local Notifications)
      await _setupLocalNotifications();
      
      // 4. Handle interactions
      
      // A. Terminated State: Check if app was opened by a notification
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('App opened from terminated state by notification: ${message.data}');
          // Delay slightly to ensure app is built
          Future.delayed(const Duration(seconds: 1), () {
            _handleNotificationTap(message.data);
          });
        }
      });

      // B. Background State: App opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background by notification: ${message.data}');
        _handleNotificationTap(message.data);
      });
      
      // C. Foreground Message Stream
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        
        // Deduplicate messages based on messageId
        if (message.messageId != null && _processedMessageIds.contains(message.messageId)) {
           debugPrint('Duplicate message ID ${message.messageId}, skipping.');
           return;
        }
        if (message.messageId != null) {
          _processedMessageIds.add(message.messageId!);
          // Keep set size manageable
          if (_processedMessageIds.length > 20) {
            _processedMessageIds.clear();
          }
        }

        debugPrint('Message data: ${message.data}');
        
        // Show local notification if payload exists
        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showLocalNotification(message);
        }
      });

      // 5. Get and Save Token
      await saveToken();

      // 6. Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((context) async {
         await saveToken(); 
      });
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_ic_notification');

    // iOS settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped payload: ${response.payload}');
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleNotificationTap(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );
    
    // Create Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            icon: 'ic_stat_ic_notification', 
            largeIcon: const DrawableResourceAndroidBitmap('app_logo'), // Blue logo (Right side)
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  // Handle Navigation on Notification Tap
  void _handleNotificationTap(Map<String, dynamic> data) async {
    final type = data['type'];
    final navigator = MyApp.navigatorKey.currentState;

    debugPrint('Handling notification tap: type=$type, data=$data');

    if (navigator == null) {
      debugPrint('Navigator state is null, cannot navigate');
      return;
    }

    if (type == 'chat') {
      final senderId = data['sender_id'];
      if (senderId != null) {
        // Fetch minimal user data needed for ChatMessageScreen
        try {
          final response = await _supabase
              .from('profiles')
              .select('id, username, avatar_url, current_mood')
              .eq('id', senderId)
              .maybeSingle();

          if (response != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (context) => ChatMessageScreen(
                  userId: response['id'],
                  name: response['username'] ?? 'Unknown',
                  avatarUrl: response['avatar_url'],
                  moodEmoji: '😊', // Default or fetch from mood logs
                  moodText: response['current_mood'] ?? 'Unknown',
                  colorHex: 'FF6B6B', // Default color
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error fetching sender profile for nav: $e');
        }
      }
    } else if (type == 'trending_post') {
      final postId = data['post_id'];
      if (postId != null) {
         _navigateToPost(navigator, postId);
      }
    } else if (type == 'community_new_post') {
      final communityPostId = data['community_post_id'];
      if (communityPostId != null) {
        _navigateToCommunityPost(navigator, communityPostId);
      }
    } else {
      // Default: Go to Notifications Screen
      navigator.push(
        MaterialPageRoute(
           builder: (context) => const NotificationScreen(),
        ),
      );
    }
  }

  Future<void> _navigateToPost(NavigatorState navigator, String postId) async {
    try {
        final post = await _supabase.from('posts').select().eq('id', postId).maybeSingle();
        if (post != null) {
           // We need enriched post data (username, avatar etc). A bit messy here.
           // Ideally PostDetailScreen fetches it, but it expects a map.
           // We'll let PostDetailScreen handle fetching if we could, 
           // BUT PostDetailScreen takes a 'post' map with pre-filled data.
           // Let's quickly fetch profile.
           final user = await _supabase.from('profiles').select().eq('id', post['user_id']).maybeSingle();
           
           if (user != null) {
             final enrichedPost = {
               ...post,
               'username': user['username'],
               'avatar_url': user['avatar_url'],
               'isVerified': user['is_verified'],
               'timeAgo': 'Just now', // Placeholder
               'mood': post['mood'],
             };
             navigator.push(
              MaterialPageRoute(builder: (context) => PostDetailScreen(post: enrichedPost)),
             );
           }
        }
    } catch (e) {
      debugPrint('Error navigating to post: $e');
    }
  }

  Future<void> _navigateToCommunityPost(NavigatorState navigator, String communityPostId) async {
    try {
       // Just fetch minimal needed? CommunityPostDetailScreen handles comments fetching.
       // It expects 'post' map.
       final post = await _supabase.from('community_posts').select().eq('id', communityPostId).maybeSingle();
       if (post != null) {
           // Fetch user
           final user = await _supabase.from('profiles').select().eq('id', post['user_id']).maybeSingle();
           if (user != null) {
              final enrichedPost = {
               ...post,
               'username': user['username'],
               'avatar_url': user['avatar_url'],
             };
             navigator.push(
              MaterialPageRoute(builder: (context) => CommunityPostDetailScreen(post: enrichedPost)),
             );
           }
       }
    } catch (e) {
      debugPrint('Error navigating to community post: $e');
    }
  }

  Future<void> saveToken() async {
    if (Firebase.apps.isEmpty) return;
    try {
      String? token = await _firebaseMessaging.getToken();
      final userId = _supabase.auth.currentUser?.id;

      print('FCM TOKEN: $token');

      if (token != null && userId != null) {
        
        // Determine device type
        String deviceType = 'other';
        if (kIsWeb) deviceType = 'web';
        else if (defaultTargetPlatform == TargetPlatform.android) deviceType = 'android';
        else if (defaultTargetPlatform == TargetPlatform.iOS) deviceType = 'ios';

        // 1. Upsert token to user_fcm_tokens (for multi-device support)
        await _supabase.from('user_fcm_tokens').upsert(
          {
            'user_id': userId,
            'token': token,
            'device_type': deviceType,
            'last_updated': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id, token',
        );

        // 2. Also update profiles table (legacy/single-device support)
        // We use a retry loop because the 'profiles' row might be created by a trigger
        // which could be slightly slower than this client-side call.
        int retries = 3;
        while (retries > 0) {
          try {
            // Check if profile exists first to verify we can update it
            final profileExists = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
            
            if (profileExists != null) {
               await _supabase.from('profiles').update({
                'fcm_token': token,
              }).eq('id', userId);
              debugPrint('Profiles table updated with FCM token');
              break; // Success
            } else {
               debugPrint('Profile not found yet, retrying... ($retries)');
               await Future.delayed(const Duration(milliseconds: 1000));
               retries--;
            }
          } catch (e) {
               debugPrint('Error updating profiles fcm_token: $e');
               break; 
          }
        }

        debugPrint('FCM Token saved to Supabase (user_fcm_tokens & profiles)');
      } else {
        debugPrint('FCM Token or UserId is null. Token: $token, UserId: $userId');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
  
  // Method to remove token on logout
  Future<void> deleteToken() async {
     if (Firebase.apps.isEmpty) return;
     try {
       String? token = await _firebaseMessaging.getToken();
       if (token != null) {
          await _supabase.from('user_fcm_tokens').delete().eq('token', token);
       }
     } catch (e) {
       debugPrint('Error deleting FCM token: $e');
     }
  }
}
