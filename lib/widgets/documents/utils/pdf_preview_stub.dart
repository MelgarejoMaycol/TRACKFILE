import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

Widget buildPdfPreview(String url) {
  return Container(
    color: Colors.white,
    child: SfPdfViewer.network(
      url,
      canShowPaginationDialog: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      pageSpacing: 4,
      onDocumentLoaded: (_) {
        debugPrint('✅ PDF cargado correctamente');
      },
      onDocumentLoadFailed: (details) {
        debugPrint('❌ ERROR PDF');
        debugPrint(details.description);
      },
    ),
  );
}