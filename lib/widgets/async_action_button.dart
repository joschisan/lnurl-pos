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

  void _updateState(AsyncButtonState newState) {
    if (!mounted) return;

    setState(() => _state = newState);
  }

  void _showError(String message) {
    if (!mounted) return;

    NotificationUtils.showError(message);
  }

  Future<void> _handlePress() async {
    _updateState(AsyncButtonState.loading);

    final result = await widget.onPressed().run();

    result.fold(
      (error) {
        _updateState(AsyncButtonState.idle);
        _showError(error);
      },
      (_) {
        _updateState(AsyncButtonState.idle);
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
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: switch (_state) {
          AsyncButtonState.loading => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          AsyncButtonState.idle => Text(
            widget.text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        },
      ),
    );
  }
}
