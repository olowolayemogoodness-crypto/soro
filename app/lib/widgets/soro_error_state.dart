import 'package:flutter/material.dart';

import 'ilu_state_view.dart';

/// Something did not load. Plain words, no blame, one clear way to try again.
class SoroErrorState extends StatelessWidget {
  const SoroErrorState({
    super.key,
    required this.onRetry,
    this.title = "That didn't load",
    this.message = 'Check your connection, then try again. Your work is safe.',
    this.actionLabel = 'Try again',
  });

  final VoidCallback onRetry;
  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => SoroStateView(
        kind: SoroStateKind.error,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onRetry,
      );
}
