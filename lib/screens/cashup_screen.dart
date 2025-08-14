import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../bridge_generated.dart/lib.dart';
import '../widgets/action_button.dart';
import '../widgets/amount_display.dart';
import '../utils/notification_utils.dart';

class CashupScreen extends StatefulWidget {
  final LnurlClient lnurlClient;

  const CashupScreen({super.key, required this.lnurlClient});

  @override
  State<CashupScreen> createState() => _CashupScreenState();
}

class _CashupScreenState extends State<CashupScreen> {
  Widget buildPaymentTile(Payment payment) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _showPaymentDetails(payment),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.bolt,
            color: Theme.of(context).colorScheme.primary,
            size: 26,
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${widget.lnurlClient.currencySymbol()} ${NumberFormat('#,##0.00').format(payment.amountFiat / 100.0)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        trailing: Text(
          _formatTime(payment.createdAt),
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.bolt,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
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
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.primary,
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

  Future<void> _saveTransactions(BuildContext context) async {
    try {
      // Get CSV content directly from Rust backend
      final csvContent = widget.lnurlClient.exportTransactionsCsv();

      // Convert string to bytes
      final bytes = Uint8List.fromList(csvContent.codeUnits);

      // Format date for filename
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Let user pick save location with bytes for mobile compatibility
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Transaction Summary',
        fileName: 'cashup-$date.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );
    } catch (e) {
      NotificationUtils.showError('Failed to save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = widget.lnurlClient.listPayments();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveTransactions(context),
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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
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
