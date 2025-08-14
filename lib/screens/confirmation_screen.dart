import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/action_button.dart';
import '../widgets/amount_display.dart';

class ConfirmationScreen extends StatelessWidget {
  final String currencySymbol;
  final int amountFiat;
  final int amountSats;

  const ConfirmationScreen({
    super.key,
    required this.currencySymbol,
    required this.amountFiat,
    required this.amountSats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder:
                        (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 200,
                    ),
                  ),
                ),
              ),
              AmountDisplay(
                amountFiat: amountFiat,
                amountSats: amountSats,
                currencySymbol: currencySymbol,
              ),
              const Expanded(child: SizedBox()),
              ActionButton(
                text: 'Continue',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
