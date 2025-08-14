import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class NotificationUtils {
  static void _showNotification(
    String message,
    IconData icon,
    Color iconColor,
    Duration duration,
  ) {
    showOverlayNotification(
      (context) => Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(icon, size: 26, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      duration: duration,
      position: NotificationPosition.top,
    );
  }

  static void showError(String message) {
    _showNotification(
      message,
      Icons.error,
      Colors.red,
      const Duration(seconds: 3),
    );
  }
}
