import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import '../utils/notification_utils.dart';

enum AsyncButtonState { idle, loading }

class AsyncActionButton extends StatefulWidget {
  final String text;
  final TaskEither<String, void> Function() onPressed;

  const AsyncActionButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  State<AsyncActionButton> createState() => _AsyncActionButtonState();
}

class _AsyncActionButtonState extends State<AsyncActionButton> {
  AsyncButtonState _state = AsyncButtonState.idle;

  Future<void> _handlePress() async {
    setState(() => _state = AsyncButtonState.loading);

    final result = await widget.onPressed().run();

    if (!mounted) return;

    result.fold(
      (error) {
        setState(() => _state = AsyncButtonState.idle);

        NotificationUtils.showError(error);
      },
      (_) {
        setState(() => _state = AsyncButtonState.idle);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: switch (_state) {
          AsyncButtonState.idle => _handlePress,
          AsyncButtonState.loading => null,
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: switch (_state) {
          AsyncButtonState.loading => SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          AsyncButtonState.idle => Text(
            widget.text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        },
      ),
    );
  }
}
