import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:badges/badges.dart' as badges;
import '../../core/theme/app_theme.dart';
import '../feed/feed_screen.dart';
import '../communities/communities_screen.dart';
import '../chat/chat_list_screen.dart';
import '../orbit/orbit_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _notificationCount = 0;
  int _messageCount = 0;

  final List<Widget> _screens = const [
    FeedScreen(),
    CommunitiesScreen(),
    ChatListScreen(),
    OrbitScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.darkCard,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTabTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        border: const Border(top: BorderSide(color: AppColors.darkBorder, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, index: 0, currentIndex: _currentIndex, onTap: _onTabTap),
              _NavItem(icon: Icons.people_alt_rounded, index: 1, currentIndex: _currentIndex, onTap: _onTabTap),
              _ChatNavItem(
                currentIndex: _currentIndex,
                onTap: _onTabTap,
                badgeCount: _messageCount,
              ),
              _NavItem(icon: Icons.hub_rounded, index: 3, currentIndex: _currentIndex, onTap: _onTabTap),
              _NavItem(icon: Icons.person_rounded, index: 4, currentIndex: _currentIndex, onTap: _onTabTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatNavItem extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final int badgeCount;

  const _ChatNavItem({
    required this.currentIndex,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(2),
        child: Center(
          child: badges.Badge(
            showBadge: badgeCount > 0,
            badgeContent: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            badgeStyle: const badges.BadgeStyle(
              badgeColor: AppColors.accentPink,
              padding: EdgeInsets.all(5),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 24,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
