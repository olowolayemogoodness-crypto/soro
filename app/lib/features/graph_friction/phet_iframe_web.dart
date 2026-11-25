import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'canvas_bridge.dart';

@JS('document')
external _HtmlDocument get _document;

extension type _HtmlDocument(JSObject _) implements JSObject {
  external JSObject createElement(JSString tagName);
}

extension type _HtmlIframeElement(JSObject _) implements JSObject {
  external set src(JSString value);
  external JSString get src;
  external set allow(JSString value);
  external _CssStyleDeclaration get style;
  external _WindowProxy? get contentWindow;
  external void setAttribute(JSString name, JSString value);
}

extension type _CssStyleDeclaration(JSObject _) implements JSObject {
  external set border(JSString value);
  external set width(JSString value);
  external set height(JSString value);
  external set borderRadius(JSString value);
  external set backgroundColor(JSString value);
}

extension type _WindowProxy(JSObject _) implements JSObject {
  external void postMessage(JSAny? message, JSString targetOrigin);
}

final Map<String, _HtmlIframeElement> _registeredIframes =
    <String, _HtmlIframeElement>{};

Widget buildPlatformPhetIframe({
  required String url,
  required CanvasCmd? lastCmd,
  required double height,
}) {
  final viewType =
      'soro-phet-friction-iframe-${url.contains('_yo.html') ? 'yo' : 'en'}';

  if (!_registeredIframes.containsKey(viewType)) {
    final iframe = _HtmlIframeElement(_document.createElement('iframe'.toJS));
    iframe.src = url.toJS;
    iframe.allow = 'fullscreen; autoplay'.toJS;
    iframe.setAttribute(
      'title'.toJS,
      'PhET Forces and Motion: Basics (Friction)'.toJS,
    );
    iframe.style.border = '0'.toJS;
    iframe.style.width = '100%'.toJS;
    iframe.style.height = '100%'.toJS;
    iframe.style.borderRadius = '12px'.toJS;
    iframe.style.backgroundColor = '#FFFEFA'.toJS;

    _registeredIframes[viewType] = iframe;
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => iframe,
    );
  } else {
    final existing = _registeredIframes[viewType]!;
    if (existing.src.toDart != url) {
      existing.src = url.toJS;
    }
  }

  // Forward incoming canvas_cmd to the embedded PhET iframe via postMessage.
  if (lastCmd != null) {
    final iframe = _registeredIframes[viewType];
    try {
      final payload = jsonEncode(lastCmd.toJson());
      iframe?.contentWindow?.postMessage(payload.toJS, '*'.toJS);
    } catch (_) {
      // Cross-origin frame may still be initializing.
    }
  }

  return Container(
    key: const Key('phet_iframe_container'),
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFEFA),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFDDD4BA), width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: HtmlElementView(viewType: viewType),
        ),
        Positioned(
          left: 8,
          bottom: 6,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xEBFFFEFA),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFDDD4BA)),
              ),
              child: Text(
                url.contains('_yo.html')
                    ? 'PhET Yorùbá build (_yo.html) · needs native check'
                    : 'PhET English build (_en.html)',
                key: const Key('phet_iframe_url_text'),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF565044),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
