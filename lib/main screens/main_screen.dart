import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../space/space_screen.dart';
import '../communities/communities_screen.dart';
import '../orbit/orbit_screen.dart';
import '../chat/chat_screen.dart';
import '../theme/theme_service.dart';
import '../creation/create_menu_sheet.dart';
import '../services/user_activity_service.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../mobile/home_mobile.dart';
import '../web/home_web.dart';
import '../shared/widgets/scale_button.dart';
import '../services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _unreadMessageCount = 0;
  int _notificationCount = 0; // State for notification badge
  Timer? _pollingTimer;
  RealtimeChannel? _notificationSubscription;
  RealtimeChannel? _messageSubscription;

  // Placeholder pages - created dynamically to pass callback and counts
  List<Widget> get _pages => [
    SpaceScreen(notificationCount: _notificationCount),
    const CommunitiesScreen(),
    const SizedBox(), // Placeholder for FAB
    OrbitScreen(notificationCount: _notificationCount),
    ChatScreen(
      onMessagesRead: _fetchUnreadCount,
      notificationCount: _notificationCount,
    ), 
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Start tracking user activity
    UserActivityService().startTracking();
    
    // Ensure FCM is initialized
    FcmService().initialize();
    
    // Fetch initial counts
    _fetchCounts();
    
    // Setup real-time listeners
    _setupRealtimeSubscriptions();
    
    // Start polling as a fallback (less frequent)
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _notificationSubscription?.unsubscribe();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UserActivityService().updateActivity();
      _fetchCounts();
      _startPolling(); 
    } else if (state == AppLifecycleState.paused) {
      _pollingTimer?.cancel(); 
    }
  }

  /// Poll for new messages every 4 seconds
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchCounts();
    });
  }

  Future<void> _fetchCounts() async {
    _fetchUnreadCount();
    _fetchNotificationCount();
  }

  Future<void> _fetchUnreadCount() async {
    final count = await UserActivityService().getUnreadMessageCount();
    if (mounted) {
      if (count != _unreadMessageCount) {
         setState(() => _unreadMessageCount = count);
      }
    }
  }

  Future<void> _fetchNotificationCount() async {
    // Import NotificationService at top of file needed
    try {
      // We need to import NotificationService first
      // Assuming it's imported (I will add import in next step or this one if I can)
      final count = await NotificationService().getUnreadCount();
      if (mounted) {
         if (count != _notificationCount) {
            setState(() => _notificationCount = count);
         }
      }
    } catch (_) {}
  }

  void _setupRealtimeSubscriptions() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Listen for new notifications
    _notificationSubscription = NotificationService().subscribeToNotifications((payload) {
      if (mounted) {
        _fetchNotificationCount();
      }
    });

    // Listen for new messages
    _messageSubscription = Supabase.instance.client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            if (mounted) _fetchUnreadCount();
          },
        )
        .subscribe();
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Handle Add Button Tap
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const CreateMenuSheet(),
      );
    } else {
      // Clear badge immediately when switching to chat
      if (index == 4) {
        setState(() {
          _currentIndex = index;
          _unreadMessageCount = 0; // Clear badge immediately
        });
        // Refresh with actual count after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _fetchUnreadCount();
        });
      } else if (index == 3) { // Orbit
         setState(() {
          _currentIndex = index;
        });
      } else {
        setState(() {
          _currentIndex = index;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb || screenWidth >= 650;

    if (isDesktop) {
      return HomeWeb(
        currentIndex: _currentIndex,
        currentPage: _pages[_currentIndex],
        onTabTapped: _onTabTapped,
        unreadMessageCount: _unreadMessageCount,
        notificationCount: _notificationCount,
      );
    } else {
      return HomeMobile(
        currentIndex: _currentIndex,
        currentPage: _pages[_currentIndex],
        onTabTapped: _onTabTapped,
        unreadMessageCount: _unreadMessageCount,
        notificationCount: _notificationCount,
      );
    }
  }
}

