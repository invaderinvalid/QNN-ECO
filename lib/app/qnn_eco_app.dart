import 'package:flutter/material.dart';

import '../features/startup/startup_screen.dart';

class QnnEcoApp extends StatelessWidget {
  const QnnEcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QNN-ECO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff4f46e5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}
