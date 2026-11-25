import 'package:flutter/material.dart';
import 'canvas_bridge.dart';

/// Fallback / VM-test implementation of the PhET iframe view when not running
/// on `dart:ui_web` (e.g. during `flutter test`).
Widget buildPlatformPhetIframe({
  required String url,
  required CanvasCmd? lastCmd,
  required double height,
}) {
  return Container(
    key: const Key('phet_iframe_container'),
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFEFA),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFDDD4BA), width: 1.5),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.public, size: 18, color: Color(0xFF1B56D0)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'PhET HTML5 Sim Bridge · ${url.contains('_yo.html') ? 'Yorùbá (_yo.html)' : 'English (_en.html)'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF292927),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          url,
          key: const Key('phet_iframe_url_text'),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF565044),
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (lastCmd != null) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD2E8F8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'postMessage -> canvas_cmd: ${lastCmd.cmd}',
              key: const Key('phet_iframe_last_cmd'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF292927),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
