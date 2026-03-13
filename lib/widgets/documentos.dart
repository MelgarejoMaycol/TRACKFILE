import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/document_service.dart';
import 'document_modal.dart';
import 'upload_document_modal.dart';

class DocumentosWidget extends StatefulWidget {
  final String? role;
  final String? jsonPath;
  final String? userId;
  final String? token;
  final bool canUpload;

  const DocumentosWidget({
    super.key,
    this.role,
    this.jsonPath,
    this.userId,
    this.token,
    this.canUpload = false,
  });

  @override
  State<DocumentosWidget> createState() => _DocumentosWidgetState();
}

class _DocumentInfo {
  final String name;
  final DateTime expiryDate;
  final DateTime? paymentDate;
  final bool important;
  final String category; // tipo de documento (SOAT, Licencia, etc.)
  final String ownerId; // id del conductor/propietario/empresa
  final String ownerType; // 'empresa' | 'conductor' | 'propietario' | 'vehiculo'
  final String ownerName; // nombre para agrupar
  final String vehicleId; // id del vehículo si aplica
  final String vehiclePlate; // placa del vehículo si aplica

  const _DocumentInfo({
    required this.name,
    required this.expiryDate,
    this.paymentDate,
    this.important = false,
    this.category = 'General',
    this.ownerId = '',
    this.ownerType = 'empresa',
    this.ownerName = '',
    this.vehicleId = '',
    this.vehiclePlate = '',
  });

  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;

  bool get isNearExpiry => daysRemaining <= 30 && daysRemaining >= 0;
  bool get isExpired => daysRemaining < 0;
}

enum _EmpresaFilter { all, important, nearExpiry, expired, paid }

