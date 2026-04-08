import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/document_service.dart';
import 'document_modal.dart';
import 'upload_document_modal.dart';
import 'shimmer_skeleton.dart';

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
  final DateTime? creationDate;
  final bool important;
  final String category; // tipo de documento (SOAT, Licencia, etc.)
  final String ownerId; // id del conductor/propietario/empresa
  final String ownerType; // 'empresa' | 'conductor' | 'propietario' | 'vehiculo'
  final String ownerName; // nombre para agrupar
  final String vehicleId; // id del vehículo si aplica
  final String vehiclePlate; // placa del vehículo si aplica
  final int documentId; // id del documento
  final int idTipo; // id del tipo de documento

  const _DocumentInfo({
    required this.name,
    required this.expiryDate,
    this.creationDate,
    this.important = false,
    this.category = 'General',
    this.ownerId = '',
    this.ownerType = 'empresa',
    this.ownerName = '',
    this.vehicleId = '',
    this.vehiclePlate = '',
    this.documentId = 0,
    this.idTipo = 0,
  });

  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;

  bool get isNearExpiry => daysRemaining <= 30 && daysRemaining >= 0;
  bool get isExpired => daysRemaining < 0;
}

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
  final TextEditingController _empresaSearchController = TextEditingController();

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
    
    // Cargar desde la API según el rol del usuario
    if (_authToken != null && _authToken!.isNotEmpty) {
      try {
        debugPrint('📡 Cargando documentos para rol: $_role, userId: ${widget.userId}');
        
        final documents = await DocumentService.getDocumentsByRole(
          role: _role,
          userId: widget.userId,
          token: _authToken,
        );
        
        if (documents.isNotEmpty) {
          parsed = _convertApiDocumentsToDocumentInfo(documents);
          
          // Filtrar documentos según el rol
          if (_role != 'empresa' && widget.userId != null && widget.userId!.isNotEmpty) {
            final userIdInt = int.tryParse(widget.userId!);
            if (userIdInt != null) {
              debugPrint('📋 Filtrando documentos para $_role con userId: $userIdInt');
              parsed = parsed.where((doc) => doc.ownerId.toString() == userIdInt.toString()).toList();
              debugPrint('📊 Documentos filtrados: ${parsed.length} de ${documents.length}');
            }
          }
          
          debugPrint('✅ Se cargaron ${documents.length} documentos desde API');
          debugPrint('📊 Documentos convertidos y filtrados: ${parsed.length}');
        } else {
          debugPrint('ℹ️ No hay documentos disponibles');
        }
      } catch (e) {
        debugPrint('⚠️ Error cargando desde API: $e');
      }
    } else {
      debugPrint('⚠️ No hay token disponible - no se puede cargar desde API');
    }

    // Actualizar estado con los documentos cargados
    if (mounted) {
      setState(() {
        _documents = parsed;
        _isLoading = false;
      });
      
      debugPrint('📊 DocumentosWidget: loaded ${parsed.length} documents, vehicles: ${_vehicles.length}');
    }
  }

  List<_DocumentInfo> _convertApiDocumentsToDocumentInfo(List<Map<String, dynamic>> documents) {
    return documents.map((doc) {
      // Mapear campos del backend (DocumentoTablaResponse)
      final String name = doc['nombreTipoDocumento'] ?? doc['nombreTipo'] ?? doc['nombre'] ?? 'Documento';
      final String category = doc['area'] ?? 'General';
      
      DateTime? expiry;
      final dynamic fechaVencimiento = doc['fechaVencimiento'];
      if (fechaVencimiento != null) {
        expiry = DateTime.tryParse(fechaVencimiento.toString());
      }
      
      if (expiry != null) {
        // Determinar el nombre del propietario (puede ser conductor, propietario o usuario)
        String ownerName = 'Usuario';
        String ownerType = 'usuario';
        
        // Si tiene propietario (vehículo)
        if (doc['nombrePropietario'] != null && doc['nombrePropietario'].toString().isNotEmpty) {
          final nombre = doc['nombrePropietario'] ?? '';
          final apellido = doc['apellidoPropietario'] ?? '';
          ownerName = '$nombre ${apellido ?? ''}'.trim();
          ownerType = 'propietario';
        }
        // Si tiene usuario/conductor
        else if (doc['nombreUsuario'] != null && doc['nombreUsuario'].toString().isNotEmpty) {
          final nombre = doc['nombreUsuario'] ?? '';
          final apellido = doc['apellidoUsuario'] ?? '';
          ownerName = '$nombre ${apellido ?? ''}'.trim();
          ownerType = 'conductor';
        }
        
        final DateTime? creation = DateTime.tryParse((doc['fechaCreacion'] ?? '').toString());
        return _DocumentInfo(
          name: name,
          expiryDate: expiry,
          creationDate: creation,
          important: false,
          category: category,
          ownerId: doc['idUsuario']?.toString() ?? doc['idVehiculo']?.toString() ?? '',
          ownerType: ownerType,
          ownerName: ownerName,
          vehicleId: doc['idVehiculo']?.toString() ?? '',
          vehiclePlate: doc['placa'] ?? '',
          documentId: int.tryParse(doc['idDocumento']?.toString() ?? '0') ?? 0,
          idTipo: int.tryParse(doc['idTipo']?.toString() ?? '0') ?? 0,
        );
      }
      return null;
    }).whereType<_DocumentInfo>().toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildDocumentsLoadingState();
    }

    final Widget contentWidget = _buildContentByRole();
    
    // Solo mostrar botón de subir si es empresa y canUpload es true
    if (!widget.canUpload || _role != 'empresa') {
      return contentWidget;
    }

    // Si podemos subir, envolver en un Stack con FAB
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        Positioned.fill(
          child: contentWidget,
        ),
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

  Widget _buildDocumentsLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                ShimmerSkeleton(
                  width: 200,
                  height: 24,
                  borderRadius: 8,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 6),
                // Subtítulo
                ShimmerSkeleton(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 8,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                // Documentos skeleton
                Column(
                  children: List.generate(
                    5,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShimmerSkeleton(
                        width: double.infinity,
                        height: 110,
                        borderRadius: 12,
                        margin: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        
        // Si no hay documentos, mostrar mensaje
        if (_documents.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
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
                    const SizedBox(height: 40),
                    // Empty state
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.file_present_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyStateTitle(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getEmptyStateSubtitle(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isCompact ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (widget.canUpload) ...[
                          ElevatedButton.icon(
                            onPressed: _showUploadModal,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Agregar documento'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Próximos documentos a vencer
        final List<_DocumentInfo> upcomingDocs = _documents
            .where((d) => !d.isExpired)
            .toList()
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
        final List<_DocumentInfo> topUpcoming = upcomingDocs.take(3).toList();

        // Aplicar búsqueda
        List<_DocumentInfo> filteredDocs = _documents;
        if (_conductorSearch.isNotEmpty) {
          final String s = _conductorSearch;
          filteredDocs = filteredDocs.where((d) =>
            d.name.toLowerCase().contains(s) ||
            d.category.toLowerCase().contains(s) ||
            d.ownerName.toLowerCase().contains(s) ||
            d.vehiclePlate.toLowerCase().contains(s)
          ).toList();
        }
        
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
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
              
              // Próximos vencimientos
              if (topUpcoming.isNotEmpty) ...[
                Text(
                  'Próximos vencimientos',
                  style: TextStyle(color: Colors.white, fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildUpcomingDocumentStrip(isCompact: isCompact, docs: topUpcoming),
                const SizedBox(height: 16),
              ],

              // Buscador
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
                  onChanged: (v) => setState(() => _conductorSearch = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 12),
              
              // Lista de documentos
              _buildDocumentList(isCompact: isCompact, docs: filteredDocs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingDocumentStrip({required bool isCompact, required List<_DocumentInfo> docs}) {
    final double cardWidth = isCompact ? 170 : 190;
    return SizedBox(
      height: isCompact ? 140 : 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final _DocumentInfo doc = docs[index];
          final Map<String, Color> colors = _getColorForDaysRemaining(doc.daysRemaining);
          final Color startColor = colors['start']!;
          final Color endColor = colors['end']!;

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
                  if (doc.creationDate != null)
                    _buildChip(
                      label: 'Creado el ${_formatDate(doc.creationDate!)}',
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

  String _empresaSearch = '';
  String _propietarioSearch = '';
  String _conductorSearch = '';

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

  // Obtener color basado en días restantes para vencimiento
  Map<String, Color> _getColorForDaysRemaining(int daysRemaining) {
    if (daysRemaining < 0) {
      // Vencido: gris
      return {'start': const Color(0xFF6B7280), 'end': const Color(0xFF4B5563)};
    } else if (daysRemaining <= 7) {
      // Rojo urgente (0-7 días)
      return {'start': const Color(0xFFEF4444), 'end': const Color(0xFFDC2626)};
    } else if (daysRemaining <= 15) {
      // Naranja (8-15 días)
      return {'start': const Color(0xFFF97316), 'end': const Color(0xFFEA580C)};
    } else if (daysRemaining <= 30) {
      // Amarillo (16-30 días)
      return {'start': const Color(0xFFEAB308), 'end': const Color(0xFFFCD34D)};
    } else {
      // Verde (más de 30 días)
      return {'start': const Color(0xFF16A34A), 'end': const Color(0xFF22C55E)};
    }
  }

  Widget _empresaDocumentos() { 
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 560;
        final List<_DocumentInfo> filtered = _filteredEmpresaDocuments();
        // For empresa view, focus on personal documents (drivers/owners).
        final List<_DocumentInfo> personalDocs = filtered.where((d) => d.ownerType == 'conductor' || d.ownerType == 'propietario').toList();
        
        // Si no hay documentos en absoluto (antes de buscar)
        if (_documents.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
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
                      'Busca y visualiza los documentos de tus conductores y propietarios',
                      style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
                    ),
                    const SizedBox(height: 24),
                    // Empty state
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.file_present_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyStateTitle(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getEmptyStateSubtitle(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isCompact ? 12 : 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showUploadModal,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Agregar documento'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        
        // Si hay búsqueda pero no hay resultados
        if (_empresaSearch.isNotEmpty && personalDocs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
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
                      'Busca y visualiza los documentos de tus conductores y propietarios',
                      style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
                    ),
                    const SizedBox(height: 24),
                    // Buscador
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre de persona',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) => setState(() => _empresaSearch = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 40),
                    // No results state
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron personas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No hay resultados para "$_empresaSearch"',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isCompact ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Calcular documentos próximos a vencer (todos)
        final List<_DocumentInfo> upcomingAll = _documents
            .where((d) => !d.isExpired)
            .toList()
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
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
                'Busca y visualiza los documentos de tus conductores y propietarios',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
              ),
              const SizedBox(height: 16),

              // Documentos próximos a vencer (todos, sin importar de quién es)
              if (upcomingAll.isNotEmpty) ...[
                Text(
                  'Próximos a vencer',
                  style: TextStyle(color: Colors.white, fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildUpcomingDocumentStrip(isCompact: isCompact, docs: upcomingAll.take(5).toList()),
                const SizedBox(height: 24),
              ],

              // Solo buscador, sin filtros
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre de persona',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => setState(() => _empresaSearch = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 24),

              // Documentos agrupados por persona
              _buildGroupedList(isCompact: isCompact, docs: personalDocs, showProgress: false, totalDocs: personalDocs.length),
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

    // For empresa view, show all documents that belong to drivers or propietarios
    if (_role == 'empresa') {
      list = list.where((d) => d.ownerType == 'conductor' || d.ownerType == 'propietario').toList();
    }

    // Search only by owner name (persona name)
    if (q.isNotEmpty) {
      list = list.where((d) => d.ownerName.toLowerCase().contains(q)).toList();
    }

    // Sort by expiry date
    list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return list;
  }



  Widget _propietarioDocumentos() {
  // Helper to detect vehicle-related documents (re-using empresa helper logic)
  bool isVehicleDoc(_DocumentInfo d) => _isVehicleDocument(d);

  return LayoutBuilder(
    builder: (context, constraints) {
      final bool isCompact = constraints.maxWidth < 560;

      // _documents is already filtered by userId in _loadDocuments(), so use it directly
      // Don't re-filter by ownerType since it's determined by API response field population
      List<_DocumentInfo> ownerDocs = _documents;

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
              _buildUpcomingDocumentStrip(
                isCompact: isCompact,
                docs: topUpcoming,
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

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  // Método auxiliar para construir tarjetas resumen
  // Se usa a través de _buildSummaryRow
  // ignore: unused_element
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
      creationDate: doc.creationDate,
      expiryDate: doc.expiryDate,
      ownerName: doc.ownerName,
      area: doc.category,
      category: doc.name,
      vehiclePlate: doc.vehiclePlate,
      role: _role,
      daysRemaining: doc.daysRemaining,
    );
  }

  /// Retorna el título del estado vacío según el rol
  String _getEmptyStateTitle() {
    if (_role == 'empresa') {
      return 'No hay documentos registrados';
    } else {
      return 'No hay documentos';
    }
  }

  /// Retorna el subtítulo del estado vacío según el rol
  String _getEmptyStateSubtitle() {
    if (_role == 'empresa') {
      return 'Comienza a registrar documentos de tus conductores y propietarios';
    } else {
      return 'Próximamente la empresa agregará documentos o comunícate con la empresa';
    }
  }
}
