import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:intl/intl.dart';
import '../widgets/async_action_button.dart';
import '../bridge_generated.dart/lib.dart';
import '../utils/fp_utils.dart';
import 'invoice_screen.dart';
import 'cashup_screen.dart';

class AmountScreen extends StatefulWidget {
  final LnurlClient lnurlClient;

  const AmountScreen({super.key, required this.lnurlClient});

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  int _amountFiat = 0;

  void _onKeyboardTap(int value) {
    if (_amountFiat > 9999999999) return;

    setState(() {
      _amountFiat = (_amountFiat * 10) + value;
    });

    widget.lnurlClient.updateCaches();
  }

  void _onBackspace() {
    if (_amountFiat > 0) {
      setState(() {
        _amountFiat = _amountFiat ~/ 10;
      });
    }
  }

  void _onClear() {
    setState(() {
      _amountFiat = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          CashupScreen(lnurlClient: widget.lnurlClient),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Amount display - fills remaining space above continue button
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.lnurlClient.currencySymbol()} ${NumberFormat('#,##0.00').format(_amountFiat / 100)}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.lnurlClient.currencyName(),
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AsyncActionButton(
                text: 'Continue',
                onPressed: _handleSubmit,
              ),
            ),

            // Custom number pad - explicit buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio:
                    2.0, // Makes buttons less tall (wider than tall)
                children: [
                  _buildNumberButton(1),
                  _buildNumberButton(2),
                  _buildNumberButton(3),
                  _buildNumberButton(4),
                  _buildNumberButton(5),
                  _buildNumberButton(6),
                  _buildNumberButton(7),
                  _buildNumberButton(8),
                  _buildNumberButton(9),
                  _buildActionButton(Icons.clear, _onClear),
                  _buildNumberButton(0),
                  _buildActionButton(Icons.backspace_outlined, _onBackspace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(int number) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _onKeyboardTap(number),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  TaskEither<String, void> _handleSubmit() {
    if (_amountFiat == 0) {
      return TaskEither.left('Please enter an amount');
    }

    return safeTask(
      () => widget.lnurlClient.resolve(amountFiat: _amountFiat),
    ).map((invoice) async {
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => InvoiceScreen(
                lnurlClient: widget.lnurlClient,
                amountFiat: _amountFiat,
                invoice: invoice,
              ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _amountFiat = 0;
      });
    });
  }
}
