import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'document_modal.dart';
import 'shimmer_skeleton.dart';
import '../services/api_service.dart';

class InicioWidget extends StatefulWidget {
  final String? role;
  // Optional: pass document expiry dates from parent (from DB)
  final Map<String, DateTime>? documents;
  final String? jsonPath; // Ruta al archivo JSON
  final String? userProfilePath; // Ruta al JSON del perfil
  final String? userId; // ID del usuario a cargar
  final VoidCallback? onNavigateToDocuments;
  final VoidCallback? onNavigateToPayments;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToMessages;

  const InicioWidget({
    super.key,
    this.role,
    this.documents,
    this.jsonPath,
    this.userProfilePath,
    this.userId,
    this.onNavigateToDocuments,
    this.onNavigateToPayments,
    this.onNavigateToProfile,
    this.onNavigateToMessages,
  });

  @override
  State<InicioWidget> createState() => _InicioWidgetState();
}

class _InicioWidgetState extends State<InicioWidget> {
  late String _role;
  late Map<String, DateTime> _documents;
  Map<String, DateTime>? _paymentDates;
  bool _isLoading = true;
  List<Map<String, dynamic>> _fleetVehicles = [];
  List<Map<String, dynamic>> _propietarios = [];
  Map<String, String> _documentVehicle = {};
  Map<String, dynamic> _summaryMetrics = {};
  final List<Map<String, dynamic>> _alerts = [];
  
