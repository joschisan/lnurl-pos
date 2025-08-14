import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';
import '../widgets/qr_code_with_copy.dart';
import '../bridge_generated.dart/lib.dart';

enum PaymentStatus { pending, paid, failed }

class DisplayInvoiceScreen extends StatefulWidget {
  final Currency currency;
  final int amountMinorUnits;
  final Invoice invoice;

  const DisplayInvoiceScreen({
    super.key,
    required this.currency,
    required this.amountMinorUnits,
    required this.invoice,
  });

  @override
  State<DisplayInvoiceScreen> createState() => _DisplayInvoiceScreenState();
}

class _DisplayInvoiceScreenState extends State<DisplayInvoiceScreen> {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentStatus = PaymentStatus.paid;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentStatus = PaymentStatus.failed;
      });
    }
  }

  Widget _buildPaymentStatusBanner() {
    switch (_paymentStatus) {
      case PaymentStatus.pending:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Waiting for payment...',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case PaymentStatus.paid:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 12),
              Text(
                'Payment received!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case PaymentStatus.failed:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text(
                'Payment failed',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Fiat amount display (prominent)
            Text(
              '${widget.currency.symbol}${NumberFormat('#,##0.00').format(widget.amountMinorUnits / 100)}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            // Sats amount display (smaller, orange)
            Text(
              '${NumberFormat('#,###').format(widget.invoice.amountSats())} sats',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            QrCodeWithCopy(
              data: widget.invoice.raw(),
              copyMessage: 'Invoice copied to clipboard',
            ),
            const Spacer(),
            _buildPaymentStatusBanner(),
          ],
        ),
      ),
    ),
  );
}
