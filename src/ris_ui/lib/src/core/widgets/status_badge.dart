import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      'processed' => (const Color(0xFFDFF7E8), const Color(0xFF186A3B)),
      'processing' => (const Color(0xFFE4EEFF), const Color(0xFF2457C5)),
      'pending' => (const Color(0xFFFFF4D8), const Color(0xFF8B6500)),
      'failed' => (const Color(0xFFFFE1E1), const Color(0xFF9C1C1C)),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          status,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
