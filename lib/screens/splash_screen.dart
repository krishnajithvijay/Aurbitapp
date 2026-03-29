import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_theme.dart';
import '../core/services/auth_service.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    if (AuthService.instance.isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 48),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .then()
                .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 24),
            // App name
            Text(
              'Aurbit',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
            ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
            const SizedBox(height: 8),
            Text(
              'Connect. Chat. Orbit.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.5,
                  ),
            ).animate(delay: 500.ms).fadeIn(duration: 500.ms),
            const SizedBox(height: 80),
            // Loading indicator
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withOpacity(0.6),
                ),
              ),
            ).animate(delay: 800.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
