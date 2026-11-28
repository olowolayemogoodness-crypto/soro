import 'package:flutter/material.dart';

import '../../theme/soro_theme.dart';

/// 48 px "Hear Soro" speaker button. Press speaks, press again stops.
class HearSoroButton extends StatelessWidget {
  const HearSoroButton({
    super.key,
    required this.onPressed,
    this.active = false,
    this.label = 'Hear Soro',
  });

  final VoidCallback onPressed;
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: active ? 'Stop Soro' : label,
      child: SizedBox(
        height: 48,
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: SoroTokens.crimson,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: Icon(
            active ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
            size: 22,
          ),
          label: Text(
            active ? 'Stop' : label,
            style: SoroTokens.sans(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
