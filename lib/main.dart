import 'package:flutter/material.dart';

import 'dnd_warning.dart'; // Import the new warning screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Using the dark theme colors consistently across the app
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF0F1116),
        brightness: Brightness.dark,
      ),
      // Starts with DndWarningScreen
      home: const DndWarningScreen(),
    );
  }
}