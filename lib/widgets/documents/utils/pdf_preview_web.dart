// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

Widget buildPdfPreview(String url) {
  final viewId = 'pdf-preview-${url.hashCode}';

  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final previewUrl =
        'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}';

    return html.IFrameElement()
      ..src = previewUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true;
  });

  return Container(
    color: Colors.white,
    child: HtmlElementView(viewType: viewId),
  );
}