import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'screens/lnurl_scan_screen.dart';
import 'bridge_generated.dart/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RustLib.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: 'LNURL POS',
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(primary: Colors.orange),
          useMaterial3: true,
        ),
        home: const LnurlScanScreen(),
      ),
    );
  }
}
