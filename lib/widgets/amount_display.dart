import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmountDisplay extends StatelessWidget {
  final int amountFiat;
  final int amountSats;
  final String currencySymbol;

  const AmountDisplay({
    super.key,
    required this.amountFiat,
    required this.amountSats,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fiat amount display (prominent)
        Text(
          '$currencySymbol${NumberFormat('#,##0.00').format(amountFiat / 100)}',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Sats amount display (smaller, orange)
        Text(
          '${NumberFormat('#,###').format(amountSats)} sats',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Colors.orange,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
