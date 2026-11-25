import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/soro_theme.dart';

enum SoroStateKind { empty, loading, error }

/// Friendly empty / loading / error state with Ìlù in an encouraging pose
/// (never a 'confused' one). Wording is passed in by the caller.
class SoroStateView extends StatelessWidget {
  const SoroStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final SoroStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String asset = kind == SoroStateKind.loading
        ? 'assets/mascot/soro-ilu-listening.svg'
        : 'assets/mascot/soro-ilu-encouraging.svg';
    return Semantics(
      container: true,
      liveRegion: kind != SoroStateKind.empty,
      label: '$title. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(SoroTokens.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(asset, height: 96),
                const SizedBox(height: SoroTokens.s16),
                if (kind == SoroStateKind.loading) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: SoroTokens.crimson,
                    ),
                  ),
                  const SizedBox(height: SoroTokens.s12),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: SoroTokens.serif(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.ink,
                  ),
                ),
                const SizedBox(height: SoroTokens.s8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: SoroTokens.sans(fontSize: 15, color: SoroTokens.ink2),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: SoroTokens.s16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: SoroTokens.minTapTarget,
                    ),
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SoroTokens.crimson,
                        foregroundColor: SoroTokens.paper,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SoroTokens.rPill),
                        ),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