  // User profile data
  String _userName = 'Usuario';
  String _userCompany = 'Empresa';
  String? _userProfileImage;

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? '').trim();
    _documents = widget.documents != null
        ? Map<String, DateTime>.from(widget.documents!)
        : <String, DateTime>{};
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDocuments(),
      _loadUserProfile(),
    ]);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadDocuments() async {
    final Map<String, DateTime> docs = <String, DateTime>{};
    final Map<String, String> docDetails = <String, String>{};
    List<Map<String, dynamic>> fleet = [];
    Map<String, dynamic> summary = {};

    try {
      // Cargar documentos según el rol del usuario
      switch (_role.toLowerCase()) {
        case 'empresa':
          // Empresa: obtener documentos de TODOS los vehículos
          final backendDocs = await ApiService.getDocumentosEmpresa();
          _processDocuments(backendDocs, docs, docDetails);
          
          // Cargar vehículos para mostrar en flota
          final vehiculos = await ApiService.getVehiculos();
          fleet = _processVehiculos(vehiculos);
          
          // Cargar propietarios ligados a la empresa
          final propietarios = await ApiService.getPropietarios();
          
          // Calcular resumen
          final conductores = await ApiService.getConductores();
          final vencidos = await ApiService.getDocumentosVencidos();
          summary = {
            'fleetSize': vehiculos.length,
            'activeDrivers': conductores.length,
            'documentsExpired': vencidos.length,
          };
          
          // Guardar propietarios en el estado
          if (mounted) {
            setState(() {
              _propietarios = propietarios;
            });
          }
          
          debugPrint('✅ EMPRESA: ${backendDocs.length} documentos, ${vehiculos.length} vehículos, ${propietarios.length} propietarios');
          break;

        case 'conductor':
        case 'propietario':
        case 'secretaria':
          // Para otros roles, obtener su usuario actual y sus documentos
          final usuario = await ApiService.getUsuarioActual();
          if (usuario != null) {
            final usuarioId = usuario['id'] ?? usuario['idUsuario'];
            if (usuarioId != null) {
              final backendDocs = await ApiService.getDocumentos(
                userId: usuarioId.toString(),
              );
              _processDocuments(backendDocs, docs, docDetails);
              debugPrint('✅ ${_role.toUpperCase()}: ${backendDocs.length} documentos cargados');
            }
          }
          break;

        case 'admin':
          // Admin: puede ver documentos de todas las empresas
          final backendDocs = await ApiService.getDocumentosEmpresa();
          _processDocuments(backendDocs, docs, docDetails);
          debugPrint('✅ ADMIN: ${backendDocs.length} documentos cargados');
          break;

        default:
          debugPrint('⚠️ Rol no reconocido: $_role');
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Error al cargar documentos: $e');
    }

    if (!mounted) return;
    setState(() {
      _documents = docs;
      _documentVehicle = docDetails;
      _fleetVehicles = fleet;
      _summaryMetrics = summary;
    });
  }

  /// Procesa una lista de documentos del backend
  void _processDocuments(
    List<Map<String, dynamic>> backendDocs,
    Map<String, DateTime> docs,
    Map<String, String> docDetails,
  ) {
    for (final doc in backendDocs) {
      // Usar ID del documento como identificador único para evitar sobreescrituras
      final dynamic docId = doc['idDocumento'] ?? doc['id_documento'] ?? doc['id'];
      if (docId == null) {
        debugPrint('⚠️ Documento sin ID, saltando');
        continue;
      }

      final String? nombre = doc['nombre']?.toString();
      final String tipoNombre = doc['nombreTipoDocumento']?.toString() 
          ?? doc['tipoDocumento']?['nombre']?.toString() 
          ?? 'Documento';
      final displayName = nombre ?? tipoNombre;

      // Crear una clave única combinando tipo + nombre + id
      final String uniqueKey = '$tipoNombre - $displayName (#$docId)';

      // Parsear fecha de vencimiento
      final String? vencimientoStr = doc['fechaVencimiento']?.toString();
      if (vencimientoStr != null && vencimientoStr.isNotEmpty) {
        final vencimiento = DateTime.tryParse(vencimientoStr);
        if (vencimiento != null) {
          docs[uniqueKey] = vencimiento;
        }
      }

      // Construir detalles
      final String area = doc['area']?.toString() ?? '';
      final String responsable = doc['nombreResponsable']?.toString() 
          ?? doc['responsableUsuario']?['nombre']?.toString() 
          ?? '';
      final String vehiculoPlaca = doc['placa']?.toString() 
          ?? doc['vehiculo']?['placa']?.toString() 
          ?? '';

      final List<String> detailParts = [];
      if (area.isNotEmpty) detailParts.add(area);
      if (responsable.isNotEmpty) detailParts.add(responsable);
      if (vehiculoPlaca.isNotEmpty) detailParts.add('Placa: $vehiculoPlaca');

      if (detailParts.isNotEmpty) {
        docDetails[uniqueKey] = detailParts.join(' · ');
      }

      debugPrint('✅ Documento procesado: $uniqueKey, vencimiento: $vencimientoStr');
    }
    debugPrint('📊 Total documentos procesados: ${docs.length}');
  }

  /// Procesa vehículos del backend para mostrar en flota
  List<Map<String, dynamic>> _processVehiculos(List<Map<String, dynamic>> vehiculos) {
    return vehiculos
        .map((vehiculo) {
          final DateTime? nextExpiry = _calculateNextExpiry(vehiculo);
          return {
            'id': vehiculo['idVehiculo'] ?? vehiculo['id'],
            'plate': vehiculo['placa']?.toString() ?? 'N/A',
            'model': '${vehiculo['marca']?.toString() ?? ''} ${vehiculo['modelo']?.toString() ?? ''}'.trim(),
            'driver': vehiculo['nombreConductor']?.toString() 
                ?? vehiculo['conductor']?['nombre']?.toString()
                ?? 'No asignado',
            'status': vehiculo['estadoVehiculo']?.toString() ?? 'ACTIVO',
            'nextExpiry': nextExpiry ?? DateTime.now().add(const Duration(days: 30)),
            'lastService': DateTime.now().subtract(const Duration(days: 30)),
            'mileage': vehiculo['kilometrajeActual'] ?? 0,
            'color': vehiculo['color']?.toString() ?? '',
          };
        })
        .toList();
  }

  /// Calcula el próximo vencimiento de documentos para un vehículo
  DateTime? _calculateNextExpiry(Map<String, dynamic> vehiculo) {
    DateTime? earliest;
    final docs = vehiculo['documentos'] as List?;
    if (docs != null) {
      for (final doc in docs) {
        if (doc is Map) {
          final venc = DateTime.tryParse(doc['fechaVencimiento']?.toString() ?? '');
          if (venc != null && (earliest == null || venc.isBefore(earliest))) {
            earliest = venc;
          }
        }
      }
    }
    return earliest;
  }

  Future<void> _loadUserProfile() async {
    if (widget.userProfilePath == null || widget.userProfilePath!.isEmpty) {
      return;
    }

    try {
      final String raw = await rootBundle.loadString(widget.userProfilePath!);
      final dynamic decoded = json.decode(raw);
      final List<Map<String, dynamic>> candidates = _extractUserRecords(decoded);

      Map<String, dynamic>? userData;
      if (candidates.isNotEmpty) {
        if (widget.userId != null && widget.userId!.isNotEmpty) {
          userData = candidates.firstWhere(
            (entry) {
              final dynamic candidateId = entry['id'] ?? entry['id_usuario'] ?? entry['id_empresa'];
              return candidateId != null && candidateId.toString() == widget.userId;
            },
            orElse: () => candidates.first,
          );
        } else {
          userData = candidates.first;
        }
      } else if (decoded is Map<String, dynamic>) {
        userData = decoded;
      }

      if (userData == null) {
        return;
      }

      String? profileImageCandidate;
      final dynamic rawImage = userData['profileImage'] ?? userData['logo'];
      if (rawImage is String && rawImage.isNotEmpty) {
        final bool exists = await _assetExists(rawImage);
        if (exists) {
          profileImageCandidate = rawImage;
        } else {
          debugPrint('Imagen de perfil no encontrada: $rawImage');
        }
      }

      final String resolvedName = userData['name']?.toString()
          ?? userData['nombre']?.toString()
          ?? userData['representanteLegal']?.toString()
          ?? _userName;

      String resolvedCompany = userData['company']?.toString()
          ?? userData['nombreEmpresa']?.toString()
          ?? userData['razonSocial']?.toString()
          ?? userData['descripcion']?.toString()
          ?? _userCompany;

      if (_role.toLowerCase() == 'empresa') {
        resolvedCompany = userData['vision']?.toString()
            ?? userData['descripcion']?.toString()
            ?? resolvedCompany;
      }

      if (!mounted) return;
      setState(() {
        _userName = resolvedName.isNotEmpty ? resolvedName : _userName;
        _userCompany = resolvedCompany.isNotEmpty ? resolvedCompany : _userCompany;
        _userProfileImage = profileImageCandidate;
      });
    } catch (e) {
      debugPrint('Error cargando perfil desde ${widget.userProfilePath}: $e');
    }
  }

  List<Map<String, dynamic>> _extractUserRecords(dynamic source) {
    List<dynamic>? records;
    if (source is List) {
      records = source;
    } else if (source is Map<String, dynamic>) {
      const List<String> keys = ['users', 'owners', 'companies', 'data'];
      for (final key in keys) {
        final dynamic value = source[key];
        if (value is List) {
          records = value;
          break;
        }
      }
      records ??= [source];
    }

    if (records == null) {
      return const [];
    }

    return records
        .whereType<Map>()
        .map((record) => record.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Return list of entries sorted by soonest expiry
  List<MapEntry<String, DateTime>> _upcomingDocs({int limit = 3}) {
    final entries = _documents.entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries.take(limit).toList();
  }

  /// Construye el estado de carga con shimmer skeletons
  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner imagen
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(height: 20),
                // Título
                ShimmerSkeleton(
                  width: 150,
                  height: 22,
                  borderRadius: 8,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 6),
                // Subtítulo
                ShimmerSkeleton(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 8,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                // Chips de resumen
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    6,
                    (index) => const ShimmerSummaryChip(),
                  ),
                ),
                const SizedBox(height: 26),
                // Título documentos
                ShimmerSkeleton(
                  width: 250,
                  height: 18,
                  borderRadius: 8,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                // Grid de documentos
                Column(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShimmerSkeleton(
                        width: double.infinity,
                        height: 100,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_role.isEmpty) {
      return _buildRoleSelectionLanding();
    }

    final Widget roleContent = _buildRoleContent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: roleContent),
      ],
    );
  }

  Widget _buildRoleContent() {
    switch (_role.toLowerCase()) {
      case 'conductor':
        return _conductorInicio();
      case 'empresa':
        return _empresaInicio();
      case 'propietario':
        return _propietarioInicio();
      case 'secretaria':
        return _secretariaInicio();
      case 'admin':
        return _adminInicio();
    }
    return _adminInicio();
  }

  Widget _buildRoleSelectionLanding() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.dashboard_customize, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Selecciona un rol para explorar su panel.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16
          ),
        ],
      ),
    );
  }

  Widget _conductorInicio() {
    final int totalVehicles = _fleetVehicles.length;
    final int docsExpiringSoon = _documents.entries
        .where((entry) => entry.value.isBefore(DateTime.now().add(const Duration(days: 30))))
        .length;
    final List<Map<String, dynamic>> vehiclesToShow = _fleetVehicles.take(3).toList();
    final List<MapEntry<String, DateTime>> upcoming = _upcomingDocs(limit: 3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 480;
        final double imageHeight = isCompact ? 160 : 200;
        final EdgeInsets outerPadding = EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 20,
          vertical: 20,
        );

        return SingleChildScrollView(
          padding: outerPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: imageHeight,
                      color: Colors.transparent,
                      child: Image.asset(
                        'assets/vehicles.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 12 : 16),
                  const Text(
                    'Panel Conductor',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Resumen de asignaciones, documentos y próximos vencimientos.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildSummaryChip(Icons.directions_car, '$totalVehicles vehículos', 'Asignados'),
                        _buildSummaryChip(Icons.warning_amber_rounded, '$docsExpiringSoon vencimientos', 'Próximos 30 días'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (upcoming.isNotEmpty) ...[
                    const Text(
                      'Documentos próximos a vencer',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentCountdownGrid(upcoming),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: widget.onNavigateToDocuments,
                          icon: const Icon(Icons.folder_copy, color: Color(0xFF16C79A)),
                          label: const Text('Ver todos los documentos', style: TextStyle(color: Color(0xFF16C79A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Vehículos asignados',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (vehiclesToShow.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text('No hay vehículos asignados actualmente.', style: TextStyle(color: Colors.white70)),
                    )
                  else
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: ListView.separated(
                          itemCount: vehiclesToShow.length,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildVehicleCard(vehiclesToShow[index]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _buildUserProfile(isCompact: isCompact),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserProfile({required bool isCompact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stackActions = constraints.maxWidth < 360;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24, width: 1.4),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 18,
            vertical: isCompact ? 14 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _handleViewProfile,
                    child: CircleAvatar(
                      radius: isCompact ? 28 : 30,
                      backgroundColor: Colors.white24,
                      backgroundImage: _userProfileImage != null && _userProfileImage!.isNotEmpty
                          ? AssetImage(_userProfileImage!)
                          : null,
                      child: _userProfileImage == null || _userProfileImage!.isEmpty
                          ? const Icon(Icons.person, size: 34, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 17 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userCompany,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isCompact ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!stackActions) ...[
                    const SizedBox(width: 12),
                    _buildProfileActions(centered: false),
                  ],
                ],
              ),
              if (stackActions) ...[
                const SizedBox(height: 12),
                _buildProfileActions(centered: true),
              ],
              const SizedBox(height: 14),
              const Divider(color: Colors.white24, thickness: 0.8, height: 1),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, boxConstraints) {
                  final bool stackQuickActions = boxConstraints.maxWidth < 420;
                  final bool showPaymentCard = _role.toLowerCase() != 'propietario';
                  final quickCards = <Widget>[
                    _buildQuickAccessCard(Icons.folder_open, 'Ver\ndocumentos', _handleViewDocuments),
                    if (showPaymentCard)
                      _buildQuickAccessCard(Icons.payments, 'Pagos\npendientes', _handleViewPayments),
                  ];

                  if (stackQuickActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < quickCards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          quickCards[i],
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: quickCards[0]),
                      if (quickCards.length > 1) ...[
                        const SizedBox(width: 12),
                        Expanded(child: quickCards[1]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessCard(IconData icon, String label, VoidCallback onTap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 180;
        final double iconSize = isCompact ? 22 : 24;
        final double fontSize = isCompact ? 12 : 13;
        final double verticalPadding = isCompact ? 16 : 18;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize + 16,
                  height: iconSize + 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(icon, color: Colors.white, size: iconSize),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label.replaceAll('\n', ' '),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileActions({required bool centered}) {
    final buttons = <Widget>[
      _buildProfileActionButton(Icons.chat_bubble_outline, _handleViewMessages),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.end,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
      ],
    );
  }

  Widget _buildProfileActionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF16C79A),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _handleViewDocuments() {
    if (widget.onNavigateToDocuments != null) {
      widget.onNavigateToDocuments!();
    } else {
      _showDocumentsOverview();
    }
  }

  void _handleViewPayments() {
    if (widget.onNavigateToPayments != null) {
      widget.onNavigateToPayments!();
    } else {
      _showPaymentSchedule();
    }
  }

  void _handleViewProfile() {
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      _showNavigationFallback('el perfil');
    }
  }

  void _handleViewMessages() {
    if (widget.onNavigateToMessages != null) {
      widget.onNavigateToMessages!();
    } else {
      _showNavigationFallback('los mensajes');
    }
  }

  void _showDocumentsOverview() {
    final entries = _documents.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final sheetChildren = <Widget>[
      Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Documentos del conductor',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
    ];

    if (entries.isEmpty) {
      sheetChildren.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No hay documentos registrados.', style: TextStyle(color: Colors.white70)),
      ));
    } else {
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final expiry = entry.value;
        final payment = _paymentDates?[entry.key];
        final days = expiry.difference(DateTime.now()).inDays;
        final details = <String>['Vence: ${_formatDate(expiry)}'];
        if (payment != null) details.add('Pago: ${_formatDate(payment)}');

        if (i > 0) {
          sheetChildren.add(const Divider(color: Colors.white24, height: 24));
        }

        sheetChildren.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.description, color: Colors.white),
            ),
            title: Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${details.join(' • ')}\n${days.clamp(0, 999)} días restantes',
              style: const TextStyle(color: Colors.white70, height: 1.2),
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.of(context).pop();
              DocumentModal.show(
                context: context,
                documentName: entry.key,
                creationDate: payment,
                expiryDate: expiry,
              );
            },
          ),
        );
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1445),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sheetChildren,
            ),
          ),
        );
      },
    );
  }

  void _showPaymentSchedule() {
    final entries = (_paymentDates ?? {}).entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final sheetChildren = <Widget>[
      Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Próximos pagos',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
    ];

    if (entries.isEmpty) {
      sheetChildren.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No hay pagos programados.', style: TextStyle(color: Colors.white70)),
      ));
    } else {
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final relatedExpiry = _documents[entry.key];

        if (i > 0) {
          sheetChildren.add(const Divider(color: Colors.white24, height: 24));
        }

        sheetChildren.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.payments, color: Colors.white),
            ),
            title: Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Pago: ${_formatDate(entry.value)}${relatedExpiry != null ? '\nVence: ${_formatDate(relatedExpiry)}' : ''}',
              style: const TextStyle(color: Colors.white70, height: 1.2),
            ),
            isThreeLine: relatedExpiry != null,
            onTap: () {
              Navigator.of(context).pop();
              if (relatedExpiry != null) {
                DocumentModal.show(
                  context: context,
                  documentName: entry.key,
                  creationDate: entry.value,
                  expiryDate: relatedExpiry,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No hay fecha de vencimiento para ${entry.key}'),
                    backgroundColor: const Color(0xFF16C79A),
                  ),
                );
              }
            },
          ),
        );
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1445),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sheetChildren,
            ),
          ),
        );
      },
    );
  }

  void _showNavigationFallback(String destination) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configura la navegación hacia $destination para continuar.'),
        backgroundColor: const Color(0xFF16C79A),
      ),
    );
  }

  Widget _empresaInicio() {
    final DateTime now = DateTime.now();
    final int totalDrivers = (_summaryMetrics['activeDrivers'] as num?)?.toInt() ?? 0;
    final int fleetSize = (_summaryMetrics['fleetSize'] as num?)?.toInt() ?? _fleetVehicles.length;
    final int documentsExpired = (_summaryMetrics['documentsExpired'] as num?)?.toInt()
      ?? _documents.entries.where((entry) => entry.value.isBefore(now)).length;
    final int maintenanceScheduled = (_summaryMetrics['maintenanceScheduled'] as num?)?.toInt() ?? 0;
    final int certificateRequests = (_summaryMetrics['certificateRequests'] as num?)?.toInt() ?? _alerts.length;
    final int totalPropietarios = _propietarios.length;

    final List<MapEntry<String, DateTime>> upcomingDocs = _upcomingDocs(limit: 3);

    final VoidCallback documentsTap = widget.onNavigateToDocuments ?? () => _showNavigationFallback('Documentos');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.white.withValues(alpha: 0.06),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/vehicles.webp',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Panel Empresa',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Supervisa tus indicadores corporativos, próximos vencimientos y operaciones clave.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSummaryChip(Icons.apartment_rounded, '$fleetSize vehículos', 'Flota total'),
                      _buildSummaryChip(Icons.badge_rounded, '$totalDrivers conductores', 'Activos hoy'),
                      _buildSummaryChip(Icons.person_rounded, '$totalPropietarios propietarios', 'Ligados'),
                      _buildSummaryChip(Icons.warning_amber_rounded, '$documentsExpired vencidos', 'Documentos vencidos'),
                      _buildSummaryChip(Icons.build_circle_rounded, '$maintenanceScheduled mantenimientos', 'Programados'),
                      _buildSummaryChip(Icons.assignment_turned_in_rounded, '$certificateRequests solicitudes', 'Certificados'),
                    ],
                  ),
                ),
                if (upcomingDocs.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const Text(
                    'Documentos corporativos próximos a vencer',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentCountdownGrid(upcomingDocs),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: documentsTap,
                      icon: const Icon(Icons.folder_copy_rounded, color: Color(0xFF16C79A)),
                      label: const Text('Ir al módulo de documentos', style: TextStyle(color: Color(0xFF16C79A))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _propietarioInicio() {
    final totalVehicles = _fleetVehicles.length;
    final docsExpiringSoon = _documents.entries
        .where((entry) => entry.value.isBefore(DateTime.now().add(const Duration(days: 30))))
        .length;
    final vehiclesToShow = _fleetVehicles.take(3).toList();

    final List<MapEntry<String, DateTime>> upcomingDocEntries = _documents.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final List<MapEntry<String, DateTime>> limitedUpcoming = upcomingDocEntries.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.transparent,
                    child: Image.asset(
                      'assets/vehicles.webp',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Panel Propietario', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Resumen de tu flota y próximos vencimientos.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildSummaryChip(Icons.directions_bus, '$totalVehicles vehículos', 'Activos registrados'),
                        _buildSummaryChip(Icons.warning_amber_rounded, '$docsExpiringSoon vencimientos', 'Próximos 30 días'),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                if (limitedUpcoming.isNotEmpty) ...[
                  const Text('Documentos próximos a vencer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _buildDocumentCountdownGrid(limitedUpcoming),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _showDocumentsOverview,
                        icon: const Icon(Icons.folder_copy, color: Color(0xFF16C79A)),
                        label: const Text('Ver todos los documentos', style: TextStyle(color: Color(0xFF16C79A))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Vehículos asignados', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ListView.separated(
                      itemCount: vehiclesToShow.length,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final vehicle = vehiclesToShow[index];
                        return _buildVehicleCard(vehicle);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.directions_car, color: Colors.white),
                      label: const Text('Ver todos los vehículos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ver todos los vehículos aún no está disponible.')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secretariaInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Panel Secretaría', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Tareas administrativas y solicitudes.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        _infoCard(Icons.request_page, 'Solicitudes nuevas', '8'),
      ]),
    );
  }

  Widget _adminInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Panel Admin', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Vista global del sistema.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        _infoCard(Icons.settings, 'Configuraciones', ''),
      ]),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.white24, child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white))),
          if (value.isNotEmpty) Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF16C79A), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCountdownGrid(List<MapEntry<String, DateTime>> docs) {
    const double spacing = 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        if (maxWidth.isInfinite || maxWidth <= 0) {
          maxWidth = MediaQuery.of(context).size.width;
        }

        int columns = docs.isEmpty ? 1 : docs.length;
        if (columns > 3) {
          columns = 3;
        }

        while (columns > 1) {
          final double candidateWidth = (maxWidth - spacing * (columns - 1)) / columns;
          if (candidateWidth >= 80) {
            break;
          }
          columns -= 1;
        }

        final double totalSpacing = spacing * (columns - 1);
        final double itemWidth = (maxWidth - totalSpacing) / columns;
        final double countdownSize = itemWidth.clamp(78.0, 110.0);

        return Align(
          alignment: Alignment.center,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.center,
            children: docs.map((entry) {
              final DateTime expiry = entry.value;
              final int daysRemaining = expiry.difference(DateTime.now()).inDays;
              final int totalDays = daysRemaining <= 90 ? 90 : daysRemaining;
              final DateTime? paymentDate = _paymentDates?[entry.key];
              final String detailLabel = _documentVehicle[entry.key] ?? 'Sin detalle';

              return SizedBox(
                width: itemWidth,
                child: GestureDetector(
                  onTap: () => DocumentModal.show(
                    context: context,
                    documentName: entry.key,
                    creationDate: paymentDate,
                    expiryDate: expiry,
                  ),
                  child: DocumentCountdown(
                    expiry: expiry,
                    paymentDate: paymentDate,
                    totalDuration: Duration(days: totalDays),
                    title: entry.key,
                    subtitle: '$detailLabel\n${daysRemaining.clamp(0, 999)} días',
                    size: countdownSize,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }


  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final DateTime? nextExpiry = vehicle['nextExpiry'] as DateTime?;

    Color statusColor;
    switch ((vehicle['status'] as String).toLowerCase()) {
      case 'al día':
        statusColor = const Color(0xFF16C79A);
        break;
      case 'documentos pendientes':
        statusColor = const Color(0xFFEFB549);
        break;
      case 'en mantenimiento':
        statusColor = const Color(0xFFE66B6B);
        break;
      default:
        statusColor = Colors.white54;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white12,
            child: Text(
              (vehicle['plate'] as String).split('-').first,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(vehicle['plate'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        vehicle['status'] as String,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildVehicleInfoRow('Modelo', vehicle['model'] as String),
                _buildVehicleInfoRow('Conductor', vehicle['driver'] as String),
                if (nextExpiry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildVehicleInfoRow('Próximo vencimiento', _formatDate(nextExpiry)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
            onPressed: () {
              if (nextExpiry != null) {
                DocumentModal.show(
                  context: context,
                  documentName: 'Ficha vehículo ${vehicle['plate']}',
                  expiryDate: nextExpiry,
                  creationDate: null,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No hay documento asociado para ${vehicle['plate']}'),
                    backgroundColor: const Color(0xFF16C79A),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

}

// A small reusable countdown + circular progress widget for documentos.

class DocumentCountdown extends StatefulWidget {
  final DateTime expiry;
  final DateTime? paymentDate; // Fecha de pago
  final Duration totalDuration; // the total period to compute progress from
  final String title;
  final String subtitle;
  final double size;

  const DocumentCountdown({
    super.key,
    required this.expiry,
    this.paymentDate,
    required this.totalDuration,
    this.title = '',
    this.subtitle = '',
    this.size = 120,
  });

  @override
  State<DocumentCountdown> createState() => _DocumentCountdownState();
}

class _DocumentCountdownState extends State<DocumentCountdown> {
  late Duration _remaining;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _updateRemaining() {
    final now = DateTime.now();
    _remaining = widget.expiry.difference(now);
    if (_remaining.isNegative) _remaining = Duration.zero;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _updateRemaining();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalDuration.inSeconds > 0 ? widget.totalDuration.inSeconds : 1;
    final remain = _remaining.inSeconds.clamp(0, total);
    final percent = total > 0 ? (remain / total) : 0.0;

    // Render a circular ring with numeric remaining time
    final double size = widget.size;
    final double stroke = (size / 8).clamp(8.0, 20.0);
    return Column(
      children: [
        SizedBox(
          height: size + 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: stroke,
                  color: const Color(0xFF16C79A),
                  backgroundColor: Colors.white24,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatRemaining(_remaining), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: (size / 6).clamp(12.0, 18.0))),
                  const SizedBox(height: 4),
                  Text(_humanUnit(_remaining), style: TextStyle(color: Colors.white70, fontSize: (size / 10).clamp(10.0, 12.0))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  String _formatRemaining(Duration d) {
    if (d == Duration.zero) return '0';
    if (d.inDays >= 1) return '${d.inDays}';
    if (d.inHours >= 1) return '${d.inHours}';
    if (d.inMinutes >= 1) return '${d.inMinutes}';
    return '${d.inSeconds}';
  }

  String _humanUnit(Duration d) {
    if (d == Duration.zero) return 'expirado';
    if (d.inDays >= 1) return '/ días';
    if (d.inHours >= 1) return '/ horas';
    if (d.inMinutes >= 1) return '/ minutos';
    return '/ segundos';
  }
}
