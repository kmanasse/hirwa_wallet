import 'package:flutter/material.dart';

import 'screens/wallet_screen.dart';
import 'theme.dart';

void main() => runApp(const HirwaApp());

class HirwaApp extends StatelessWidget {
  const HirwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hirwa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: hirwaNavy).copyWith(
          primary: hirwaNavy,
          onPrimary: Colors.white,
          secondary: hirwaGold,
          surface: hirwaPaper,
        ),
        scaffoldBackgroundColor: hirwaPaper,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: hirwaNavy,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: hirwaNavy,
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
      ),
      home: const WalletScreen(),
    );
  }
}
