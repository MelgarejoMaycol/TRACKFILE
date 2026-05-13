import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentPreviewModal extends StatefulWidget {
  final String documentName;
  final String? fileUrl;
  final DateTime? expiryDate;
  final String? observations;

  const DocumentPreviewModal({
    super.key,
    required this.documentName,
    this.fileUrl,
    this.expiryDate,
    this.observations,
  });

  static Future<void> show({
    required BuildContext context,
    required String documentName,
    String? fileUrl,
    DateTime? expiryDate,
    String? observations,
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
          ),
        );
      },
    );
  }

  @override
  State<DocumentPreviewModal> createState() => _DocumentPreviewModalState();
}

class _DocumentPreviewModalState extends State<DocumentPreviewModal> {
  late final String _viewType;

  String get _cleanPath {
    if (widget.fileUrl == null || widget.fileUrl!.isEmpty) return '';
    final uri = Uri.tryParse(widget.fileUrl!);
    return (uri?.path ?? widget.fileUrl!).toLowerCase();
  }

  bool get _isPdf => _cleanPath.endsWith('.pdf');

  bool get _isImage =>
      _cleanPath.endsWith('.png') ||
      _cleanPath.endsWith('.jpg') ||
      _cleanPath.endsWith('.jpeg') ||
      _cleanPath.endsWith('.webp');

  @override
  void initState() {
    super.initState();

    _viewType = 'pdf-preview-${DateTime.now().microsecondsSinceEpoch}';

    if (_isPdf && widget.fileUrl != null && widget.fileUrl!.isNotEmpty) {
      final iframe = html.IFrameElement()
        ..src = widget.fileUrl!
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'white'
        ..allowFullscreen = true;

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => iframe,
      );
    }
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          Expanded(child: _buildPreview()),
          const Divider(height: 1),
          _buildFooter(context),
        ],
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
    if (_isPdf && widget.fileUrl != null && widget.fileUrl!.isNotEmpty) {
      return Container(
        color: Colors.white,
        child: ClipRRect(
          child: HtmlElementView(viewType: _viewType),
        ),
      );
    }

    if (_isImage && widget.fileUrl != null && widget.fileUrl!.isNotEmpty) {
      return Container(
        color: Colors.black12,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 6.0,
          child: Center(
            child: Image.network(
              widget.fileUrl!,
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
                      widget.fileUrl != null && widget.fileUrl!.trim().isNotEmpty
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
    if (widget.fileUrl == null || widget.fileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay archivo disponible para descargar'),
        ),
      );
      return;
    }

    final Uri? uri = Uri.tryParse(widget.fileUrl!);

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El enlace del documento no es válido')),
      );
      return;
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el documento')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}