import 'package:flutter/material.dart';

class AppAsyncView extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.child,
    this.loadingLabel = 'Loading...',
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Widget child;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(loadingLabel),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return child;
  }
}
