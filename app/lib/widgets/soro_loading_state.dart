import 'package:flutter/material.dart';

import 'ilu_state_view.dart';

/// Ìlù is listening while something loads. No action: it should resolve alone.
class SoroLoadingState extends StatelessWidget {
  const SoroLoadingState({
    super.key,
    this.title = 'Getting things ready',
    this.message = 'Ìlù is on it. This will only take a moment.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => SoroStateView(
        kind: SoroStateKind.loading,
        title: title,
        message: message,
      );
}
