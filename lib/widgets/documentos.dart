import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/document_service.dart';
import 'document_modal.dart';
import 'edit_document_modal.dart';
import 'shimmer_skeleton.dart';
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
  final DateTime? creationDate;
  final bool important;
  final String category; // tipo de documento (SOAT, Licencia, etc.)
  final String ownerId; // id del conductor/propietario/empresa
  final String
  ownerType; // 'empresa' | 'conductor' | 'propietario' | 'vehiculo'
  final String
  ownerName; // nombre del propietario/conductor para documentos personales
  final String vehicleId; // id del vehículo si aplica
  final String vehiclePlate; // placa del vehículo si aplica
  final String
  conductorName; // nombre del conductor si es documento de vehículo
  final String
  propietarioName; // nombre del propietario si es documento de vehículo
  final String
  conductorUserId; // id del usuario conductor si es documento de vehículo
  final String
  propietarioUserId; // id del usuario propietario si es documento de vehículo
  final int documentId; // id del documento
  final int idTipo; // id del tipo de documento
  final String responsableUserId; // id del usuario responsable del documento
  final String responsableName; // nombre completo del responsable
  final String
  rolResponsable; // rol del responsable (EMPRESA, ADMIN, SECRETARIA, etc.)
  final String empresaNombre; // nombre de la empresa
  final String area; // área del documento (TECNICA, LEGAL, ADMINISTRATIVO)
  final String observaciones; // observaciones del documento
  final bool estadoDocumento; // true = activo, false = histórico

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
    this.conductorName = '',
    this.propietarioName = '',
    this.conductorUserId = '',
    this.propietarioUserId = '',
    this.documentId = 0,
    this.idTipo = 0,
    this.responsableUserId = '',
    this.responsableName = '',
    this.rolResponsable = '',
    this.empresaNombre = '',
    this.area = '',
    this.observaciones = '',
    this.estadoDocumento = true,
  });

  int get daysRemaining {
    // Calcular días usando solo fechas, sin considerar horas
    final DateTime todayOnly = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final DateTime expiryOnly = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return expiryOnly.difference(todayOnly).inDays;
  }

  bool get isNearExpiry => daysRemaining <= 30 && daysRemaining >= 0;
  bool get isExpired => daysRemaining < 0;
  bool get isPersonal =>
      vehicleId.isEmpty; // Documento personal si no tiene vehículo
  bool get isVehicleDocument =>
      vehicleId.isNotEmpty; // Documento de vehículo si tiene vehículo
}

