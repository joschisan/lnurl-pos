import 'package:flutter/material.dart';
import 'package:currency_picker/currency_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge_generated.dart/lib.dart';
import '../widgets/action_button.dart';
import 'amount_screen.dart';

class CurrencyScreen extends StatelessWidget {
  final LnUrlWrapper lnurlWrapper;

  const CurrencyScreen({super.key, required this.lnurlWrapper});

  @override
  Widget build(BuildContext context) {
    final currencies =
        CurrencyService()
            .getAll()
            .where(
              (currency) => [
                'ARS',
                'AUD',
                'BRL',
                'CAD',
                'CHF',
                'CLP',
                'CZK',
                'DKK',
                'EUR',
                'GBP',
                'HKD',
                'HUF',
                'IDR',
                'ILS',
                'INR',
                'JPY',
                'KRW',
                'MXN',
                'MYR',
                'NOK',
                'NZD',
                'PHP',
                'PLN',
                'SEK',
                'SGD',
                'THB',
                'TRY',
                'USD',
                'ZAR',
              ].contains(currency.code),
            )
            .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: currencies.length,
          itemBuilder: (context, index) {
            final currency = currencies[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currency.code,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  currency.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onTap: () => _showConfirmationDrawer(context, currency),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showConfirmationDrawer(BuildContext context, Currency currency) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Currency display
                  Container(
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currency.code,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            currency.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ActionButton(
                    text: 'Confirm',
                    onPressed: () async {
                      // Get documents directory
                      final directory =
                          await getApplicationDocumentsDirectory();

                      // Persist config (infallible)
                      LnurlClient.persist(
                        dataDir: directory.path,
                        lnurl: lnurlWrapper,
                        currencyCode: currency.code,
                        currencySymbol: currency.symbol,
                        currencyName: currency.name,
                      );

                      // Load the client from persisted config
                      final client = LnurlClient.load(dataDir: directory.path);

                      if (!context.mounted || client == null) return;

                      Navigator.pop(context); // Close drawer

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => AmountScreen(lnurlClient: client),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