class _DocumentosWidgetState extends State<DocumentosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);
  static const Color _cardColor = Color(0xFF1B1F6B);

  bool _isLoading = true;
  late String _role;
  String? _authToken; // Token obtenido de SharedPreferences si es necesario
  List<_DocumentInfo> _documents = const [];
  final List<Map<String, String>> _vehicles = [];
  // Quick search UI state
  final List<String> _quickDocTypes = ['Personal', 'Tecnicomecánico', 'Licencia', 'Póliza', 'SOAT'];
  String _selectedQuickType = 'Personal';
  final TextEditingController _empresaSearchController = TextEditingController();
  List<_DocumentInfo> _quickResults = [];
  bool _showQuickResults = false;

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? 'Conductor').toLowerCase();
    _initializeToken();
  }

  Future<void> _initializeToken() async {
    // Usar token pasado, o intentar obtenerlo de SharedPreferences
    if (widget.token != null && widget.token!.isNotEmpty) {
      _authToken = widget.token;
      debugPrint('🔐 Usando token pasado al widget');
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        _authToken = prefs.getString('auth_token');
        if (_authToken != null && _authToken!.isNotEmpty) {
          debugPrint('🔐 Token obtenido de SharedPreferences (${_authToken!.length} chars)');
        } else {
          debugPrint('⚠️ No hay token disponible en SharedPreferences');
          _authToken = null;
        }
      } catch (e) {
        debugPrint('❌ Error obteniendo token: $e');
        _authToken = null;
      }
    }
    
    // Cargar documentos una vez que tenemos el token
    _loadDocuments();
  }

  @override
  void dispose() {
    _empresaSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    List<_DocumentInfo> parsed = [];
    
    // Primero intentar cargar desde la API si tenemos userId y token
    if (widget.userId != null && widget.userId!.isNotEmpty && _authToken != null) {
      try {
        debugPrint('📡 Cargando documentos desde API para usuario: ${widget.userId}');
        final documents = await DocumentService.getDocuments(
          userId: widget.userId!,
          token: _authToken,
        );

        if (documents.isNotEmpty) {
          parsed = _convertApiDocumentsToDocumentInfo(documents);
          debugPrint('✅ Se cargaron ${documents.length} documentos desde API');
        }
      } catch (e) {
        debugPrint('⚠️ Error cargando desde API: $e, intentando JSON...');
      }
    }

    // Si no hay datos de API o hay jsonPath definido, cargar desde JSON
    if (parsed.isEmpty && widget.jsonPath != null) {
      try {
        final String jsonString = await rootBundle.loadString(widget.jsonPath!);
        final dynamic decoded = json.decode(jsonString);

        // company-level documents
        final List<dynamic>? docs = decoded is Map<String, dynamic> ? decoded['documents'] as List<dynamic>? : null;
        if (docs != null) {
          parsed.addAll(docs.map((dynamic item) {
            if (item is Map<String, dynamic>) {
              final String name = (item['name'] ?? 'Documento').toString();
              final String category = (item['category'] ?? 'General').toString();
              final DateTime? expiry = DateTime.tryParse((item['expiryDate'] ?? '').toString());
              final DateTime? payment = DateTime.tryParse((item['paymentDate'] ?? '').toString());
              final bool important = item['important'] == true;
              return expiry != null
                  ? _DocumentInfo(
                      name: name,
                      expiryDate: expiry,
                      paymentDate: payment,
                      important: important,
                      category: category,
                      ownerId: (item['ownerId'] ?? '').toString(),
                      ownerType: 'empresa',
                      ownerName: (decoded['companyName'] ?? '').toString(),
                      vehiclePlate: (item['vehicle'] ?? item['vehiclePlate'] ?? '').toString(),
                    )
                  : null;
            }
            return null;
          }).whereType<_DocumentInfo>());
        }

        // driver-level documents
        final List<dynamic>? drivers = decoded is Map<String, dynamic> ? decoded['drivers'] as List<dynamic>? : null;
        if (drivers != null) {
          for (final dynamic d in drivers) {
            if (d is Map<String, dynamic>) {
              final String driverId = (d['id'] ?? d['userId'] ?? '').toString();
              final String driverName = (d['name'] ?? '').toString();
              final List<dynamic>? ddocs = d['documents'] as List<dynamic>? ?? d['docs'] as List<dynamic>?;
              if (ddocs != null) {
                parsed.addAll(ddocs.map((dynamic item) {
                  if (item is Map<String, dynamic>) {
                    final String name = (item['name'] ?? 'Documento').toString();
                    final String category = (item['category'] ?? 'General').toString();
                    final DateTime? expiry = DateTime.tryParse((item['expiryDate'] ?? '').toString());
                    final DateTime? payment = DateTime.tryParse((item['paymentDate'] ?? '').toString());
                    final bool important = item['important'] == true;
                    final String vehicle = (item['vehicle'] ?? item['vehiclePlate'] ?? '').toString();
                    return expiry != null
                        ? _DocumentInfo(
                            name: name,
                            expiryDate: expiry,
                            paymentDate: payment,
                            important: important,
                            category: category,
                            ownerId: driverId,
                            ownerType: 'conductor',
                            ownerName: driverName,
                            vehiclePlate: vehicle,
                          )
                        : null;
                  }
                  return null;
                }).whereType<_DocumentInfo>());
              }
            }
          }
        }

        // owner-level documents
        final List<dynamic>? owners = decoded is Map<String, dynamic> ? decoded['owners'] as List<dynamic>? : null;
        if (owners != null) {
          for (final dynamic o in owners) {
            if (o is Map<String, dynamic>) {
              final String ownerId = (o['id'] ?? '').toString();
              final String ownerName = (o['name'] ?? '').toString();
              final List<dynamic>? odocs = o['documents'] as List<dynamic>? ?? o['docs'] as List<dynamic>?;
              if (odocs != null) {
                parsed.addAll(odocs.map((dynamic item) {
                  if (item is Map<String, dynamic>) {
                    final String name = (item['name'] ?? 'Documento').toString();
                    final String category = (item['category'] ?? 'General').toString();
                    final DateTime? expiry = DateTime.tryParse((item['expiryDate'] ?? '').toString());
                    final DateTime? payment = DateTime.tryParse((item['paymentDate'] ?? '').toString());
                    final bool important = item['important'] == true;
                    final String vehicle = (item['vehicle'] ?? item['vehiclePlate'] ?? '').toString();
                    return expiry != null
                        ? _DocumentInfo(
                            name: name,
                            expiryDate: expiry,
                            paymentDate: payment,
                            important: important,
                            category: category,
                            ownerId: ownerId,
                            ownerType: 'propietario',
                            ownerName: ownerName,
                            vehiclePlate: vehicle,
                          )
                        : null;
                  }
                  return null;
                }).whereType<_DocumentInfo>());
              }
            }
          }
        }

        // vehicles (for propietario dashboards)
        final List<dynamic>? vehiclesJson = decoded is Map<String, dynamic> ? decoded['vehicles'] as List<dynamic>? : null;
        if (vehiclesJson != null) {
          for (final dynamic v in vehiclesJson) {
            if (v is Map<String, dynamic>) {
              final String plate = (v['plate'] ?? v['vehicle'] ?? '').toString();
              final String model = (v['model'] ?? '').toString();
              final String driver = (v['driver'] ?? '').toString();
              final String status = (v['status'] ?? '').toString();
              _vehicles.add({
                'plate': plate,
                'model': model,
                'driver': driver,
                'status': status,
                'nextExpiry': (v['nextExpiry'] ?? '').toString(),
              });
            }
          }
        }

      } catch (e) {
        debugPrint('Error cargando documentos desde JSON: $e');
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
      // If we're in the company view, run the quick search automatically so
      // the UI shows grouped personal documents on first load.
      if (_role == 'empresa') {
        _performQuickSearch();
      }
    }
    // Debug: log counts so developer can confirm data loaded when running app
    debugPrint('DocumentosWidget: loaded ${parsed.length} documents, vehicles: ${_vehicles.length}');
  }

  List<_DocumentInfo> _convertApiDocumentsToDocumentInfo(List<Map<String, dynamic>> documents) {
    return documents.map((doc) {
      final String name = doc['nombreTipo'] ?? doc['nombre'] ?? 'Documento';
      final String category = doc['area'] ?? 'General';
      final DateTime? expiry = doc['fechaVencimiento'] != null
          ? DateTime.tryParse(doc['fechaVencimiento'].toString())
          : null;
      
      if (expiry != null) {
        return _DocumentInfo(
          name: name,
          expiryDate: expiry,
          paymentDate: null,
          important: false,
          category: category,
          ownerId: doc['usuarioId']?.toString() ?? '',
          ownerType: 'usuario',
          ownerName: doc['usuarioNombre'] ?? 'Usuario',
          vehicleId: doc['vehiculoId']?.toString() ?? '',
          vehiclePlate: doc['placa'] ?? '',
        );
      }
      return null;
    }).whereType<_DocumentInfo>().toList();
  }

  List<_DocumentInfo> _exampleDocuments() {
    final DateTime now = DateTime.now();
    final Random rnd = Random(42);

    final List<String> firstNames = ['Carlos', 'María', 'Juan', 'Ana', 'Luis', 'Sofía', 'Andrés', 'Lucía', 'Diego', 'Camila', 'Pedro', 'Valentina', 'Ricardo', 'Paula', 'Héctor', 'Marta', 'Enzo', 'Daniela', 'Javier', 'Laura'];
    final List<String> lastNames = ['García', 'Pérez', 'Rodríguez', 'González', 'Martínez', 'López', 'Sánchez', 'Ramírez', 'Torres', 'Flores'];
    final List<String> plates = List.generate(40, (i) => 'ABC-${1000 + i}');
    final List<String> docTypes = ['SOAT', 'Tecnicomecánico', 'Póliza', 'Tarjeta de Operación'];

    final List<_DocumentInfo> generated = [];

    // Create many people with vehicle documents
    for (int i = 0; i < 40; i++) {
      final String ownerName = '${firstNames[rnd.nextInt(firstNames.length)]} ${lastNames[rnd.nextInt(lastNames.length)]}';
      final String ownerId = 'p${i + 1}';
      final String plate = plates[i % plates.length];
      final int docsForOwner = 2 + rnd.nextInt(3); // 2..4 documents

      for (int j = 0; j < docsForOwner; j++) {
        final String type = docTypes[rnd.nextInt(docTypes.length)];
        final int offsetDays = -120 + rnd.nextInt(480); // from -120 to +359 days
        final DateTime expiry = now.add(Duration(days: offsetDays));
        final DateTime payment = now.subtract(Duration(days: rnd.nextInt(180)));
        final bool important = rnd.nextDouble() < 0.08; // some are important

        generated.add(_DocumentInfo(
          name: type,
          expiryDate: expiry,
          paymentDate: rnd.nextBool() ? payment : null,
          important: important,
          category: type,
          ownerId: ownerId,
          ownerType: 'conductor',
          ownerName: ownerName,
          vehicleId: 'v${i + 1}',
          vehiclePlate: plate,
        ));
      }
    }

    // Add a few company-level fleet documents
    for (int k = 0; k < 8; k++) {
      final int offset = 30 + k * 30;
      generated.add(_DocumentInfo(
        name: 'Póliza Flota #${k + 1}',
        expiryDate: now.add(Duration(days: offset)),
        paymentDate: now.subtract(Duration(days: 30)),
        important: k % 3 == 0,
        category: 'Póliza',
        ownerId: 'empresa',
        ownerType: 'empresa',
        ownerName: 'Mi Empresa',
      ));
    }

    generated.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return generated;
  }

  // Sample owner documents used for preview when there are no real owner documents
  List<_DocumentInfo> _sampleOwnerDocs() {
    final DateTime now = DateTime.now();
    const String ownerId = 'prop-demo';
    const String ownerName = 'Propietario Ejemplo';

    final List<String> plates = ['ABC-123', 'XYZ-987', 'LMN-456', 'QWE-741'];
    final List<_DocumentInfo> docs = [];

    // Personal documents
    docs.addAll([
      _DocumentInfo(
        name: 'Cédula de ciudadanía',
        expiryDate: now.add(const Duration(days: 45)),
        important: false,
        category: 'Identificación',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
      _DocumentInfo(
        name: 'Licencia de conducción',
        expiryDate: now.add(const Duration(days: 365)),
        important: false,
        category: 'Licencia',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
      _DocumentInfo(
        name: 'Certificado médico',
        expiryDate: now.subtract(const Duration(days: 10)), // already expired
        important: true,
        category: 'Salud',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
      _DocumentInfo(
        name: 'Registro RUT',
        expiryDate: now.add(const Duration(days: 210)),
        important: false,
        category: 'Registro',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
    ]);

    // Reemplazamos documentos de vehículo por documentos personales/descriptivos
    docs.addAll([
      _DocumentInfo(
        name: 'Registro Único Tributario (RUT) #0123456789',
        expiryDate: now.add(const Duration(days: 210)),
        important: false,
        category: 'Registro',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
      _DocumentInfo(
        name: 'Certificado de afiliación EPS',
        expiryDate: now.add(const Duration(days: 365)),
        category: 'Salud',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
      _DocumentInfo(
        name: 'Certificado médico ocupacional',
        expiryDate: now.subtract(const Duration(days: 10)),
        important: true,
        category: 'Salud',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
      _DocumentInfo(
        name: 'Licencia de conducción - Categoría B',
        expiryDate: now.add(const Duration(days: 365)),
        category: 'Licencia',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ),
    ]);

    // A few extra miscellaneous docs to stress-test the UI
    for (int k = 0; k < 6; k++) {
      docs.add(_DocumentInfo(
        name: 'Documento extra #${k + 1}',
        expiryDate: now.add(Duration(days: 5 + k * 12 - (k % 2 == 0 ? 30 : 0))),
        important: k % 3 == 0,
        category: k % 2 == 0 ? 'General' : 'Otro',
        ownerId: ownerId,
        ownerType: 'propietario',
        ownerName: ownerName,
      ));
    }

    docs.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget contentWidget = _buildContentByRole();
    
    // Solo mostrar botón de subir si es empresa y canUpload es true
    if (!widget.canUpload || _role != 'empresa') {
      return contentWidget;
    }

    // Si podemos subir, envolver en un Stack con FAB
    return Stack(
      children: [
        contentWidget,
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: _showUploadModal,
            backgroundColor: const Color(0xFF4F4CE8),
            child: const Icon(Icons.upload_file, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildContentByRole() {
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

  void _showUploadModal() {
    if (!widget.canUpload || widget.userId == null || widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No tienes permiso para subir documentos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    UploadDocumentModal.show(
      context: context,
      userId: widget.userId!,
      userRole: _role,
      token: _authToken,
      onSuccess: () {
        // Recargar documentos después de subida exitosa
        _loadDocuments();
      },
    );
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
              _buildDocumentStrip(isCompact: isCompact),
              const SizedBox(height: 28),
              _buildDocumentList(isCompact: isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentStrip({required bool isCompact, List<_DocumentInfo>? docs, bool showIcon = false, Color? overrideStart, Color? overrideEnd, bool forceColor = false}) {
    final List<_DocumentInfo> items = docs ?? _documents;
    final double cardWidth = isCompact ? 170 : 190;
    return SizedBox(
      height: isCompact ? 140 : 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final _DocumentInfo doc = items[index];
          final int days = doc.daysRemaining;
          final bool isNearExpiry = doc.isNearExpiry || doc.isExpired;
          final bool highlight = doc.important || isNearExpiry;

            final bool useOverride = forceColor && overrideStart != null && overrideEnd != null;
            final Color startColor = useOverride
              ? overrideStart
              : (highlight ? const Color(0xFFFF6B6B) : (overrideStart ?? _accentColor));
            final Color endColor = useOverride
              ? overrideEnd
              : (highlight ? const Color(0xFFFF8E53) : (overrideEnd ?? _accentColor.withValues(alpha: 0.7)));

          return GestureDetector(
            onTap: () => _openModal(doc),
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [startColor, endColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showIcon) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.description, color: Colors.white70, size: isCompact ? 16 : 18),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          doc.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 13 : 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doc.important)
                        const Icon(Icons.push_pin, color: Colors.white, size: 16)
                      else
                        const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    doc.isExpired ? 'Vencido' : '${doc.daysRemaining.clamp(0, 999)} días restantes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doc.vehiclePlate.isNotEmpty ? doc.vehiclePlate : doc.ownerName,
                          style: TextStyle(color: Colors.white70, fontSize: isCompact ? 11 : 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        doc.category,
                        style: TextStyle(color: Colors.white60, fontSize: isCompact ? 10 : 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (doc.paymentDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Pagado: ${_formatDate(doc.paymentDate!)}',
                      style: TextStyle(color: Colors.white60, fontSize: isCompact ? 10 : 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentList({required bool isCompact, List<_DocumentInfo>? docs}) {
    final List<_DocumentInfo> items = docs ?? _documents;
    return Column(
      children: items.map((doc) {
        final bool isExpired = doc.isExpired;
        final bool isNearExpiry = doc.isNearExpiry;
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
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (doc.important)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Text('Importante', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildChip(
                    label: isExpired ? 'Documento vencido' : 'Vence el ${_formatDate(doc.expiryDate)}',
                    highlight: isNearExpiry || isExpired,
                  ),
                  _buildChip(
                    label: '${doc.daysRemaining.clamp(0, 999)} días restantes',
                    highlight: isNearExpiry,
                  ),
                  if (doc.paymentDate != null)
                    _buildChip(
                      label: 'Pagado el ${_formatDate(doc.paymentDate!)}',
                      highlight: false,
                    ),
                  _buildChip(label: doc.category, highlight: false),
                  if (doc.ownerName.isNotEmpty) _buildChip(label: doc.ownerName, highlight: false),
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

  Widget _buildGroupedList({required bool isCompact, required List<_DocumentInfo> docs, bool showProgress = false, int totalDocs = 6}) {
    final Map<String, List<_DocumentInfo>> grouped = {};
    for (final d in docs) {
      final String key = d.ownerName.isNotEmpty ? '${d.ownerName} (${d.ownerType})' : 'Empresa';
      grouped.putIfAbsent(key, () => []).add(d);
    }

    final entries = grouped.entries.toList();
    return Column(
      children: entries.map((entry) {
        final String person = entry.key;
        final List<_DocumentInfo> items = entry.value;
        final int completed = items.length;
        final int total = totalDocs <= 0 ? 1 : totalDocs;
        final double progress = (completed / total).clamp(0.0, 1.0);
        final Color barColor = progress >= 1 ? const Color(0xFF16C79A) : const Color(0xFFFF8E53);
        return ExpansionTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A3BF0), Color(0xFF6C63FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white12,
                      child: const Icon(Icons.person, color: Colors.white70, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        person,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$completed', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completed de $total documentos',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildDocumentList(isCompact: isCompact, docs: items),
            ),
            const SizedBox(height: 12),
          ],
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

  // --- Empresa documents panel (search, filters, highlighting) ---

  _EmpresaFilter _selectedEmpresaFilter = _EmpresaFilter.all;
  String _empresaSearch = '';
  String _propietarioSearch = '';
  bool _empresaSortAscending = true;

  // Additional filters
  String _selectedDocType = 'Todos';
  String _selectedPerson = 'Todos';

  // Date range filter for empresa view
  DateTimeRange? _selectedDateRange;

  // Vehicle-related document keywords (used to restrict docs for company view)
  static const List<String> _vehicleDocKeywords = [
    'soat',
    'tecnicomecanico',
    'tecnicomecánico',
    'poliza',
    'póliza',
    'seguro',
    'tarjeta de operación',
    'tarjeta de operacion',
    'revision',
    'revisión',
  ];

  bool _isVehicleDocument(_DocumentInfo d) {
    final String text = '${d.category} ${d.name}'.toLowerCase();
    return _vehicleDocKeywords.any((k) => text.contains(k));
  }

  List<String> get _availableDocTypes {
    final Set<String> types = {'Todos'};
    for (final d in _documents) {
      if (_role == 'empresa') {
        // Include categories for documents belonging to drivers or propietarios so empresa can filter by them
        if (d.ownerType == 'conductor' || d.ownerType == 'propietario') types.add(d.category);
      } else {
        types.add(d.category);
      }
    }
    final List<String> result = types.toList();
    result.sort((a,b) {
      if (a=='Todos') return -1;
      if (b=='Todos') return 1;
      return a.compareTo(b);
    });
    return result;
  }

  List<String> get _availablePeople {
    final Set<String> people = {'Todos'};
    for (final d in _documents) {
      final name = (d.ownerName.isNotEmpty) ? '${d.ownerName} (${d.ownerType})' : d.ownerType;
      people.add(name);
    }
    return people.toList();
  }

  List<String> get _availableVehicles {
    final Set<String> vehicles = {'Todos'};
    for (final d in _documents) {
      if (d.vehiclePlate.isNotEmpty) vehicles.add(d.vehiclePlate);
    }
    return vehicles.toList();
  }

  final String _selectedVehicle = 'Todos';

  bool _groupByPerson = false; // toggle to group documents by owner

  // --- Helpers for filter presets and reset ---
  void _resetEmpresaFilters() {
    setState(() {
      _empresaSearch = '';
      _selectedDocType = 'Todos';
      _selectedPerson = 'Todos';
      _selectedDateRange = null;
      _selectedEmpresaFilter = _EmpresaFilter.all;
      _empresaSortAscending = true;
      _groupByPerson = false;
    });
  }

  DateTimeRange _presetDateRange(int days) {
    final DateTime start = DateTime.now();
    final DateTime end = start.add(Duration(days: days));
    return DateTimeRange(start: start, end: end);
  }

  Widget _empresaDocumentos() { 
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 560;
        final List<_DocumentInfo> filtered = _filteredEmpresaDocuments();
        // For empresa view, focus on personal documents (drivers/owners).
        final List<_DocumentInfo> personalDocs = filtered.where((d) => d.ownerType == 'conductor' || d.ownerType == 'propietario').toList();
        // Documents that are near expiry (but not yet expired)
        final List<_DocumentInfo> nearExpiryDocs = personalDocs.where((d) => d.isNearExpiry && !d.isExpired).toList();
        // Important or already expired documents for quick highlights
        final List<_DocumentInfo> highlightDocs = personalDocs.where((d) => d.important || d.isExpired).toList();
        // Main document list: show personal documents excluding the near-expiry ones (already shown above)
        final List<_DocumentInfo> remaining = personalDocs.where((d) => !nearExpiryDocs.contains(d)).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos de la empresa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Filtra, busca y prioriza los documentos de vehículos (SOAT, Tecnicomecánico, Pólizas, etc.) de tu empresa.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
              ),
              const SizedBox(height: 16),

              // Controls: main search + quick-search selector and magnifier
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, propietario o placa',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (v) => setState(() => _empresaSearch = v.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => setState(() => _empresaSortAscending = !_empresaSortAscending),
                          icon: Icon(_empresaSortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 12),

              // Quick-search row: type selector + small query + magnifier
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedQuickType,
                      dropdownColor: _cardColor,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(color: Colors.white),
                      items: _quickDocTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setState(() { if (v != null) _selectedQuickType = v; }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 12),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: _performQuickSearch,
                      icon: const Icon(Icons.search, color: Colors.white70),
                    ),
                  ),
                  if (_showQuickResults) ...[
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(10)),
                      child: IconButton(
                        onPressed: () => setState(() => _showQuickResults = false),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
                ],
              ),

              // Highlights strip: important / expired documents
              if (highlightDocs.isNotEmpty) ...[
                _buildDocumentStrip(isCompact: isCompact, docs: highlightDocs, showIcon: true),
                const SizedBox(height: 20),
              ],

              // Section: Próximamente a vencer (personal)
              if (nearExpiryDocs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('Próximamente a vencer', style: TextStyle(color: Colors.white, fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w600)),
                ),
                _buildDocumentStrip(isCompact: isCompact, docs: nearExpiryDocs, showIcon: true),
                const SizedBox(height: 20),
              ],

              // Document list (grouped or flat)
              if (_showQuickResults) ...[
                _buildGroupedList(isCompact: isCompact, docs: _quickResults, showProgress: true, totalDocs: 6),
              ] else if (_groupByPerson) ...[
                _buildGroupedList(isCompact: isCompact, docs: remaining, showProgress: true, totalDocs: 6),
              ] else ...[
                _buildDocumentList(isCompact: isCompact, docs: remaining),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<_DocumentInfo> _filteredEmpresaDocuments() {
    final String q = _empresaSearch.trim().toLowerCase();
    List<_DocumentInfo> list = List<_DocumentInfo>.from(_documents);

    // For empresa view, show all documents that belong to drivers or propietarios so the company can review them
    if (_role == 'empresa') {
      list = list.where((d) => d.ownerType == 'conductor' || d.ownerType == 'propietario').toList();
    }

    // filter by selected date range (expiry date)
    if (_selectedDateRange != null) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end;
      list = list.where((d) => !d.expiryDate.isBefore(start) && !d.expiryDate.isAfter(end)).toList();
    }

    // apply quick filters
    if (_selectedEmpresaFilter == _EmpresaFilter.important) {
      list = list.where((d) => d.important).toList();
    } else if (_selectedEmpresaFilter == _EmpresaFilter.nearExpiry) {
      list = list.where((d) => d.isNearExpiry && !d.isExpired).toList();
    } else if (_selectedEmpresaFilter == _EmpresaFilter.expired) {
      list = list.where((d) => d.isExpired).toList();
    } else if (_selectedEmpresaFilter == _EmpresaFilter.paid) {
      list = list.where((d) => d.paymentDate != null).toList();
    }

    // filter by document type
    if (_selectedDocType.isNotEmpty && _selectedDocType != 'Todos') {
      list = list.where((d) => d.category == _selectedDocType).toList();
    }

    // filter by person
    if (_selectedPerson.isNotEmpty && _selectedPerson != 'Todos') {
      list = list.where((d) {
        final String name = (d.ownerName.isNotEmpty) ? '${d.ownerName} (${d.ownerType})' : d.ownerType;
        return name == _selectedPerson;
      }).toList();
    }

    // search
    if (q.isNotEmpty) {
      list = list.where((d) => d.name.toLowerCase().contains(q) || d.ownerName.toLowerCase().contains(q)).toList();
    }

    list.sort((a, b) => _empresaSortAscending ? a.expiryDate.compareTo(b.expiryDate) : b.expiryDate.compareTo(a.expiryDate));
    return list;
  }

  void _performQuickSearch() {
    // Quick search by selected type only (no typing). Show documents grouped by person.
    final String selected = _selectedQuickType.trim();
    List<_DocumentInfo> candidates = _documents.where((d) => d.ownerType == 'conductor' || d.ownerType == 'propietario').toList();

    final List<_DocumentInfo> results = candidates.where((d) {
      if (selected == 'Personal') return true; // all personal documents
      return d.category.toLowerCase().contains(selected.toLowerCase());
    }).toList();

    results.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    setState(() {
      _quickResults = results;
      _showQuickResults = true;
      _groupByPerson = true;
    });
  }

  Widget _propietarioDocumentos() {
  bool isOwnerDoc(_DocumentInfo d) {
    final t = d.ownerType.trim().toLowerCase();
    return t == 'propietario';
  }

  // Helper to detect vehicle-related documents (re-using empresa helper logic)
  bool isVehicleDoc(_DocumentInfo d) => _isVehicleDocument(d);

  return LayoutBuilder(
    builder: (context, constraints) {
      final bool isCompact = constraints.maxWidth < 560;

      List<_DocumentInfo> ownerDocs = _documents.where(isOwnerDoc).toList();
      final bool usingExampleData = ownerDocs.isEmpty;
      if (usingExampleData) {
        ownerDocs = _sampleOwnerDocs();
      }

      final int totalDocs = 6;
      final int completedDocs = ownerDocs.length;
      final double progress = (completedDocs / (totalDocs <= 0 ? 1 : totalDocs)).clamp(0.0, 1.0);
      final Color barColor = progress >= 1 ? const Color(0xFF16C79A) : const Color(0xFFFF8E53);

      // Próximos documentos a vencer (top 3)
      final List<_DocumentInfo> upcomingDocs = ownerDocs
          .where((d) => !d.isExpired)
          .toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      final List<_DocumentInfo> topUpcoming = upcomingDocs.take(3).toList();

      // Aplicar búsqueda (si existe) para filtrar documentos del propietario
      if (_propietarioSearch.isNotEmpty) {
        final String s = _propietarioSearch;
        ownerDocs = ownerDocs.where((d) =>
          d.name.toLowerCase().contains(s) ||
          d.category.toLowerCase().contains(s) ||
          d.ownerName.toLowerCase().contains(s) ||
          d.vehiclePlate.toLowerCase().contains(s)
        ).toList();
      }

      // Documentos personales: todos los documentos del propietario que no están relacionados con vehículos.
      final List<_DocumentInfo> personalOwnerDocs = ownerDocs.where((d) => d.vehiclePlate.isEmpty && !isVehicleDoc(d)).toList();

      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 24,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.task_alt, color: Color(0xFFFF8E53), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Documentos registrados: $completedDocs de $totalDocs',
                        style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Documentos del propietario',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 18 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            if (topUpcoming.isNotEmpty) ...[
              Text(
                'Próximos vencimientos',
                style: TextStyle(color: Colors.white, fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _buildDocumentStrip(
                isCompact: isCompact,
                docs: topUpcoming,
                showIcon: true,
                overrideStart: const Color(0xFFFF8E53),
                overrideEnd: const Color(0xFFFFB347),
                forceColor: true,
              ),
              const SizedBox(height: 16),
            ],

            // Barra de búsqueda para documentos del propietario
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar documentos (nombre, categoría, propietario, placa)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => setState(() => _propietarioSearch = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 12),

            // 2) Documentos personales del propietario (mostrar como tarjetas verticales)
            if (personalOwnerDocs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Documentos personales', style: TextStyle(color: Colors.white, fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w600)),
              ),
              // Mostrar todos los documentos personales del propietario como tarjetas en lista vertical,
              // en lugar de agruparlos por persona (comportamiento solicitado por el usuario).
              _buildDocumentList(isCompact: isCompact, docs: personalOwnerDocs),
              const SizedBox(height: 20),
            ],

            // 3) Sección de vehículos removida: los documentos relacionados con vehículos no se muestran
            // en este panel por solicitud del usuario. Todos los documentos personales del propietario
            // se muestran arriba como tarjetas para facilitar la visualización.

            // If there are no vehicles and we haven't shown personal docs, show grouped owner list as fallback
            if (_vehicles.isEmpty && personalOwnerDocs.isEmpty) ...[
              _buildGroupedList(isCompact: isCompact, docs: ownerDocs),
            ],

            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
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

  Widget _buildSummaryRow(List<_DocumentInfo> docs) {
    final int total = docs.length;
    final int expiring = docs.where((d) => d.isNearExpiry && !d.isExpired).length;
    final int expired = docs.where((d) => d.isExpired).length;
    final int important = docs.where((d) => d.important).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSummaryCard('Total', total.toString(), Colors.white24),
        _buildSummaryCard('Por vencer', expiring.toString(), const Color(0xFFFF8E53)),
        _buildSummaryCard('Vencidos', expired.toString(), const Color(0xFFFF6B6B)),
        _buildSummaryCard('Importantes', important.toString(), _accentColor),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
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
