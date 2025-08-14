import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../utils/notification_utils.dart';

class QrCodeWithCopy extends StatelessWidget {
  final String data;
  final String copyMessage;

  const QrCodeWithCopy({
    super.key,
    required this.data,
    required this.copyMessage,
  });

  void _handleCopy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: data));
    NotificationUtils.showCopy(copyMessage);
  }

  @override
  Widget build(BuildContext context) =>
      Column(children: [_buildQrCode(), _buildCopyButton(context)]);

  Widget _buildQrCode() => Padding(
    padding: const EdgeInsets.all(16),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: PrettyQrView.data(
        data: data,
        decoration: const PrettyQrDecoration(
          shape: PrettyQrSmoothSymbol(color: Colors.black),
          background: Colors.white,
        ),
      ),
    ),
  );

  Widget _buildCopyButton(BuildContext context) => ElevatedButton.icon(
    onPressed: () => _handleCopy(context),
    icon: const Icon(Icons.copy, size: 24),
    label: const Text('Copy to Clipboard'),
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
