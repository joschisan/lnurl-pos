import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fpdart/fpdart.dart' hide State;
import '../utils/notification_utils.dart';
import '../bridge_generated.dart/lib.dart';
import 'currency_screen.dart';

Widget _buildQrScanner(
  MobileScannerController controller,
  void Function(BarcodeCapture) onDetect,
  VoidCallback onPaste,
) => LayoutBuilder(
  builder: (context, constraints) {
    final size = constraints.maxWidth;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: MobileScanner(controller: controller, onDetect: onDetect),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: IconButton(
              onPressed: onPaste,
              icon: const Icon(Icons.paste, color: Colors.white, size: 36),
            ),
          ),
        ],
      ),
    );
  },
);

TaskEither<String, String> _getClipboardText() {
  return TaskEither.tryCatch(
    () => Clipboard.getData(Clipboard.kTextPlain),
    (error, stackTrace) => 'Clipboard access error: $error',
  ).flatMap(
    (clipboardData) => TaskEither.fromOption(
      Option.fromNullable(
        clipboardData?.text,
      ).filter((text) => text.isNotEmpty),
      () => 'Clipboard is empty',
    ),
  );
}

class LnurlScreen extends StatefulWidget {
  const LnurlScreen({super.key});

  @override
  State<LnurlScreen> createState() => _LnurlScreenState();
}

class _LnurlScreenState extends State<LnurlScreen> {
  final _controller = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    if (!mounted) return;

    if (capture.barcodes.isEmpty) return;

    if (capture.barcodes.first.rawValue == null) return;

    _processInput(capture.barcodes.first.rawValue!);
  }

  void _processInput(String lnurl) {
    try {
      final lnurlWrapper = parseLnurl(lnurl: lnurl);

      setState(() {
        _isScanning = false;
      });

      // Navigate to currency picker screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CurrencyScreen(lnurlWrapper: lnurlWrapper),
          ),
        );
      }

      return;
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    NotificationUtils.showError(message);
  }

  Future<void> _handleClipboardPaste() async {
    (await _getClipboardText().run()).fold(_showError, _processInput);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset('assets/logo.png', width: 80, height: 80),
                ),
              ),
            ),
            _buildQrScanner(_controller, _onDetect, _handleClipboardPaste),
            Expanded(
              child: Center(
                child: Text(
                  'Scan an LNURL payment code to start receiving payments.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
