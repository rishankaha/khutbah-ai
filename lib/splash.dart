import 'package:flutter/material.dart';
import 'dart:async';
import 'dnd_warning.dart'; // Assuming this is the next screen

class SplashScreen extends StatefulWidget {
  final int milliseconds;

  const SplashScreen({Key? key, this.milliseconds = 2200}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller for fade-in/out
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    // Start fade-in animation immediately
    _animController.forward();

    // Navigate to the next screen after the duration
    Timer(Duration(milliseconds: widget.milliseconds), () {
      _animController.reverse().then((_) {
        // Use pushReplacement to prevent going back to the splash screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => DndWarningScreen()),
        );
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color matching your dark theme
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Replaced Icon with Image.asset ---
                Image.asset(
                  'assets/image/x.png', 
                  width: 120, // Set size for the logo
                  height: 120,
                  // Ensure your image is white/transparent for this background, 
                  // or use a ColorFilter if needed.
                ),
                
                const SizedBox(height: 18),
                
                // --- Updated Main Title ---
                const Text(
                  'Khutbah Live Translator',
                  style: TextStyle(
                    fontSize: 28, // Made slightly larger
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // --- Updated Subtitle ---
                const Text(
                  'Real-time Sermon Translation',
                  style: TextStyle(fontSize: 16, color: Colors.white70), // Made slightly larger
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}