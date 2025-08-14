import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:currency_picker/currency_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/async_action_button.dart';
import '../bridge_generated.dart/lib.dart';
import '../utils/fp_utils.dart';
import 'display_invoice_screen.dart';

class AmountScreen extends StatefulWidget {
  final LnurlClient lnurlClient;

  const AmountScreen({super.key, required this.lnurlClient});

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  Currency _currency = CurrencyService().findByCode('USD')!;
  int _amountMinorUnits = 0;

  void _onKeyboardTap(int value) {
    if (_amountMinorUnits > 9999999999) return;

    setState(() {
      _amountMinorUnits = (_amountMinorUnits * 10) + value;
    });
  }

  void _onBackspace() {
    if (_amountMinorUnits > 0) {
      setState(() {
        _amountMinorUnits = _amountMinorUnits ~/ 10;
      });
    }
  }

  void _onClear() {
    setState(() {
      _amountMinorUnits = 0;
    });
  }

  void _showCurrencyPicker(BuildContext context) {
    showCurrencyPicker(
      context: context,
      currencyFilter: <String>[
        'ARS',
        'AUD',
        'BDT',
        'BRL',
        'BTN',
        'BWP',
        'CAD',
        'CDF',
        'CHF',
        'COP',
        'CRC',
        'CUP',
        'CZK',
        'ERN',
        'ETB',
        'EUR',
        'GBP',
        'GHS',
        'GTQ',
        'HKD',
        'HNL',
        'IDR',
        'INR',
        'KES',
        'LBP',
        'MMK',
        'MWK',
        'MXN',
        'MYR',
        'NAD',
        'NGN',
        'NIO',
        'NZD',
        'PEN',
        'PHP',
        'PKR',
        'PLN',
        'SDG',
        'SOS',
        'SRD',
        'THB',
        'UAH',
        'USD',
        'UYU',
        'VES',
        'ZAR',
        'ZMW',
      ],
      onSelect: (Currency currency) {
        setState(() {
          _currency = currency;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showCurrencyPicker(context),
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
                      '${_currency.symbol}${NumberFormat('#,##0.00').format(_amountMinorUnits / 100)}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currency.name,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.withValues(alpha: 0.8),
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
        child: Center(child: Icon(icon, size: 28, color: Colors.white)),
      ),
    );
  }

  TaskEither<String, void> _handleSubmit() {
    if (_amountMinorUnits == 0) {
      return TaskEither.left('Please enter an amount');
    }

    return safeTask(
      () => widget.lnurlClient.resolve(
        amountMinorUnits: _amountMinorUnits,
        currencyCode: _currency.code,
      ),
    ).map((invoice) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => DisplayInvoiceScreen(
                currency: _currency,
                amountMinorUnits: _amountMinorUnits,
                invoice: invoice,
              ),
        ),
      );
    });
  }
}
