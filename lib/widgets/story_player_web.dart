// Web implementation: native <video> element via HtmlElementView.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registered = <String>{};
final Map<String, VoidCallback?> _callbacks = <String, VoidCallback?>{};

Widget buildVideoPlayer(String videoUrl, {VoidCallback? onEnded}) {
  final viewType = 'story-video-${videoUrl.hashCode}';
  // Always update callback so it stays current even after hot-reload / rebuild
  _callbacks[viewType] = onEnded;
  if (!_registered.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el = html.VideoElement()
        ..src = videoUrl
        ..autoplay = true
        ..muted = true
        ..controls = false
        ..loop = false
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = 'black';
      el.onEnded.listen((_) => _callbacks[viewType]?.call());
      return el;
    });
    _registered.add(viewType);
  }
  return HtmlElementView(viewType: viewType);
}
