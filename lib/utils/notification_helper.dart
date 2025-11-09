import 'package:flutter/material.dart';

class NotificationHelper {
  static void showNotification(
    BuildContext context, {
    required String message,
    required bool isSuccess,
    int durationSeconds = 2,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Auto-dismiss
    Future.delayed(Duration(seconds: durationSeconds), () {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  static void showSuccessNotification(BuildContext context, String message) {
    showNotification(context, message: message, isSuccess: true);
  }

  static void showErrorNotification(BuildContext context, String message, {int durationSeconds = 3}) {
    showNotification(
      context,
      message: message,
      isSuccess: false,
      durationSeconds: durationSeconds,
    );
  }
}
