import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/wallet_transaction.dart';
import 'screens/auth_gate.dart';
import 'screens/wallet_screen.dart';
import 'state/wallet_state.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }
  runApp(HirwaApp(firebaseReady: firebaseReady));
}

class HirwaApp extends StatelessWidget {
  const HirwaApp({super.key, this.firebaseReady = false});

  final bool firebaseReady;

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
      home: firebaseReady
          ? const AuthGate()
          : ChangeNotifierProvider(
              create: (_) => WalletState.local(sampleTransactions()),
              child: const WalletScreen(showCloudBanner: true),
            ),
    );
  }
}
