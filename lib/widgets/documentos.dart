import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'document_modal.dart';

class DocumentosWidget extends StatefulWidget {
  final String? role;
  final String? jsonPath;

  const DocumentosWidget({
    super.key,
    this.role,
    this.jsonPath,
  });

  @override
  State<DocumentosWidget> createState() => _DocumentosWidgetState();
}

class _DocumentInfo {
  final String name;
  final DateTime expiryDate;
  final DateTime? paymentDate;

  const _DocumentInfo({
    required this.name,
    required this.expiryDate,
    this.paymentDate,
  });

  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;
}

class _DocumentosWidgetState extends State<DocumentosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);
  static const Color _cardColor = Color(0xFF1B1F6B);

  bool _isLoading = true;
  late String _role;
  List<_DocumentInfo> _documents = const [];

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? 'Conductor').toLowerCase();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    List<_DocumentInfo> parsed = [];
    if (widget.jsonPath != null) {
      try {
        final String jsonString = await rootBundle.loadString(widget.jsonPath!);
        final dynamic decoded = json.decode(jsonString);
        final List<dynamic>? docs = decoded is Map<String, dynamic> ? decoded['documents'] as List<dynamic>? : null;
        if (docs != null) {
          parsed = docs.map((dynamic item) {
            if (item is Map<String, dynamic>) {
              final String name = (item['name'] ?? 'Documento').toString();
              final DateTime? expiry = DateTime.tryParse((item['expiryDate'] ?? '').toString());
              final DateTime? payment = DateTime.tryParse((item['paymentDate'] ?? '').toString());
              return expiry != null
                  ? _DocumentInfo(name: name, expiryDate: expiry, paymentDate: payment)
                  : null;
            }
            return null;
          }).whereType<_DocumentInfo>().toList();
        }
      } catch (e) {
        debugPrint('Error cargando documentos: $e');
      }
    }

    if (parsed.isEmpty) {
      parsed = _exampleDocuments();
    }

    parsed.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    if (mounted) {
      setState(() {
        _documents = parsed;
        _isLoading = false;
      });
    }
  }

  List<_DocumentInfo> _exampleDocuments() {
    final DateTime now = DateTime.now();
    return [
      _DocumentInfo(name: 'SOAT', expiryDate: now.add(const Duration(days: 90)), paymentDate: now.subtract(const Duration(days: 30))),
      _DocumentInfo(name: 'Tecnicomecánico', expiryDate: now.add(const Duration(days: 45)), paymentDate: now.subtract(const Duration(days: 15))),
      _DocumentInfo(name: 'Licencia', expiryDate: now.add(const Duration(days: 180)), paymentDate: now.subtract(const Duration(days: 60))),
      _DocumentInfo(name: 'Tarjeta de Operación', expiryDate: now.add(const Duration(days: 120)), paymentDate: now.subtract(const Duration(days: 45))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_role) {
      case 'empresa':
        return _empresaDocumentos();
      case 'propietario':
        return _propietarioDocumentos();
      case 'secretaria':
        return _secretariaDocumentos();
      case 'admin':
        return _adminDocumentos();
      case 'conductor':
        return _conductorDocumentos();
    }
    return _conductorDocumentos();
  }

  Widget _conductorDocumentos() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 560;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos del conductor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Monitorea tus documentos obligatorios y consulta las fechas de vencimiento.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
              const SizedBox(height: 20),
              _buildDocumentStrip(isCompact: isCompact),
              const SizedBox(height: 28),
              _buildDocumentList(isCompact: isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentStrip({required bool isCompact}) {
    final double cardWidth = isCompact ? 180 : 200;
    return SizedBox(
      height: isCompact ? 150 : 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _documents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final _DocumentInfo doc = _documents[index];
          final int days = doc.daysRemaining;
          final bool isNearExpiry = days <= 30;
          return GestureDetector(
            onTap: () => _openModal(doc),
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    isNearExpiry ? const Color(0xFFFF6B6B) : _accentColor,
                    isNearExpiry ? const Color(0xFFFF8E53) : _accentColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          doc.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    days > 0 ? '$days días restantes' : 'Vencido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Vence: ${_formatDate(doc.expiryDate)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (doc.paymentDate != null)
                    Text(
                      'Pagado: ${_formatDate(doc.paymentDate!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentList({required bool isCompact}) {
    return Column(
      children: _documents.map((doc) {
        final bool isExpired = doc.daysRemaining < 0;
        final bool isNearExpiry = doc.daysRemaining <= 30;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _cardColor.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            title: Text(
              doc.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildChip(
                    label: isExpired
                        ? 'Documento vencido'
                        : 'Vence el ${_formatDate(doc.expiryDate)}',
                    highlight: isNearExpiry || isExpired,
                  ),
                  if (doc.paymentDate != null)
                    _buildChip(
                      label: 'Pagado el ${_formatDate(doc.paymentDate!)}',
                      highlight: false,
                    ),
                  _buildChip(
                    label: '${doc.daysRemaining.clamp(0, 999)} días restantes',
                    highlight: isNearExpiry,
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.visibility_rounded, color: Colors.white70),
              onPressed: () => _openModal(doc),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChip({required String label, required bool highlight}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? _accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? _chipBorderColor : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _empresaDocumentos() {
    return _buildComingSoon('empresa');
  }

  Widget _propietarioDocumentos() {
    return _buildComingSoon('propietario');
  }

  Widget _secretariaDocumentos() {
    return _buildComingSoon('secretaria');
  }

  Widget _adminDocumentos() {
    return _buildComingSoon('administrador');
  }

  Widget _buildComingSoon(String roleLabel) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          'Panel de documentos para $roleLabel en desarrollo',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _openModal(_DocumentInfo doc) {
    DocumentModal.show(
      context: context,
      documentName: doc.name,
      paymentDate: doc.paymentDate,
      expiryDate: doc.expiryDate,
    );
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
