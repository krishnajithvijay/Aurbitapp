import 'package:flutter/material.dart';
import '../shared/widgets/custom_bottom_navigation.dart';

class HomeMobile extends StatelessWidget {
  final int currentIndex;
  final Widget currentPage;
  final Function(int) onTabTapped;
  final int unreadMessageCount;
  final int notificationCount;

  const HomeMobile({
    super.key,
    required this.currentIndex,
    required this.currentPage,
    required this.onTabTapped,
    required this.unreadMessageCount,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: currentPage,
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: currentIndex,
        onTap: onTabTapped,
        unreadMessageCount: unreadMessageCount,
      ),
    );
  }
}
