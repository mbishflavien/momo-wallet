import 'package:flutter/material.dart';

import 'screens/wallet_screen.dart';
import 'ui.dart';
import 'wallet.dart';

void main() => runApp(MomoApp(wallet: Wallet.sample()));

class MomoApp extends StatelessWidget {
  const MomoApp({super.key, required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoMo Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: momoYellow,
          primary: momoBlue,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6F2),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: WalletScreen(wallet: wallet),
    );
  }
}
