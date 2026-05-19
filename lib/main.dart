import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EducationalSecurityApp());
}

class EducationalSecurityApp extends StatelessWidget {
  const EducationalSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC e Biometria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
