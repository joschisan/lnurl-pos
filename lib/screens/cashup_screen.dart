import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../bridge_generated.dart/lib.dart';
import '../widgets/action_button.dart';
import '../widgets/amount_display.dart';

class CashupScreen extends StatefulWidget {
  final LnurlClient lnurlClient;

  const CashupScreen({super.key, required this.lnurlClient});

  @override
  State<CashupScreen> createState() => _CashupScreenState();
}

class _CashupScreenState extends State<CashupScreen> {
  Widget buildPaymentTile(Payment payment) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => _showPaymentDetails(payment),
      leading: CircleAvatar(
        backgroundColor: Colors.orange.withValues(alpha: 0.1),
        child: Icon(Icons.bolt, color: Colors.orange, size: 26),
      ),
      title: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${widget.lnurlClient.currencySymbol()}${NumberFormat('#,##0.00').format(payment.amountFiat / 100.0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      trailing: Text(
        _formatTime(payment.createdAt),
        style: const TextStyle(fontSize: 18, color: Colors.grey),
      ),
    ),
  );

  void _showPaymentDetails(Payment payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      child: Icon(Icons.bolt, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateTime(payment.createdAt),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: AmountDisplay(
                    amountFiat: payment.amountFiat,
                    amountSats:
                        payment.amountMsat ~/ 1000, // Convert msat to sats
                    currencySymbol: widget.lnurlClient.currencySymbol(),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  String _formatDateTime(int createdAt) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return DateFormat('MMM dd, HH:mm:ss').format(dateTime);
  }

  String _formatTime(int createdAt) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return DateFormat('HH:mm').format(dateTime);
  }

  void _showDeleteConfirmationDrawer(BuildContext context) {
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
                          Icons.delete_outline,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Delete Payment History?',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ActionButton(
                    text: 'Confirm',
                    onPressed: () {
                      widget.lnurlClient.deletePayments();
                      Navigator.pop(context); // Close drawer
                      setState(() {}); // Refresh the screen
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _shareTransactions(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Let Rust create the file and return path
      final filePath = widget.lnurlClient.exportTransactionsToFile(
        outputDir: directory.path,
      );

      // Share the file using the returned path
      final fileName = filePath.split('/').last;

      await Share.shareXFiles(
        [XFile(filePath, name: fileName, mimeType: 'application/json')],
        text: 'Cashup transaction summary',
        subject: 'Transaction Summary - $fileName',
        sharePositionOrigin: Rect.zero,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = widget.lnurlClient.listPayments();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareTransactions(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmationDrawer(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: AmountDisplay(
                amountFiat: widget.lnurlClient.sumAmountsFiat(),
                amountSats:
                    widget.lnurlClient.sumAmountsMsat() ~/
                    1000, // Convert msat to sats
                currencySymbol: widget.lnurlClient.currencySymbol(),
              ),
            ),
            // Payment list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return buildPaymentTile(payment);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
