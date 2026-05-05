import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentPreviewModal extends StatelessWidget {
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

  bool get _isPdf => fileUrl?.toLowerCase().endsWith('.pdf') ?? false;
  bool get _isImage =>
      fileUrl != null &&
      (fileUrl!.toLowerCase().endsWith('.png') ||
          fileUrl!.toLowerCase().endsWith('.jpg') ||
          fileUrl!.toLowerCase().endsWith('.jpeg') ||
          fileUrl!.toLowerCase().endsWith('.webp'));

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
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
                  documentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  expiryDate != null
                      ? 'Vencimiento: ${_formatDate(expiryDate!)}'
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
    if (_isPdf && fileUrl != null && fileUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.zero),
        child: SfPdfViewer.network(
          fileUrl!,
          canShowPaginationDialog: true,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          pageLayoutMode: PdfPageLayoutMode.single,
        ),
      );
    }

    if (_isImage && fileUrl != null && fileUrl!.isNotEmpty) {
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 6.0,
        child: Image.network(
          fileUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
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
            documentName,
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
          if (observations != null && observations!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Observaciones',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    observations!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: fileUrl != null && fileUrl!.isNotEmpty
                      ? () => _downloadDocument(context)
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade700),
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
    if (fileUrl == null || fileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay archivo disponible para descargar'),
        ),
      );
      return;
    }

    final Uri? uri = Uri.tryParse(fileUrl!);

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