class _DocumentosWidgetState extends State<DocumentosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);
  static const Color _cardColor = Color(0xFF1B1F6B);

  bool _isLoading = true;
  late String _role;
  String? _authToken; // Token obtenido de SharedPreferences si es necesario
  List<_DocumentInfo> _documents = const [];
  List<_DocumentInfo> _allDocuments = const [];
  bool _showHistory = false;
  // Quick search UI state
  final TextEditingController _empresaSearchController =
      TextEditingController();

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
          debugPrint(
            '🔐 Token obtenido de SharedPreferences (${_authToken!.length} chars)',
          );
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
    List<Map<String, dynamic>> vehicles = [];

    // Cargar desde la API según el rol del usuario
    if (_authToken != null && _authToken!.isNotEmpty) {
      try {
        debugPrint(
          '📡 Cargando documentos para rol: $_role, userId: ${widget.userId}',
        );

        // Cargar documentos y vehículos en paralelo
        final docsFuture = DocumentService.getDocumentsByRole(
          role: _role,
          userId: widget.userId,
          token: _authToken,
        );
        final vehiclesFuture = DocumentService.getAllVehicles(
          token: _authToken,
        );

        final results = await Future.wait([docsFuture, vehiclesFuture]);
        final documents = List<Map<String, dynamic>>.from(results[0]);
        vehicles = List<Map<String, dynamic>>.from(results[1]);

        debugPrint('🚗 Se cargaron ${vehicles.length} vehículos');

        if (documents.isNotEmpty) {
          final allParsed = _convertApiDocumentsToDocumentInfo(
            documents,
            vehicles,
          );
          _allDocuments = allParsed;

          parsed = _showHistory
              ? allParsed.where((d) => d.estadoDocumento == false).toList()
              : allParsed.where((d) => d.estadoDocumento == true).toList();
          debugPrint('✅ Documentos convertidos: ${parsed.length}');
          for (final doc in parsed) {
            debugPrint(
              '  - Tipo: ${doc.ownerType}, Usuario: ${doc.ownerName}, Vehículo: ${doc.vehiclePlate}, Prop: ${doc.propietarioName}, Cond: ${doc.conductorName}',
            );
          }

          // Filtrar solo documentos activos (estadoDocumento == true)
          debugPrint(
            '📋 Documentos filtrados por estado activo: ${parsed.length}',
          );

          // Filtrar documentos según el rol
          if (_role != 'empresa' &&
              widget.userId != null &&
              widget.userId!.isNotEmpty) {
            final userIdInt = int.tryParse(widget.userId!);
            if (userIdInt != null) {
              final userIdStr = userIdInt.toString();
              debugPrint(
                '📋 Filtrando documentos para $_role con userId: $userIdInt',
              );
              // Mostrar:
              // 1. Documentos personales (ownerId == userId)
              // 2. Documentos de vehículos donde es conductor (conductorUserId == userId)
              // 3. Documentos de vehículos donde es propietario (propietarioUserId == userId)
              parsed = parsed.where((doc) {
                return doc.ownerId == userIdStr ||
                    doc.conductorUserId == userIdStr ||
                    doc.propietarioUserId == userIdStr;
              }).toList();
              debugPrint(
                '📊 Documentos filtrados: ${parsed.length} de ${documents.length}',
              );
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

      debugPrint(
        '📊 DocumentosWidget: loaded ${parsed.length} documents y ${vehicles.length} vehicles',
      );
    }
  }

  List<_DocumentInfo> _convertApiDocumentsToDocumentInfo(
    List<Map<String, dynamic>> documents,
    List<Map<String, dynamic>> vehicles,
  ) {
    debugPrint(
      '🔄 Convirtiendo ${documents.length} documentos con ${vehicles.length} vehículos disponibles',
    );

    return documents
        .map((doc) {
          final String name =
              doc['nombreTipoDocumento'] ??
              doc['nombreTipo'] ??
              doc['nombre'] ??
              'Documento';
          final String category = doc['area'] ?? 'General';
          final String area = doc['area'] ?? '';
          final String observaciones = doc['observaciones'] ?? '';
          final String vehicleId = doc['idVehiculo']?.toString() ?? '';
          final String vehiclePlate = doc['placa'] ?? '';

          DateTime? expiry;
          final dynamic fechaVencimiento = doc['fechaVencimiento'];
          if (fechaVencimiento != null) {
            expiry = DateTime.tryParse(fechaVencimiento.toString());
          }

          if (expiry != null) {
            final DateTime? creation = DateTime.tryParse(
              (doc['fechaCreacion'] ?? '').toString(),
            );

            // Construir nombre del usuario (del documento personal)
            final userFirstName = doc['nombreUsuario'] ?? '';
            final userLastName = doc['apellidoUsuario'] ?? '';
            final String ownerName = '$userFirstName $userLastName'.trim();

            // Para documentos de usuario: el responsable es el mismo usuario
            // El API devuelve idUsuario que es el dueño del documento personal
            final String responsableUserId = !vehicleId.isNotEmpty
                ? (doc['idUsuario']?.toString() ?? '')
                : '';
            debugPrint(
              '📋 Documento ${doc['idDocumento']}: responsableUserId = "$responsableUserId" (usuario dueño: ${doc['idUsuario']})',
            );
            final responsableFirstName =
                doc['nombreResponsable'] ?? doc['nombre_responsable'] ?? '';
            final responsableLastName =
                doc['apellidoResponsable'] ?? doc['apellido_responsable'] ?? '';
            final String responsableName =
                '$responsableFirstName $responsableLastName'.trim();
            final String rolResponsable =
                doc['rolResponsable'] ?? doc['rol_responsable'] ?? '';

            // Obtener nombre de la empresa
            final String empresaNombre =
                doc['nombreEmpresa'] ?? doc['nombre_empresa'] ?? 'Empresa';

            // Buscar nombres de conductor y propietario en la lista de vehículos
            String conductorName = '';
            String propietarioName = '';
            String conductorUserId = '';
            String propietarioUserId = '';

            if (vehicleId.isNotEmpty && vehicles.isNotEmpty) {
              debugPrint('🔍 Buscando vehículo ID: $vehicleId');

              // Buscar el vehículo en la lista
              for (final vehicle in vehicles) {
                final vhId = vehicle['id']?.toString() ?? '';
                if (vhId == vehicleId) {
                  debugPrint('   ✅ Vehículo encontrado: $vehiclePlate');

                  // Obtener datos del conductor (estructura anidada: conductor.usuario.nombre)
                  final conductor = vehicle['conductor'];
                  if (conductor != null && conductor is Map) {
                    final usuario = conductor['usuario'];
                    if (usuario != null && usuario is Map) {
                      final condFirstName = usuario['nombre'] ?? '';
                      final condLastName = usuario['apellido'] ?? '';
                      conductorName = '$condFirstName $condLastName'.trim();
                      conductorUserId = usuario['id']?.toString() ?? '';
                      debugPrint(
                        '   ✓ Conductor: $conductorName (ID: $conductorUserId)',
                      );
                    }
                  }

                  // Obtener datos del propietario (estructura anidada: propietario.usuario.nombre)
                  final propietario = vehicle['propietario'];
                  if (propietario != null && propietario is Map) {
                    final usuario = propietario['usuario'];
                    if (usuario != null && usuario is Map) {
                      final propFirstName = usuario['nombre'] ?? '';
                      final propLastName = usuario['apellido'] ?? '';
                      propietarioName = '$propFirstName $propLastName'.trim();
                      propietarioUserId = usuario['id']?.toString() ?? '';
                      debugPrint(
                        '   ✓ Propietario: $propietarioName (ID: $propietarioUserId)',
                      );
                    }
                  }

                  break;
                }
              }
            }

            return _DocumentInfo(
              name: name,
              expiryDate: expiry,
              creationDate: creation,
              important: false,
              category: category,
              ownerId: vehicleId.isNotEmpty
                  ? vehicleId
                  : (doc['idUsuario']?.toString() ?? ''),
              ownerType: vehicleId.isNotEmpty ? 'vehiculo' : 'usuario',
              ownerName: ownerName,
              vehicleId: vehicleId,
              vehiclePlate: vehiclePlate,
              conductorName: conductorName,
              propietarioName: propietarioName,
              conductorUserId: conductorUserId,
              propietarioUserId: propietarioUserId,
              documentId:
                  int.tryParse(doc['idDocumento']?.toString() ?? '0') ?? 0,
              idTipo: int.tryParse(doc['idTipo']?.toString() ?? '0') ?? 0,
              responsableUserId: responsableUserId,
              responsableName: responsableName,
              rolResponsable: rolResponsable,
              empresaNombre: empresaNombre,
              area: area,
              observaciones: observaciones,
              estadoDocumento: doc['estadoDocumento'] ?? true,
            );
          }
          return null;
        })
        .whereType<_DocumentInfo>()
        .toList();
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
        Positioned.fill(child: contentWidget),
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
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis Documentos',
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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

        // Separar documentos: personales vs del vehículo
        final List<_DocumentInfo> personalDocs = _documents
            .where((d) => d.vehicleId.isEmpty)
            .toList();
        final List<_DocumentInfo> vehicleDocs = _documents
            .where((d) => d.vehicleId.isNotEmpty)
            .toList();

        // Próximos documentos a vencer (todos, incluyendo vencidos)
        final int upcomingLimit = 3;
        final List<_DocumentInfo> upcomingDocs = _documents.toList()
          ..sort((a, b) {
            // Orden personalizado: vencidos primero (más tiempo vencido primero), luego próximos (menos días primero)
            if (a.daysRemaining < 0 && b.daysRemaining < 0) {
              return a.daysRemaining.compareTo(
                b.daysRemaining,
              ); // Más negativo primero
            } else if (a.daysRemaining < 0 && b.daysRemaining >= 0) {
              return -1; // Vencidos primero
            } else if (a.daysRemaining >= 0 && b.daysRemaining < 0) {
              return 1; // Vencidos primero
            } else {
              return a.daysRemaining.compareTo(
                b.daysRemaining,
              ); // Menos días primero
            }
          });
        final List<_DocumentInfo> topUpcoming = upcomingDocs
            .take(upcomingLimit)
            .toList();

        // Aplicar búsqueda
        List<_DocumentInfo> filteredPersonalDocs = personalDocs;
        List<_DocumentInfo> filteredVehicleDocs = vehicleDocs;
        if (_conductorSearch.isNotEmpty) {
          final String s = _conductorSearch;
          filteredPersonalDocs = filteredPersonalDocs
              .where(
                (d) =>
                    d.name.toLowerCase().contains(s) ||
                    d.category.toLowerCase().contains(s) ||
                    d.ownerName.toLowerCase().contains(s),
              )
              .toList();
          filteredVehicleDocs = filteredVehicleDocs
              .where(
                (d) =>
                    d.name.toLowerCase().contains(s) ||
                    d.category.toLowerCase().contains(s) ||
                    d.vehiclePlate.toLowerCase().contains(s),
              )
              .toList();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Mis Documentos',
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildUpcomingDocumentCircularGrid(
                  isCompact: isCompact,
                  docs: topUpcoming,
                ),
                const SizedBox(height: 16),
              ],

              // Buscador
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar documentos (nombre, categoría, placa)',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) =>
                      setState(() => _conductorSearch = v.trim().toLowerCase()),
                ),
              ),

              // SECCIÓN 1: MIS DOCUMENTOS (personales)
              if (filteredPersonalDocs.isNotEmpty) ...[
                Text(
                  'Mis Documentos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDocumentList(
                  isCompact: isCompact,
                  docs: filteredPersonalDocs,
                ),
                const SizedBox(height: 24),
              ],

              // SECCIÓN 2: DOCUMENTOS DEL VEHÍCULO
              if (filteredVehicleDocs.isNotEmpty) ...[
                Text(
                  'Documentos del Vehículo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildVehicleDocumentsSection(
                  isCompact: isCompact,
                  docs: filteredVehicleDocs,
                ),
              ] else if (filteredPersonalDocs.isEmpty) ...[
                Center(
                  child: Text(
                    'No hay documentos que coincidan con la búsqueda',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: isCompact ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build circular progress indicators for upcoming documents
  Widget _buildUpcomingDocumentCircularGrid({
    required bool isCompact,
    required List<_DocumentInfo> docs,
  }) {
    if (docs.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<_DocumentInfo> displayDocs = docs.take(3).toList();

    if (isCompact) {
      return SizedBox(
        height: 230,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: displayDocs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 220,
              child: _buildCircularDocumentCard(
                doc: displayDocs[index],
                isCompact: true,
              ),
            );
          },
        ),
      );
    }

    return Row(
      children: displayDocs.map((doc) {
        return Expanded(
          child: _buildCircularDocumentCard(doc: doc, isCompact: false),
        );
      }).toList(),
    );
  }

  /// Build individual circular progress card for a document
  Widget _buildCircularDocumentCard({
    required _DocumentInfo doc,
    required bool isCompact,
  }) {
    final progressPercent = _calculateProgressPercent(doc);
    final Map<String, Color> colors = _getColorForDaysRemaining(
      doc.daysRemaining,
    );
    final Color accentColor = colors['start']!;
    final circleSize = isCompact ? 100.0 : 110.0;

    return GestureDetector(
      onTap: () => _openModal(doc),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 8.0),
        padding: EdgeInsets.all(isCompact ? 12 : 14),
        decoration: BoxDecoration(
          color: _cardColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular progress indicator with custom painter
            SizedBox(
              width: circleSize,
              height: circleSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(circleSize, circleSize),
                    painter: _CircleProgressPainter(
                      progress: progressPercent.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      progressColor: accentColor,
                      strokeWidth: 6,
                    ),
                  ),
                  // Center content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        doc.daysRemaining < 0
                            ? '${doc.daysRemaining}'
                            : '${doc.daysRemaining}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 24 : 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        doc.daysRemaining == 1 ? 'día' : 'días',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isCompact ? 10 : 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 10 : 12),
            // Document name
            Text(
              doc.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Document category
            Text(
              doc.category,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isCompact ? 9 : 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Show owner name for personal documents with person icon
            if (doc.isPersonal && doc.ownerName.isNotEmpty) ...[
              SizedBox(height: isCompact ? 4 : 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    color: accentColor,
                    size: isCompact ? 12 : 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      doc.ownerName,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: isCompact ? 8 : 9,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
            if (doc.vehiclePlate.isNotEmpty) ...[
              SizedBox(height: isCompact ? 4 : 6),
              Text(
                doc.vehiclePlate,
                style: TextStyle(
                  color: accentColor,
                  fontSize: isCompact ? 9 : 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Calculate progress percentage from creation to expiry date
  /// Progress = remaining days / total days
  /// 100% = many days left, 0% = expiring soon
  double _calculateProgressPercent(_DocumentInfo doc) {
    if (doc.creationDate == null) {
      return 0.0;
    }

    final totalDaysSpan = doc.expiryDate.difference(doc.creationDate!).inDays;
    if (totalDaysSpan <= 0) {
      return 0.0;
    }

    // Use remaining days instead of elapsed days
    final remainingDays = doc.daysRemaining.toDouble();
    final progressPercent = (remainingDays / totalDaysSpan).clamp(0.0, 1.0);

    return progressPercent;
  }

  Widget _buildDocumentList({
    required bool isCompact,
    List<_DocumentInfo>? docs,
  }) {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            // TÍTULO: Mostrar diferente según tipo de documento
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orangeAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Importante',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                // Para documentos de vehículo: mostrar placa, conductor y propietario debajo del título
                if (doc.isVehicleDocument && doc.vehiclePlate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Placa: ${doc.vehiclePlate}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            // SUBTITLE: Información de propietario/conductor/fecha
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  // Para documentos personales: mostrar nombre del usuario con icono de persona
                  if (doc.isPersonal && doc.ownerName.isNotEmpty)
                    _buildChipWithIcon(
                      icon: Icons.person,
                      label: doc.ownerName,
                      highlight: false,
                    ),

                  // Para documentos de vehículo: mostrar conductor y propietario con iconos
                  if (doc.isVehicleDocument) ...[
                    if (doc.conductorName.isNotEmpty)
                      _buildChipWithIcon(
                        icon: Icons.directions_car,
                        label: 'Conductor: ${doc.conductorName}',
                        highlight: false,
                      ),
                    if (doc.propietarioName.isNotEmpty)
                      _buildChipWithIcon(
                        icon: Icons.person_outline,
                        label: 'Propietario: ${doc.propietarioName}',
                        highlight: false,
                      ),
                  ],

                  // Información de vencimiento y estado
                  _buildChip(
                    label: isExpired
                        ? 'Documento vencido'
                        : 'Vence el ${_formatDate(doc.expiryDate)}',
                    highlight: isNearExpiry || isExpired,
                  ),
                  _buildChip(
                    label: '${doc.daysRemaining.clamp(0, 999)} días restantes',
                    highlight: isNearExpiry,
                  ),

                  // Fecha de creación
                  if (doc.creationDate != null)
                    _buildChip(
                      label: 'Creado el ${_formatDate(doc.creationDate!)}',
                      highlight: false,
                    ),

                  // Tipo de documento
                  _buildChip(
                    label: doc.estadoDocumento ? 'Activo' : 'Histórico',
                    highlight: !doc.estadoDocumento,
                  ),
                ],
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (String action) {
                if (action == 'view') {
                  _openModal(doc);
                } else if (action == 'edit') {
                  _openEditModal(doc);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ver detalles',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text('Editar', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
              color: const Color(0xFF1B1F6B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Agrupa documentos personales por usuario y muestra también sus documentos de vehículos
  Widget _buildGroupedListWithVehicles({
    required bool isCompact,
    required List<_DocumentInfo> personalDocs,
    required List<_DocumentInfo> vehicleDocs,
  }) {
    // Agrupar documentos personales por nombre de usuario
    final Map<String, List<_DocumentInfo>> groupedPersonal = {};
    for (final d in personalDocs) {
      final String key = d.ownerName.isNotEmpty ? d.ownerName : 'Usuario';
      groupedPersonal.putIfAbsent(key, () => []).add(d);
    }

    final entries = groupedPersonal.entries.toList();
    return Column(
      children: entries.map((entry) {
        final String userName = entry.key;
        final List<_DocumentInfo> personalItems = entry.value;

        // Buscar documentos de vehículos ligados a este usuario
        // (donde sea propietario O conductor)
        final List<_DocumentInfo> userVehicleDocs = vehicleDocs.where((doc) {
          return doc.propietarioName == userName ||
              doc.conductorName == userName;
        }).toList();

        // Total de documentos (personales + vehículos)
        final int totalDocs = personalItems.length + userVehicleDocs.length;

        return ExpansionTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A3BF0), Color(0xFF6C63FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white12,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalDocs',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Documentos personales
                  if (personalItems.isNotEmpty) ...[
                    Text(
                      'Documentos Personales',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDocumentList(
                      isCompact: isCompact,
                      docs: personalItems,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Documentos de vehículos
                  if (userVehicleDocs.isNotEmpty) ...[
                    Text(
                      'Documentos de Vehículos Asociados',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildVehicleDocumentsSection(
                      isCompact: isCompact,
                      docs: userVehicleDocs,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildVehicleDocumentsSection({
    required bool isCompact,
    required List<_DocumentInfo> docs,
  }) {
    // Agrupar documentos por vehicleId + placa
    final Map<String, List<_DocumentInfo>> groupedByVehicle = {};
    for (final doc in docs) {
      final String key = '${doc.vehicleId}|${doc.vehiclePlate}';
      groupedByVehicle.putIfAbsent(key, () => []).add(doc);
    }

    return Column(
      children: groupedByVehicle.entries.map((entry) {
        final List<_DocumentInfo> vehicleDocs = entry.value;
        final _DocumentInfo firstDoc = vehicleDocs.first;
        final String placa = firstDoc.vehiclePlate.isNotEmpty
            ? firstDoc.vehiclePlate
            : 'Placa desconocida';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              // Encabezado con info del vehículo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3330BE).withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Placa del vehículo
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          color: Colors.cyan,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A partir de aquí: documentos del vehículo $placa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCompact ? 14 : 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Estos documentos pertenecen únicamente a este vehículo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isCompact ? 11 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Info de Propietario y Conductor
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Propietario',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isCompact ? 10 : 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  firstDoc.propietarioName.isNotEmpty
                                      ? firstDoc.propietarioName
                                      : '-',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompact ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Conductor',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isCompact ? 10 : 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  firstDoc.conductorName.isNotEmpty
                                      ? firstDoc.conductorName
                                      : 'Info disponible',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompact ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Lista de documentos del vehículo
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildDocumentList(
                  isCompact: isCompact,
                  docs: vehicleDocs,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChip({required String label, required bool highlight}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? _accentColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? _chipBorderColor : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildChipWithIcon({
    required IconData icon,
    required String label,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? _accentColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? _chipBorderColor : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- Empresa documents panel (search, filters, highlighting) ---

  String _empresaSearch = '';
  String _propietarioSearch = '';
  String _conductorSearch = '';

  // Obtener color basado en días restantes para vencimiento
  Map<String, Color> _getColorForDaysRemaining(int daysRemaining) {
    if (daysRemaining < 0) {
      // Vencido: rojo
      return {'start': const Color(0xFFEF4444), 'end': const Color(0xFFDC2626)};
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

        // Separar documentos según búsqueda
        String q = _empresaSearch.trim().toLowerCase();

        // Documentos personales (sin vehículo)
        List<_DocumentInfo> personalDocs = _documents
            .where((d) => d.isPersonal)
            .toList();
        if (q.isNotEmpty) {
          personalDocs = personalDocs
              .where((d) => d.ownerName.toLowerCase().contains(q))
              .toList();
        }

        // Documentos de vehículo (con idVehiculo)
        List<_DocumentInfo> vehicleDocs = _documents
            .where((d) => d.isVehicleDocument)
            .toList();
        if (q.isNotEmpty) {
          vehicleDocs = vehicleDocs
              .where(
                (d) =>
                    d.vehiclePlate.toLowerCase().contains(q) ||
                    d.propietarioName.toLowerCase().contains(q) ||
                    d.conductorName.toLowerCase().contains(q),
              )
              .toList();
        }

        // Si no hay documentos en absoluto
        if (_documents.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 24,
                ),
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
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showHistory = !_showHistory;
                        });
                        _loadDocuments();
                      },
                      icon: Icon(
                        _showHistory ? Icons.visibility : Icons.history,
                        color: Colors.white,
                      ),
                      label: Text(
                        _showHistory
                            ? 'Ver documentos activos'
                            : 'Ver historial',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showHistory
                            ? Colors.orange
                            : _accentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Busca y visualiza los documentos de tus conductores, propietarios y vehículos',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isCompact ? 12 : 13,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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

        // Calcular documentos próximos a vencer (todos, incluyendo vencidos)
        final int upcomingLimit = 3;
        final List<_DocumentInfo> upcomingAll = _documents.toList()
          ..sort((a, b) {
            // Orden personalizado: vencidos primero (más tiempo vencido primero), luego próximos (menos días primero)
            if (a.daysRemaining < 0 && b.daysRemaining < 0) {
              return a.daysRemaining.compareTo(
                b.daysRemaining,
              ); // Más negativo primero
            } else if (a.daysRemaining < 0 && b.daysRemaining >= 0) {
              return -1; // Vencidos primero
            } else if (a.daysRemaining >= 0 && b.daysRemaining < 0) {
              return 1; // Vencidos primero
            } else {
              return a.daysRemaining.compareTo(
                b.daysRemaining,
              ); // Menos días primero
            }
          });
        final List<_DocumentInfo> upcomingAllLimited = upcomingAll
            .take(upcomingLimit)
            .toList();

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: 24,
          ),
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
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showHistory = !_showHistory;
                  });
                  _loadDocuments();
                },
                icon: Icon(
                  _showHistory ? Icons.visibility : Icons.history,
                  color: Colors.white,
                ),
                label: Text(
                  _showHistory ? 'Ver solo activos' : 'Ver historial',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showHistory ? Colors.orange : _accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              Text(
                'Busca y visualiza los documentos de tus conductores, propietarios y vehículos',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
              const SizedBox(height: 16),

              // Documentos próximos a vencer
              if (!_showHistory && upcomingAllLimited.isNotEmpty) ...[
                Text(
                  'Próximos a vencer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildUpcomingDocumentCircularGrid(
                  isCompact: isCompact,
                  docs: upcomingAllLimited,
                ),
                const SizedBox(height: 24),
              ],

              // Buscador
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre de persona',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (v) =>
                    setState(() => _empresaSearch = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 24),
              if (q.isNotEmpty &&
                  personalDocs.isEmpty &&
                  vehicleDocs.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No hay resultados para "$q"',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isCompact ? 13 : 15,
                      ),
                    ),
                  ),
                ),
              ],

              // SECCIÓN: DOCUMENTOS DE USUARIOS (con sus vehículos)
              if (personalDocs.isNotEmpty || vehicleDocs.isNotEmpty) ...[
                Text(
                  _showHistory
                      ? 'Historial de Documentos'
                      : 'Documentos de Usuarios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildGroupedListWithVehicles(
                  isCompact: isCompact,
                  personalDocs: personalDocs,
                  vehicleDocs: vehicleDocs,
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _propietarioDocumentos() {
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
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis Documentos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 40),
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
                          'No hay documentos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w600,
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

        // Separar documentos: personales vs del vehículo
        final List<_DocumentInfo> personalDocs = _documents
            .where((d) => d.vehicleId.isEmpty)
            .toList();
        final List<_DocumentInfo> vehicleDocs = _documents
            .where((d) => d.vehicleId.isNotEmpty)
            .toList();

        // Próximos documentos a vencer (todos, incluyendo vencidos - propietario)
        final List<_DocumentInfo> upcomingDocs = _documents.toList()
          ..sort((a, b) {
            // Orden personalizado: vencidos primero (más tiempo vencido primero), luego próximos (menos días primero)
            if (a.daysRemaining < 0 && b.daysRemaining < 0) {
              return a.daysRemaining.compareTo(
                b.daysRemaining,
              ); // Más negativo primero
            } else if (a.daysRemaining < 0 && b.daysRemaining >= 0) {
              return -1; // Vencidos primero
            } else if (a.daysRemaining >= 0 && b.daysRemaining < 0) {
              return 1; // Vencidos primero
            } else {
              return a.daysRemaining.compareTo(
                b.daysRemaining,
              ); // Menos días primero
            }
          });
        final int upcomingLimit = 3;
        final List<_DocumentInfo> topUpcoming = upcomingDocs
            .take(upcomingLimit)
            .toList();

        // Aplicar búsqueda
        List<_DocumentInfo> filteredPersonalDocs = personalDocs;
        List<_DocumentInfo> filteredVehicleDocs = vehicleDocs;
        if (_propietarioSearch.isNotEmpty) {
          final String s = _propietarioSearch;
          filteredPersonalDocs = filteredPersonalDocs
              .where(
                (d) =>
                    d.name.toLowerCase().contains(s) ||
                    d.category.toLowerCase().contains(s) ||
                    d.ownerName.toLowerCase().contains(s),
              )
              .toList();
          filteredVehicleDocs = filteredVehicleDocs
              .where(
                (d) =>
                    d.name.toLowerCase().contains(s) ||
                    d.category.toLowerCase().contains(s) ||
                    d.vehiclePlate.toLowerCase().contains(s),
              )
              .toList();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Mis Documentos',
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildUpcomingDocumentCircularGrid(
                  isCompact: isCompact,
                  docs: topUpcoming,
                ),
                const SizedBox(height: 16),
              ],

              // Buscador
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar documentos (nombre, categoría, placa)',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(
                    () => _propietarioSearch = v.trim().toLowerCase(),
                  ),
                ),
              ),

              // SECCIÓN 1: MIS DOCUMENTOS (personales)
              if (filteredPersonalDocs.isNotEmpty) ...[
                Text(
                  'Mis Documentos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDocumentList(
                  isCompact: isCompact,
                  docs: filteredPersonalDocs,
                ),
                const SizedBox(height: 24),
              ],

              // SECCIÓN 2: DOCUMENTOS DEL VEHÍCULO
              if (filteredVehicleDocs.isNotEmpty) ...[
                Text(
                  'Documentos del Vehículo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildVehicleDocumentsSection(
                  isCompact: isCompact,
                  docs: filteredVehicleDocs,
                ),
              ] else if (filteredPersonalDocs.isEmpty) ...[
                Center(
                  child: Text(
                    'No hay documentos que coincidan con la búsqueda',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: isCompact ? 12 : 14,
                    ),
                  ),
                ),
              ],
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
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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

  /// Abre el modal para editar un documento
  void _openEditModal(_DocumentInfo doc) async {
    // Lógica: Si rol es EMPRESA o no hay responsable específico, mostrar nombre de empresa
    // Si hay responsable con otro rol, mostrar nombre del responsable
    String responsableDisplay;
    if (doc.rolResponsable.toUpperCase() == 'EMPRESA' ||
        doc.rolResponsable.isEmpty) {
      // Si el responsable es la empresa o no hay responsable específico
      responsableDisplay = doc.empresaNombre;
    } else {
      // Si hay un responsable específico (secretaria, admin, etc.)
      responsableDisplay = doc.responsableName.isNotEmpty
          ? doc.responsableName
          : doc.empresaNombre;
    }

    // Obtener el ID del usuario actual (quien está editando)
    String currentUserId = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final authUserJson = prefs.getString('auth_user');
      if (authUserJson != null && authUserJson.isNotEmpty) {
        final authUser = jsonDecode(authUserJson) as Map<String, dynamic>;
        currentUserId = authUser['id']?.toString() ?? '';
        debugPrint('👤 Usuario actual editando: $currentUserId');
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo usuario actual: $e');
    }

    // Cargar tipos de documento
    final tiposDocumento = await DocumentService.getDocumentTypes(
      token: widget.token,
    );

    if (mounted) {
      // Convertir documentos a formato para el modal
      final documentosParaModal = _documents
          .map(
            (d) => {
              'documentoId': d.documentId,
              'idTipo': d.idTipo,
              'vehicleId': d.vehicleId,
              'ownerId': d.ownerId,
              'estadoDocumento': d.estadoDocumento,
            },
          )
          .toList();

      EditDocumentModal.show(
        context: context,
        documentoId: doc.documentId,
        idTipo: doc.idTipo,
        tipoDocumento: doc.category,
        fechaVencimiento: doc.expiryDate,
        titular: doc.ownerName,
        responsable: responsableDisplay,
        observaciones: doc.observaciones,
        area: doc.area,
        isVehicleDocument: doc.isVehicleDocument,
        vehicleId: doc.vehicleId,
        // ownerId contiene: vehicleId para vehículos, o idUsuario para usuarios
        ownerUserId: doc.ownerId,
        empresaNombre: doc.empresaNombre,
        vehiclePlate: doc.vehiclePlate,
        responsableUserId:
            currentUserId, // Usar el ID del usuario actual que está editando
        tiposDocumento: tiposDocumento,
        documentosActuales: documentosParaModal,
        onSuccess: () {
          // Recargar documentos después de editar
          _loadDocuments();
        },
      );
    }
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

/// Custom painter to draw circular progress indicator
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - (strokeWidth / 2);

    // Background circle
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final Paint progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw progress arc (starting from top, going clockwise)
    const double startAngle = -3.14159265359 / 2; // -90 degrees
    final double sweepAngle = (2 * 3.14159265359) * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
