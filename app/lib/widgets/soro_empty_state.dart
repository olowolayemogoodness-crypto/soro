import 'package:flutter/material.dart';

import 'ilu_state_view.dart';

/// Nothing here yet: Ìlù encourages the student toward one clear action.
class SoroEmptyState extends StatelessWidget {
  const SoroEmptyState({
    super.key,
    this.title = 'Nothing here yet',
    this.message = 'Ask Ìlù a question and it will show up here.',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SoroStateView(
        kind: SoroStateKind.empty,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}
