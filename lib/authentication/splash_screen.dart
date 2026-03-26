import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/fcm_service.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const SplashScreen({super.key, required this.onContinue});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    // Setup animations for the 3 dots
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Stagger the animations
    Future.delayed(Duration.zero, () {
      if (mounted) _controllers[0].repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controllers[1].repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controllers[2].repeat(reverse: true);
    });

    // Start connection check
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    // Wait for at least 1 second for animation
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Simple ping to check connection
      // We catch any error. If it's a network error, we fail.
      // If it's an RLS error or empty, we consider it connected.
      await Supabase.instance.client
          .from('profiles')
          .select('id')
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 10)); // Increased timeout for stability
      
      // If we get here (or get a Supabase error that isn't a network crash), we are likely online.
      if (mounted) {
        // Initialize FCM if we have a connection and potentially a user
        try {
           await FcmService().initialize();
        } catch (e) {
           debugPrint("FCM Init failed: $e");
           // Don't block app start on FCM fail
        }
        widget.onContinue();
      }

    } catch (e) {
      if (e is TimeoutException) {
         debugPrint('Connection check timed out');
          if (mounted) {
            setState(() {
              _showError = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connection Timed Out. Please check your internet connection.')),
            );
          }
      } else if (e is PostgrestException) {
         // PostgrestException means we talked to Supabase (SDK can throw this)
         // treating as success regarding "connection".
         if (mounted) widget.onContinue();
      } else {
        // Likely network error
        if (mounted) {
          setState(() {
            _showError = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection Error: $e. Check emulator/device internet.')),
          );
        }
      }
    }
  }

  bool _showError = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title and Subtitle
              Column(
                children: [
                  const Text(
                    'Aurbit',
                    style: TextStyle(
                      fontSize: 60, // ~text-6xl
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // text-foreground
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 24), // space-y-6 equivalent gap
                  Text(
                    'Your space. Your pace.',
                    style: TextStyle(
                      fontSize: 20, // ~text-xl
                      color: Colors.grey[400], // text-muted-foreground
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48), // mt-12

              // Pulsing Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ScaleTransition(
                      scale: _animations[index],
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white, // primary color
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              
              if (_showError)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _showError = false);
                      _checkConnection();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    child: const Text("Retry Connection"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
