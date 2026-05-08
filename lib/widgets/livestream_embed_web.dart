// Web implementation of the YouTube iframe embed.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registered = <String>{};

Widget buildYoutubeIframe(String embedUrl) {
  final viewType = 'yt-iframe-${embedUrl.hashCode}';
  if (!_registered.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final element = html.IFrameElement()
        ..src = embedUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; encrypted-media; picture-in-picture'
        ..allowFullscreen = true;
      return element;
    });
    _registered.add(viewType);
  }
  return HtmlElementView(viewType: viewType);
}
