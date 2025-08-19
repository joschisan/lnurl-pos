import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../bridge_generated.dart/lib.dart';
import '../widgets/action_button.dart';
import '../widgets/amount_display.dart';
import '../utils/notification_utils.dart';

enum PaymentStatus { pending, paid, failed }

class InvoiceScreen extends StatefulWidget {
  final LnurlClient lnurlClient;
  final int amountFiat;
  final Invoice invoice;

  const InvoiceScreen({
    super.key,
    required this.lnurlClient,
    required this.amountFiat,
    required this.invoice,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  PaymentStatus _paymentStatus = PaymentStatus.pending;

  @override
  void initState() {
    super.initState();
    _startPaymentVerification();
  }

  // Start polling for payment verification similar to home screen event polling
  void _startPaymentVerification() async {
    try {
      // This will poll until payment is complete or fails
      await widget.invoice.verifyPayment();

      if (!mounted) return;

      setState(() {
        _paymentStatus = PaymentStatus.paid;
      });
    } catch (e) {
      if (!mounted) return;

      NotificationUtils.showError(e.toString());

      setState(() {
        _paymentStatus = PaymentStatus.failed;
      });
    }
  }

  Widget _buildPaymentStatusBanner() {
    return switch (_paymentStatus) {
      PaymentStatus.pending => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.orange,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Waiting for payment...',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      PaymentStatus.paid => ActionButton(
        text: 'Continue',
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      PaymentStatus.failed => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Text(
            'Payment failed',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    };
  }

  void _showDismissConfirmationDrawer(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.error,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Dismiss Unpaid Invoice?',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ActionButton(
                    text: 'Confirm',
                    onPressed: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.pop(context); // Go back to previous screen
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (_paymentStatus == PaymentStatus.pending) {
            _showDismissConfirmationDrawer(context);
          } else {
            Navigator.pop(context);
          }
        },
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AmountDisplay(
              amountFiat: widget.amountFiat,
              amountSats:
                  widget.invoice.amountMsat() ~/ 1000, // Convert msat to sats
              currencySymbol: widget.lnurlClient.currencySymbol(),
            ),
            const SizedBox(height: 16),
            _paymentStatus == PaymentStatus.paid
                ? _buildSuccessVisual()
                : _buildQrVisual(),
            const Spacer(),
            _buildPaymentStatusBanner(),
          ],
        ),
      ),
    ),
  );

  Widget _buildSuccessVisual() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
    ),
    child: const SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 1,
        child: Center(
          child: Icon(Icons.check_circle, color: Colors.green, size: 100),
        ),
      ),
    ),
  );

  Widget _buildQrVisual() => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: PrettyQrView.data(
      data: widget.invoice.raw(),
      decoration: const PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(color: Colors.black),
        background: Colors.white,
      ),
    ),
  );
}
