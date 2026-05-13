// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentPreviewModal extends StatefulWidget {
  final String documentName;
  final String? fileUrl;
  final DateTime? expiryDate;
  final String? observations;
  final String? ownerName;

  const DocumentPreviewModal({
    super.key,
    required this.documentName,
    this.fileUrl,
    this.expiryDate,
    this.observations,
    this.ownerName,
  });

  static Future<void> show({
    required BuildContext context,
    required String documentName,
    String? fileUrl,
    DateTime? expiryDate,
    String? observations,
    String? ownerName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: DocumentPreviewModal(
            documentName: documentName,
            fileUrl: fileUrl,
            expiryDate: expiryDate,
            observations: observations,
            ownerName: ownerName,
          ),
        );
      },
    );
  }

  @override
  State<DocumentPreviewModal> createState() => _DocumentPreviewModalState();
}

class _DocumentPreviewModalState extends State<DocumentPreviewModal> {
  String get _cleanPath {
    if (widget.fileUrl == null || widget.fileUrl!.isEmpty) return '';
    final uri = Uri.tryParse(widget.fileUrl!);
    return (uri?.path ?? widget.fileUrl!).toLowerCase();
  }

  bool get _isPdf {
    final url = widget.fileUrl?.toLowerCase() ?? '';
    final name = widget.documentName.toLowerCase();

    return _cleanPath.endsWith('.pdf') ||
        url.contains('.pdf') ||
        url.contains('/raw/upload/') ||
        url.contains('/image/upload/') ||
        name.contains('pdf') ||
        name.contains('cedula') ||
        name.contains('licencia') ||
        name.contains('soat') ||
        name.contains('tecnomecanica') ||
        name.contains('seguro') ||
        name.contains('tarjeta') ||
        name.contains('contractual');
  }

  bool get _isImage =>
      _cleanPath.endsWith('.png') ||
      _cleanPath.endsWith('.jpg') ||
      _cleanPath.endsWith('.jpeg') ||
      _cleanPath.endsWith('.webp');

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 920,
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F6B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildPreview()),
            const Divider(height: 1, color: Colors.white24),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.documentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.expiryDate != null
                      ? 'Vencimiento: ${_formatDate(widget.expiryDate!)}'
                      : 'Fecha de vencimiento no disponible',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (widget.fileUrl == null || widget.fileUrl!.trim().isEmpty) {
      return _buildPreviewPlaceholder();
    }

    final url = widget.fileUrl!.trim();

    debugPrint('📄 PREVIEW URL: $url');

    if (_isPdf) {
      if (kIsWeb) {
        final viewId = 'pdf-preview-${url.hashCode}';

        ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
          final previewUrl =
              'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}';

          final iframe = html.IFrameElement()
            ..src = previewUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true;

          return iframe;
        });

        return Container(
          color: Colors.white,
          child: HtmlElementView(viewType: viewId),
        );
      }

      return Container(
        color: Colors.white,
        child: SfPdfViewer.network(
          url,
          canShowPaginationDialog: true,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          enableDoubleTapZooming: true,
          pageSpacing: 4,
          onDocumentLoaded: (details) {
            debugPrint('✅ PDF cargado correctamente');
          },
          onDocumentLoadFailed: (details) {
            debugPrint('❌ ERROR PDF');
            debugPrint(details.description);
          },
        ),
      );
    }

    if (_isImage) {
      return Container(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 6,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ),
      );
    }

    return _buildPreviewPlaceholder();
  }

  Widget _buildPreviewPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.insert_drive_file_rounded,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          const Text(
            'Vista previa no disponible',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Este archivo no se puede previsualizar aquí. Puedes descargarlo para abrirlo en tu dispositivo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Text(
            widget.documentName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.observations != null &&
              widget.observations!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.observations!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      widget.fileUrl != null &&
                          widget.fileUrl!.trim().isNotEmpty
                      ? () => _downloadDocument(context)
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.lightBlueAccent,
                    side: const BorderSide(color: Colors.lightBlueAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cerrar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(BuildContext context) async {
    if (widget.fileUrl == null || widget.fileUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay archivo disponible para descargar'),
        ),
      );
      return;
    }

    final originalUrl = widget.fileUrl!.trim();

    final userName = _safeFileName(
      widget.ownerName == null || widget.ownerName!.trim().isEmpty
          ? 'usuario'
          : widget.ownerName!,
    );

    final documentType = _safeFileName(widget.documentName);

    final fileName = '${userName}_$documentType';

    String downloadUrl = originalUrl;

    // Quita el false de previsualización
    downloadUrl = downloadUrl.replaceFirst('/fl_attachment:false/', '/');

    // Cloudinary: fuerza descarga con nombre correcto
    if (downloadUrl.contains('/upload/')) {
      downloadUrl = downloadUrl.replaceFirst(
        '/upload/',
        '/upload/fl_attachment:$fileName/',
      );
    }

    final Uri? uri = Uri.tryParse(downloadUrl);

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El enlace del documento no es válido')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el documento')),
      );
    }
  }

  String _safeFileName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
