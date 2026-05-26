import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_language.dart';
import '../services/api_service.dart';
import 'documents/document_preview_modal.dart';
import 'utils/shimmer_skeleton.dart';

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
  final Map<String, Map<String, dynamic>> _documentRawData = {};
  Map<String, dynamic> _summaryMetrics = {};
  final List<Map<String, dynamic>> _alerts = [];

  // User profile data
  String _userName = 'Usuario';
  String _userCompany = 'Empresa';
  String? _userProfileImage;

  String _metric(int count, String singularKey, String pluralKey) {
    return '$count ${context.t(count == 1 ? singularKey : pluralKey)}';
  }

  @override
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
    await Future.wait([_loadDocuments(), _loadUserProfile()]);
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

          final mantenimientos = await ApiService.getMantenimientos(
            role: _role,
            userId: widget.userId,
          );

          final programados = mantenimientos.where((m) {
            final estado = m['estado']?.toString().toUpperCase() ?? '';
            return estado == 'PROGRAMADO';
          }).length;

          final sugeridos = mantenimientos.where((m) {
            final estado = m['estado']?.toString().toUpperCase() ?? '';
            return estado == 'SUGERIDO';
          }).length;

          // ✅ Solicitudes pendientes de responder para la empresa
          final solicitudes = await ApiService.getSolicitudes();

          final solicitudesPendientes = solicitudes.where((s) {
            final estado = s['estado']?.toString().trim().toUpperCase() ?? '';
            return estado == 'EN_REVISION';
          }).length;

          summary = {
            'fleetSize': vehiculos.length,
            'activeDrivers': conductores.length,
            'documentsExpired': vencidos.length,
            'maintenanceScheduled': programados,
            'maintenanceSuggested': sugeridos,
            'certificateRequests': solicitudesPendientes,
          };

          // Guardar propietarios en el estado
          if (mounted) {
            setState(() {
              _propietarios = propietarios;
            });
          }

          //   '✅ EMPRESA: ${backendDocs.length} documentos, ${vehiculos.length} vehículos, ${propietarios.length} propietarios',
          // );
          break;

        case 'conductor':
          // Conductor: datos propios + vehículos asignados
          // Cargar documentos de la empresa (ya están filtrados por empresa en backend)
          final backendDocs = await ApiService.getMisDocumentos();
          _processDocuments(backendDocs, docs, docDetails);

          // Vehículos asignados al conductor
          try {
            final vehiculos = await ApiService.getMisVehiculos();
            if (vehiculos.isNotEmpty) {
              fleet = _processVehiculos(vehiculos);
            }
          } catch (_) {
          }

          // Calcular resumen
          final DateTime todayOnlyCond = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
          final vencidosCond = backendDocs.where((doc) {
            final fecha = doc['fechaVencimiento'];
            if (fecha == null) return false;
            final vencimiento = DateTime.tryParse(fecha.toString());
            if (vencimiento == null) return false;
            final vencimientoOnly = DateTime(
              vencimiento.year,
              vencimiento.month,
              vencimiento.day,
            );
            return vencimientoOnly.isBefore(todayOnlyCond);
          }).length;

          final proximosCond = backendDocs.where((doc) {
            final fecha = doc['fechaVencimiento'];
            if (fecha == null) return false;
            final vencimiento = DateTime.tryParse(fecha.toString());
            if (vencimiento == null) return false;
            final vencimientoOnly = DateTime(
              vencimiento.year,
              vencimiento.month,
              vencimiento.day,
            );
            final diff = vencimientoOnly.difference(todayOnlyCond).inDays;
            return diff > 0 && diff <= 30;
          }).length;

          final mantenimientosCond = await ApiService.getMantenimientos(
            role: _role,
            userId: widget.userId,
          );

          final programadosCond = mantenimientosCond.where((m) {
            final estado = m['estado']?.toString().toUpperCase() ?? '';
            return estado == 'PROGRAMADO';
          }).length;

          final sugeridosCond = mantenimientosCond.where((m) {
            final estado = m['estado']?.toString().toUpperCase() ?? '';
            return estado == 'SUGERIDO';
          }).length;

          summary = {
            'assignedVehicles': fleet.length,
            'myDocuments': backendDocs.length,
            'expiredDocuments': vencidosCond,
            'expiringInDays': proximosCond,
            'maintenanceScheduled': programadosCond,
            'maintenanceSuggested': sugeridosCond,
          };

          //   '✅ CONDUCTOR: ${backendDocs.length} documentos, ${fleet.length} vehículos',
          // );
          break;

        case 'propietario':
          // Propietario: documentos de la empresa (ya están filtrados por empresa en backend)
          final backendDocsP = await ApiService.getMisDocumentos();
          _processDocuments(backendDocsP, docs, docDetails);

          // Vehículos del propietario
          try {
            final vehiculos = await ApiService.getMisVehiculos();
            if (vehiculos.isNotEmpty) {
              fleet = _processVehiculos(vehiculos);
            }
          } catch (_) {
          }

          // Calcular resumen
          final DateTime todayOnlyProp = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
          final vencidosProp = backendDocsP.where((doc) {
            final fecha = doc['fechaVencimiento'];
            if (fecha == null) return false;
            final vencimiento = DateTime.tryParse(fecha.toString());
            if (vencimiento == null) return false;
            final vencimientoOnly = DateTime(
              vencimiento.year,
              vencimiento.month,
              vencimiento.day,
            );
            return vencimientoOnly.isBefore(todayOnlyProp);
          }).length;

          final proximosAvencerProp = backendDocsP.where((doc) {
            final fecha = doc['fechaVencimiento'];
            if (fecha == null) return false;
            final vencimiento = DateTime.tryParse(fecha.toString());
            if (vencimiento == null) return false;
            final vencimientoOnly = DateTime(
              vencimiento.year,
              vencimiento.month,
              vencimiento.day,
            );
            final diff = vencimientoOnly.difference(todayOnlyProp).inDays;
            return diff > 0 && diff <= 30;
          }).length;

          final mantenimientosProp = await ApiService.getMantenimientos(
            role: _role,
            userId: widget.userId,
          );

          final programadosProp = mantenimientosProp.where((m) {
            final estado = m['estado']?.toString().toUpperCase() ?? '';
            return estado == 'PROGRAMADO';
          }).length;

          final sugeridosProp = mantenimientosProp.where((m) {
            final estado = m['estado']?.toString().toUpperCase() ?? '';
            return estado == 'SUGERIDO';
          }).length;

          summary = {
            'myVehicles': fleet.length,
            'myDocuments': backendDocsP.length,
            'expiredDocuments': vencidosProp,
            'expiringInDays': proximosAvencerProp,
            'maintenanceScheduled': programadosProp,
            'maintenanceSuggested': sugeridosProp,
          };

          //   '✅ PROPIETARIO: ${backendDocsP.length} documentos, ${fleet.length} vehículos',
          // );
          break;

        case 'secretaria':
          // Secretaria: documentos de la empresa (ya están filtrados por empresa en backend)
          final backendDocsS = await ApiService.getDocumentosEmpresa();
          _processDocuments(backendDocsS, docs, docDetails);
          //   '✅ SECRETARIA: ${backendDocsS.length} documentos cargados',
          // );
          break;

        case 'admin':
          // Admin: puede ver documentos de todas las empresas
          final backendDocs = await ApiService.getDocumentosEmpresa();
          _processDocuments(backendDocs, docs, docDetails);
          final vehiculos = await ApiService.getVehiculos();
          fleet = _processVehiculos(vehiculos);
          final vencidos = await ApiService.getDocumentosVencidos();
          summary = {
            'totalDocuments': backendDocs.length,
            'totalVehicles': vehiculos.length,
            'documentsExpired': vencidos.length,
          };
          break;

        default:
          break;
      }
    } catch (_) {
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
    _documentRawData.clear();

    for (final doc in backendDocs) {
      final bool estadoDocumento =
          doc['estadoDocumento'] == true ||
          doc['estado_documento'] == true ||
          doc['estadoDocumento']?.toString().toLowerCase() == 'true' ||
          doc['estado_documento']?.toString().toLowerCase() == 'true';

      if (!estadoDocumento) continue;
      final String tipoNombre =
          doc['nombreTipoDocumento']?.toString() ??
          doc['tipoDocumento']?['nombre']?.toString() ??
          doc['tipo']?.toString() ??
          doc['nombre']?.toString() ??
          'Documento';

      final dynamic docId =
          doc['idDocumento'] ?? doc['id_documento'] ?? doc['id'];

      final String uniqueKey = docId != null
          ? '$tipoNombre-$docId'
          : '$tipoNombre-${doc['fechaVencimiento'] ?? docs.length}';

      final String? vencimientoStr = doc['fechaVencimiento']?.toString();
      if (vencimientoStr != null && vencimientoStr.isNotEmpty) {
        final vencimiento = DateTime.tryParse(vencimientoStr);
        if (vencimiento != null) {
          docs[uniqueKey] = vencimiento;
          _documentRawData[uniqueKey] = doc;
        }
      }

      final String vehiculoPlaca =
          doc['placa']?.toString() ??
          doc['vehiculoPlaca']?.toString() ??
          doc['vehiculo']?['placa']?.toString() ??
          '';

      final String nombreUsuario =
          doc['nombreUsuario']?.toString() ??
          doc['usuarioNombre']?.toString() ??
          doc['conductorNombre']?.toString() ??
          doc['propietarioNombre']?.toString() ??
          doc['usuario']?['nombre']?.toString() ??
          '';

      final List<String> detailParts = [];

      if (vehiculoPlaca.isNotEmpty) {
        detailParts.add('Placa: $vehiculoPlaca');
      }

      if (nombreUsuario.isNotEmpty) {
        detailParts.add(nombreUsuario);
      }

      if (detailParts.isNotEmpty) {
        docDetails[uniqueKey] = detailParts.join(' · ');
      }
    }
  }

  /// Procesa vehículos del backend para mostrar en flota
  List<Map<String, dynamic>> _processVehiculos(
    List<Map<String, dynamic>> vehiculos,
  ) {
    return vehiculos.map((vehiculo) {
      final DateTime? nextExpiry = _calculateNextExpiry(vehiculo);

      // Extraer nombre del conductor desde conductor.usuario.nombre/apellido
      String driverName = 'No asignado';
      if (vehiculo['conductor'] != null && vehiculo['conductor'] is Map) {
        final conductor = vehiculo['conductor'] as Map;
        if (conductor['usuario'] != null && conductor['usuario'] is Map) {
          final usuario = conductor['usuario'] as Map;
          final nombre = usuario['nombre']?.toString() ?? '';
          final apellido = usuario['apellido']?.toString() ?? '';
          if (nombre.isNotEmpty || apellido.isNotEmpty) {
            driverName = '$nombre $apellido'.trim();
          }
        }
      }

      // Extraer datos del propietario
      String ownerName = 'Sin definir';
      if (vehiculo['propietario'] != null && vehiculo['propietario'] is Map) {
        final propietario = vehiculo['propietario'] as Map;
        if (propietario['usuario'] != null && propietario['usuario'] is Map) {
          final usuario = propietario['usuario'] as Map;
          final nombre = usuario['nombre']?.toString() ?? '';
          final apellido = usuario['apellido']?.toString() ?? '';
          if (nombre.isNotEmpty || apellido.isNotEmpty) {
            ownerName = '$nombre $apellido'.trim();
          }
        }
      }

      // Extraer datos de la licencia del conductor
      String licenseNumber = '';
      String licenseCategory = '';
      DateTime? licenseExpiry;
      if (vehiculo['conductor'] != null && vehiculo['conductor'] is Map) {
        final conductor = vehiculo['conductor'] as Map;
        licenseNumber = conductor['licenciaConduccion']?.toString() ?? '';
        licenseCategory = conductor['categoriaLicencia']?.toString() ?? '';
        final expDate = conductor['fechaVencimientoLicencia'];
        if (expDate != null) {
          licenseExpiry = DateTime.tryParse(expDate.toString());
        }
      }

      return {
        'id': vehiculo['idVehiculo'] ?? vehiculo['id'],
        'plate': vehiculo['placa']?.toString() ?? 'N/A',
        'model':
            '${vehiculo['marca']?.toString() ?? ''} ${vehiculo['modelo']?.toString() ?? ''}'
                .trim(),
        'driver': driverName,
        'owner': ownerName,
        'year': vehiculo['anio']?.toString() ?? '',
        'color': vehiculo['color']?.toString() ?? '',
        'vin': vehiculo['vin']?.toString() ?? '',
        'mileage': vehiculo['kilometrajeActual'] ?? 0,
        'status': vehiculo['estadoVehiculo']?.toString() ?? 'ACTIVO',
        'nextExpiry':
            nextExpiry ?? DateTime.now().add(const Duration(days: 30)),
        'lastService': DateTime.now().subtract(const Duration(days: 30)),
        'licenseNumber': licenseNumber,
        'licenseCategory': licenseCategory,
        'licenseExpiry': licenseExpiry,
      };
    }).toList();
  }

  /// Calcula el próximo vencimiento de documentos para un vehículo
  DateTime? _calculateNextExpiry(Map<String, dynamic> vehiculo) {
    DateTime? earliest;
    final docs = vehiculo['documentos'] as List?;
    if (docs != null) {
      for (final doc in docs) {
        if (doc is Map) {
          final venc = DateTime.tryParse(
            doc['fechaVencimiento']?.toString() ?? '',
          );
          if (venc != null && (earliest == null || venc.isBefore(earliest))) {
            earliest = venc;
          }
        }
      }
    }
    return earliest;
  }

  Future<void> _loadUserProfile() async {
    try {
      final perfilBackend = await ApiService.getMiPerfil();

      final String nombre = perfilBackend?['nombre']?.toString() ?? '';
      final String apellido = perfilBackend?['apellido']?.toString() ?? '';
      final String nombreCompleto = '$nombre $apellido'.trim();

      final empresa = perfilBackend?['empresa'];
      String empresaNombre = _userCompany;

      if (empresa is Map<String, dynamic>) {
        empresaNombre = empresa['nombreEmpresa']?.toString() ?? _userCompany;
      }

      if (mounted) {
        setState(() {
          if (nombreCompleto.isNotEmpty) _userName = nombreCompleto;
          if (empresaNombre.isNotEmpty) _userCompany = empresaNombre;
        });
      }

      return;
    } catch (_) {
    }

    if (widget.userProfilePath == null || widget.userProfilePath!.isEmpty) {
      return;
    }

    try {
      final String raw = await rootBundle.loadString(widget.userProfilePath!);
      final dynamic decoded = json.decode(raw);
      final List<Map<String, dynamic>> candidates = _extractUserRecords(
        decoded,
      );

      Map<String, dynamic>? userData;
      if (candidates.isNotEmpty) {
        if (widget.userId != null && widget.userId!.isNotEmpty) {
          userData = candidates.firstWhere((entry) {
            final dynamic candidateId =
                entry['id'] ?? entry['id_usuario'] ?? entry['id_empresa'];
            return candidateId != null &&
                candidateId.toString() == widget.userId;
          }, orElse: () => candidates.first);
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
        }
        // } else {
        // }
      }

      final String resolvedName =
          userData['name']?.toString() ??
          userData['nombre']?.toString() ??
          userData['representanteLegal']?.toString() ??
          _userName;

      String resolvedCompany =
          userData['company']?.toString() ??
          userData['nombreEmpresa']?.toString() ??
          userData['razonSocial']?.toString() ??
          userData['descripcion']?.toString() ??
          _userCompany;

      if (_role.toLowerCase() == 'empresa') {
        resolvedCompany =
            userData['vision']?.toString() ??
            userData['descripcion']?.toString() ??
            resolvedCompany;
      }

      if (!mounted) return;
      setState(() {
        _userName = resolvedName.isNotEmpty ? resolvedName : _userName;
        _userCompany = resolvedCompany.isNotEmpty
            ? resolvedCompany
            : _userCompany;
        _userProfileImage = profileImageCandidate;
      });
    } catch (_) {
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
        .map(
          (record) =>
              record.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  DateTime? _getDocumentCreationDate(String documentKey) {
    final rawDoc = _documentRawData[documentKey];

    final creationStr =
        rawDoc?['fechaCreacion']?.toString() ??
        rawDoc?['fecha_creacion']?.toString() ??
        rawDoc?['createdAt']?.toString();

    if (creationStr == null || creationStr.isEmpty) return null;

    return DateTime.tryParse(creationStr);
  }

  /// Return list of entries sorted by soonest expiry
  List<MapEntry<String, DateTime>> _upcomingDocs({int limit = 3}) {
    final entries = _documents.entries.toList();
    entries.sort((a, b) {
      final DateTime today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final int daysA = a.value.difference(today).inDays;
      final int daysB = b.value.difference(today).inDays;

      // Orden personalizado: vencidos primero (más tiempo vencido primero), luego próximos (menos días primero)
      if (daysA < 0 && daysB < 0) {
        return daysA.compareTo(daysB); // Más negativo primero
      } else if (daysA < 0 && daysB >= 0) {
        return -1; // Vencidos primero
      } else if (daysA >= 0 && daysB < 0) {
        return 1; // Vencidos primero
      } else {
        return daysA.compareTo(daysB); // Menos días primero
      }
    });
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
      children: [Expanded(child: roleContent)],
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
          Icon(
            Icons.dashboard_customize,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Selecciona un rol para explorar su panel.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 16),
        ],
      ),
    );
  }

  Widget _conductorInicio() {
    final int totalVehicles = _fleetVehicles.length;
    final int myDocuments = _documents.length;
    final int maintenanceScheduled =
        (_summaryMetrics['maintenanceScheduled'] as num?)?.toInt() ?? 0;

    final int maintenanceSuggested =
        (_summaryMetrics['maintenanceSuggested'] as num?)?.toInt() ?? 0;
    final DateTime todayOnly = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final int docsExpired = _documents.entries.where((entry) {
      final DateTime expiryOnly = DateTime(
        entry.value.year,
        entry.value.month,
        entry.value.day,
      );
      return expiryOnly.isBefore(todayOnly);
    }).length;
    final int docsExpiringSoon = _documents.entries.where((entry) {
      final DateTime expiryOnly = DateTime(
        entry.value.year,
        entry.value.month,
        entry.value.day,
      );
      return expiryOnly.isBefore(todayOnly.add(const Duration(days: 30))) &&
          expiryOnly.isAfter(todayOnly);
    }).length;
    final List<Map<String, dynamic>> vehiclesToShow = _fleetVehicles
        .take(3)
        .toList();
    final List<MapEntry<String, DateTime>> upcomingDocs = _upcomingDocs(
      limit: 3,
    );

    // Debug
    //   '📊 CONDUCTOR PANEL: Documents=${_documents.length}, Vehicles=${_fleetVehicles.length}, Summary=$_summaryMetrics',
    // );

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
                // Banner
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
                // Título
                Text(
                  context.t('home.driverPanel'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('home.driverSubtitle'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                // Chips de resumen
                Align(
                  alignment: Alignment.center,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSummaryChip(
                        Icons.directions_car,
                        _metric(totalVehicles, 'home.vehicle', 'home.vehicles'),
                        context.t('home.assigned'),
                      ),
                      _buildSummaryChip(
                        Icons.description_rounded,
                        _metric(myDocuments, 'home.document', 'home.documents'),
                        context.t('home.personal'),
                      ),
                      _buildSummaryChip(
                        Icons.warning_amber_rounded,
                        '$docsExpired ${context.t('home.expiredStatus').toLowerCase()}',
                        context.t('home.expired'),
                      ),
                      _buildSummaryChip(
                        Icons.schedule_rounded,
                        '$docsExpiringSoon ${context.t('home.next')}',
                        context.t('home.next30'),
                      ),
                      _buildSummaryChip(
                        Icons.build_circle_rounded,
                        '$maintenanceScheduled ${context.t('home.maintenancePlural')}',
                        context.t('home.scheduled'),
                      ),
                      _buildSummaryChip(
                        Icons.tips_and_updates_rounded,
                        '$maintenanceSuggested ${context.t('home.maintenancePlural')}',
                        context.t('home.suggested'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                // Documentos próximos a vencer
                if (upcomingDocs.isNotEmpty) ...[
                  Text(
                    context.t('home.yourDocsExpiring'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentCountdownGrid(upcomingDocs),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: _handleViewDocuments,
                      icon: const Icon(
                        Icons.folder_copy_rounded,
                        color: Color(0xFF16C79A),
                      ),
                      label: Text(
                        context.t('home.viewAllDocuments'),
                        style: const TextStyle(color: Color(0xFF16C79A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        context.t('home.noDocuments'),
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                // Vehículos asignados
                if (vehiclesToShow.isNotEmpty) ...[
                  Text(
                    context.t('home.assignedVehicles'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                  if (totalVehicles > 3) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.t('home.vehiclesUnavailable'),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          context.t('home.viewAllVehicles'),
                          style: const TextStyle(color: Color(0xFF16C79A)),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        context.t('home.noVehicles'),
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
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

  // ignore: unused_element
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
                      backgroundImage:
                          _userProfileImage != null &&
                              _userProfileImage!.isNotEmpty
                          ? AssetImage(_userProfileImage!)
                          : null,
                      child:
                          _userProfileImage == null ||
                              _userProfileImage!.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 34,
                              color: Colors.white70,
                            )
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
                  final bool showPaymentCard =
                      _role.toLowerCase() != 'propietario';
                  final quickCards = <Widget>[
                    _buildQuickAccessCard(
                      Icons.folder_open,
                      context.t('home.viewDocuments'),
                      _handleViewDocuments,
                    ),
                    if (showPaymentCard)
                      _buildQuickAccessCard(
                        Icons.payments,
                        context.t('home.pendingPayments'),
                        _handleViewPayments,
                      ),
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

  Widget _buildQuickAccessCard(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
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
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: verticalPadding,
            ),
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
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.end,
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
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        context.t('home.driverDocuments'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
    ];

    if (entries.isEmpty) {
      sheetChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            context.t('home.noDocuments'),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    } else {
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final expiry = entry.value;
        final payment = _paymentDates?[entry.key];
        // Calcular días usando solo fechas, sin considerar horas
        final DateTime todayOnly = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        final DateTime expiryOnly = DateTime(
          expiry.year,
          expiry.month,
          expiry.day,
        );
        final int days = expiryOnly.difference(todayOnly).inDays;
        final details = <String>['${context.t('home.expires')}: ${_formatDate(expiry)}'];
        if (payment != null) details.add('${context.t('home.payment')}: ${_formatDate(payment)}');

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
            title: Text(
              entry.key.split('-').first,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${details.join(' • ')}\n${days < 0
                  ? context.t('home.expiredStatus')
                  : days == 0
                  ? context.t('home.expiresToday')
                  : '$days ${context.t('home.daysRemaining')}'}',
              style: TextStyle(
                color: days < 0
                    ? Colors.red[300]
                    : days == 0
                    ? Colors.amber[300]
                    : Colors.white70,
                height: 1.2,
              ),
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.of(context).pop();
              final rawDoc = _documentRawData[entry.key] ?? {};

              final fileUrl =
                  rawDoc['urlStorage']?.toString() ??
                  rawDoc['urlDocumento']?.toString() ??
                  rawDoc['url']?.toString() ??
                  rawDoc['rutaDocumento']?.toString() ??
                  rawDoc['fileUrl']?.toString() ??
                  '';

              final observations =
                  rawDoc['observaciones']?.toString() ??
                  rawDoc['observacion']?.toString() ??
                  '';

              DocumentPreviewModal.show(
                context: context,
                documentName: entry.key.split('-').first,
                fileUrl: fileUrl,
                expiryDate: expiry,
                observations: observations,
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
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        context.t('home.nextPayments'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
    ];

    if (entries.isEmpty) {
      sheetChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            context.t('home.noPayments'),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
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
            title: Text(
              entry.key.split('-').first,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${context.t('home.payment')}: ${_formatDate(entry.value)}${relatedExpiry != null ? '\n${context.t('home.expires')}: ${_formatDate(relatedExpiry)}' : ''}',
              style: const TextStyle(color: Colors.white70, height: 1.2),
            ),
            isThreeLine: relatedExpiry != null,
            onTap: () {
              Navigator.of(context).pop();
              if (relatedExpiry != null) {
                final rawDoc = _documentRawData[entry.key] ?? {};

                final fileUrl =
                    rawDoc['urlStorage']?.toString() ??
                    rawDoc['urlDocumento']?.toString() ??
                    rawDoc['url']?.toString() ??
                    rawDoc['rutaDocumento']?.toString() ??
                    rawDoc['fileUrl']?.toString() ??
                    '';

                final observations =
                    rawDoc['observaciones']?.toString() ??
                    rawDoc['observacion']?.toString() ??
                    '';

                DocumentPreviewModal.show(
                  context: context,
                  documentName: entry.key.split('-').first,
                  fileUrl: fileUrl,
                  expiryDate: relatedExpiry,
                  observations: observations,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${context.t('home.noDueDate')} ${entry.key}',
                    ),
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
        content: Text(
          'Configura la navegación hacia $destination para continuar.',
        ),
        backgroundColor: const Color(0xFF16C79A),
      ),
    );
  }

  Widget _empresaInicio() {
    final DateTime todayOnly = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final int totalDrivers =
        (_summaryMetrics['activeDrivers'] as num?)?.toInt() ?? 0;
    final int fleetSize =
        (_summaryMetrics['fleetSize'] as num?)?.toInt() ??
        _fleetVehicles.length;
    final int documentsExpired = _documents.entries.where((entry) {
      final DateTime expiryOnly = DateTime(
        entry.value.year,
        entry.value.month,
        entry.value.day,
      );
      return expiryOnly.isBefore(todayOnly);
    }).length;
    final int maintenanceScheduled =
        (_summaryMetrics['maintenanceScheduled'] as num?)?.toInt() ?? 0;
    final int maintenanceSuggested =
        (_summaryMetrics['maintenanceSuggested'] as num?)?.toInt() ?? 0;
    final int certificateRequests =
        (_summaryMetrics['certificateRequests'] as num?)?.toInt() ??
        _alerts.length;
    final int totalPropietarios = _propietarios.length;

    final List<MapEntry<String, DateTime>> upcomingDocs = _upcomingDocs(
      limit: 3,
    );

    final VoidCallback documentsTap =
        widget.onNavigateToDocuments ??
        () => _showNavigationFallback('Documentos');

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
                Text(
                  context.t('home.companyPanel'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('home.companySubtitle'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSummaryChip(
                        Icons.apartment_rounded,
                        _metric(fleetSize, 'home.vehicle', 'home.vehicles'),
                        context.t('home.totalFleet'),
                      ),
                      _buildSummaryChip(
                        Icons.badge_rounded,
                        '$totalDrivers ${context.t('home.drivers')}',
                        context.t('home.activeToday'),
                      ),
                      _buildSummaryChip(
                        Icons.person_rounded,
                        '$totalPropietarios ${context.t('home.owners')}',
                        context.t('home.linked'),
                      ),
                      _buildSummaryChip(
                        Icons.warning_amber_rounded,
                        '$documentsExpired ${context.t('home.expiredStatus').toLowerCase()}',
                        context.t('home.expiredDocuments'),
                      ),
                      _buildSummaryChip(
                        Icons.build_circle_rounded,
                        '$maintenanceScheduled ${context.t('home.maintenancePlural')}',
                        context.t('home.scheduled'),
                      ),
                      _buildSummaryChip(
                        Icons.tips_and_updates_rounded,
                        '$maintenanceSuggested ${context.t('home.maintenancePlural')}',
                        context.t('home.suggested'),
                      ),
                      _buildSummaryChip(
                        Icons.assignment_turned_in_rounded,
                        '$certificateRequests ${context.t('home.requests')}',
                        context.t('home.certificates'),
                      ),
                    ],
                  ),
                ),
                if (upcomingDocs.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Text(
                    context.t('home.companyDocsExpiring'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentCountdownGrid(upcomingDocs),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: documentsTap,
                      icon: const Icon(
                        Icons.folder_copy_rounded,
                        color: Color(0xFF16C79A),
                      ),
                      label: Text(
                        context.t('home.goDocuments'),
                        style: const TextStyle(color: Color(0xFF16C79A)),
                      ),
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
    final int maintenanceScheduled =
        (_summaryMetrics['maintenanceScheduled'] as num?)?.toInt() ?? 0;

    final int maintenanceSuggested =
        (_summaryMetrics['maintenanceSuggested'] as num?)?.toInt() ?? 0;
    final int myDocuments = _documents.length;
    final DateTime todayOnly = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final int docsExpired = _documents.entries.where((entry) {
      final DateTime expiryOnly = DateTime(
        entry.value.year,
        entry.value.month,
        entry.value.day,
      );
      return expiryOnly.isBefore(todayOnly);
    }).length;
    final int docsExpiringSoon = _documents.entries.where((entry) {
      final DateTime expiryOnly = DateTime(
        entry.value.year,
        entry.value.month,
        entry.value.day,
      );
      return expiryOnly.isBefore(todayOnly.add(const Duration(days: 30))) &&
          expiryOnly.isAfter(todayOnly);
    }).length;
    final vehiclesToShow = _fleetVehicles.take(3).toList();
    final List<MapEntry<String, DateTime>> upcomingDocs = _upcomingDocs(
      limit: 3,
    );

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
                // Banner
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
                // Título
                Text(
                  context.t('home.ownerPanel'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('home.ownerSubtitle'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                // Chips de resumen
                Align(
                  alignment: Alignment.center,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSummaryChip(
                        Icons.directions_bus,
                        _metric(totalVehicles, 'home.vehicle', 'home.vehicles'),
                        context.t('home.activeToday'),
                      ),
                      _buildSummaryChip(
                        Icons.description_rounded,
                        _metric(myDocuments, 'home.document', 'home.documents'),
                        context.t('home.personal'),
                      ),
                      _buildSummaryChip(
                        Icons.build_circle_rounded,
                        '$maintenanceScheduled ${context.t('home.maintenancePlural')}',
                        context.t('home.scheduled'),
                      ),
                      _buildSummaryChip(
                        Icons.tips_and_updates_rounded,
                        '$maintenanceSuggested ${context.t('home.maintenancePlural')}',
                        context.t('home.suggested'),
                      ),
                      _buildSummaryChip(
                        Icons.warning_amber_rounded,
                        '$docsExpired ${context.t('home.expiredStatus').toLowerCase()}',
                        context.t('home.expired'),
                      ),
                      _buildSummaryChip(
                        Icons.schedule_rounded,
                        '$docsExpiringSoon ${context.t('home.next')}',
                        context.t('home.next30'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                // Sección de documentos próximos a vencer
                if (upcomingDocs.isNotEmpty) ...[
                  Text(
                    context.t('home.yourDocsExpiring'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentCountdownGrid(upcomingDocs),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: _handleViewDocuments,
                      icon: const Icon(
                        Icons.folder_copy_rounded,
                        color: Color(0xFF16C79A),
                      ),
                      label: Text(
                        context.t('home.viewAllDocuments'),
                        style: const TextStyle(color: Color(0xFF16C79A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        context.t('home.noDocuments'),
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                // Sección de vehículos
                if (vehiclesToShow.isNotEmpty) ...[
                  Text(
                    context.t('home.assignedVehicles'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                  if (totalVehicles > 3) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.t('home.vehiclesUnavailable'),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          context.t('home.viewAllVehicles'),
                          style: const TextStyle(color: Color(0xFF16C79A)),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        context.t('home.noVehicles'),
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
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

  Widget _secretariaInicio() {
    final List<MapEntry<String, DateTime>> upcomingDocs = _upcomingDocs(
      limit: 3,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('home.secretaryPanel'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('home.secretarySubtitle'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              _infoCard(Icons.request_page, context.t('home.newRequests'), '8'),
              const SizedBox(height: 26),
              // Documentos próximos a vencer
              if (upcomingDocs.isNotEmpty) ...[
                Text(
                  context.t('home.docsExpiring'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDocumentCountdownGrid(upcomingDocs),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => _showNavigationFallback('Documentos'),
                    icon: const Icon(
                      Icons.folder_copy_rounded,
                      color: Color(0xFF16C79A),
                    ),
                    label: Text(
                      context.t('home.goDocuments'),
                      style: const TextStyle(color: Color(0xFF16C79A)),
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      context.t('home.noDocuments'),
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminInicio() {
    final List<MapEntry<String, DateTime>> upcomingDocs = _upcomingDocs(
      limit: 3,
    );

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
                Text(
                  context.t('home.adminPanel'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('home.adminSubtitle'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                _infoCard(Icons.settings, context.t('home.settings'), ''),
                const SizedBox(height: 26),
                // Documentos próximos a vencer
                if (upcomingDocs.isNotEmpty) ...[
                  Text(
                    context.t('home.systemDocsExpiring'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentCountdownGrid(upcomingDocs),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () => _showNavigationFallback('Documentos'),
                      icon: const Icon(
                        Icons.folder_copy_rounded,
                        color: Color(0xFF16C79A),
                      ),
                      label: Text(
                        context.t('home.goDocuments'),
                        style: const TextStyle(color: Color(0xFF16C79A)),
                      ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        context.t('home.noDocuments'),
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
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

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
          final double candidateWidth =
              (maxWidth - spacing * (columns - 1)) / columns;
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
              // Calcular días usando solo fechas, sin considerar horas
              final DateTime todayOnly = DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );
              final DateTime expiryOnly = DateTime(
                expiry.year,
                expiry.month,
                expiry.day,
              );
              final int daysRemaining = expiryOnly.difference(todayOnly).inDays;
              final DateTime? creationDate = _getDocumentCreationDate(
                entry.key,
              );

              final DateTime creationOnly = creationDate != null
                  ? DateTime(
                      creationDate.year,
                      creationDate.month,
                      creationDate.day,
                    )
                  : todayOnly.subtract(const Duration(days: 90));

              final int totalDaysFromCreation = expiryOnly
                  .difference(creationOnly)
                  .inDays;

              final int totalDays = totalDaysFromCreation > 0
                  ? totalDaysFromCreation
                  : 1;
              final DateTime? paymentDate = _paymentDates?[entry.key];
              final String detailLabel =
                  _documentVehicle[entry.key] ?? context.t('home.noDetail');

              return SizedBox(
                width: itemWidth,
                child: GestureDetector(
                  onTap: () {
                    final rawDoc = _documentRawData[entry.key] ?? {};

                    final fileUrl =
                        rawDoc['urlStorage']?.toString() ??
                        rawDoc['urlDocumento']?.toString() ??
                        rawDoc['url']?.toString() ??
                        rawDoc['rutaDocumento']?.toString() ??
                        rawDoc['fileUrl']?.toString() ??
                        '';

                    final observations =
                        rawDoc['observaciones']?.toString() ??
                        rawDoc['observacion']?.toString() ??
                        '';

                    DocumentPreviewModal.show(
                      context: context,
                      documentName: entry.key.split('-').first,
                      fileUrl: fileUrl,
                      expiryDate: expiry,
                      observations: observations,
                    );
                  },
                  child: DocumentCountdown(
                    expiry: expiry,
                    paymentDate: paymentDate,
                    totalDuration: Duration(days: totalDays),
                    title: entry.key.split('-').first,
                    subtitle:
                        '$detailLabel\n${_formatDate(expiry)}\n${daysRemaining < 0
                            ? '$daysRemaining ${context.t('home.days')}'
                            : daysRemaining == 0
                            ? context.t('home.today')
                            : '$daysRemaining ${context.t('home.days')}'}',
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
    final String driverName = vehicle['driver'] as String;
    final String ownerName = vehicle['owner'] as String;
    final String yearStr = vehicle['year'] as String;
    final String colorStr = vehicle['color'] as String;
    final bool hasDriver =
        driverName.isNotEmpty && driverName.toLowerCase() != 'no asignado';
    final bool hasYear = yearStr.isNotEmpty;
    final bool hasColor = colorStr.isNotEmpty;

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
          // Ícono de vehículo
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF16C79A).withValues(alpha: 0.2),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Color(0xFF16C79A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Placa y estado
                Row(
                  children: [
                    Text(
                      vehicle['plate'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        vehicle['status'] as String,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Modelo
                _buildVehicleInfoRow(
                  context.t('home.model'),
                  vehicle['model'] as String,
                ),
                // Propietario
                _buildVehicleInfoRow(context.t('home.owner'), ownerName),
                // Conductor
                if (hasDriver)
                  _buildVehicleInfoRow(context.t('home.driver'), driverName)
                else
                  _buildVehicleInfoRow(
                    context.t('home.driver'),
                    context.t('home.unassigned'),
                  ),
                // Año y Color en una sola fila si están disponibles
                if (hasYear || hasColor)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (hasYear) ...[
                          Expanded(
                            child: _buildVehicleInfoRow(
                              context.t('home.year'),
                              yearStr,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (hasColor) ...[
                          Expanded(
                            child: _buildVehicleInfoRow(
                              context.t('home.color'),
                              colorStr,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.open_in_new,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${context.t('home.detail')} ${vehicle['plate']} - $ownerName',
                  ),
                  backgroundColor: const Color(0xFF16C79A),
                ),
              );
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

  @override
  void initState() {
    super.initState();
    _updateRemaining();
  }

  void _updateRemaining() {
    final DateTime todayOnly = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final DateTime expiryOnly = DateTime(
      widget.expiry.year,
      widget.expiry.month,
      widget.expiry.day,
    );
    _remaining = expiryOnly.difference(todayOnly);
    // No clamp to zero for expired documents
  }

  @override
  Widget build(BuildContext context) {
    final int daysRemaining = _remaining.inDays;

    Color progressColor;

    if (daysRemaining < 0) {
      progressColor = Colors.redAccent;
    } else if (daysRemaining <= 7) {
      progressColor = Colors.redAccent;
    } else if (daysRemaining <= 15) {
      progressColor = Colors.orangeAccent;
    } else if (daysRemaining <= 30) {
      progressColor = const Color(0xFFEFB549);
    } else {
      progressColor = const Color(0xFF16C79A);
    }

    final total = widget.totalDuration.inSeconds > 0
        ? widget.totalDuration.inSeconds
        : 1;
    final bool isExpired = daysRemaining < 0;

    final remain = _remaining.inSeconds.clamp(0, total);

    final percent = isExpired
        ? 1.0
        : total > 0
        ? (remain / total)
        : 0.0;

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
                  color: progressColor,
                  backgroundColor: progressColor.withValues(alpha: 0.18),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatRemaining(_remaining),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: (size / 6).clamp(12.0, 18.0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _humanUnit(_remaining),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: (size / 10).clamp(10.0, 12.0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  String _formatRemaining(Duration d) {
    final int days = d.inDays.abs();

    if (days >= 365) {
      return '${(days / 365).floor()}';
    }

    if (days >= 30) {
      return '${(days / 30).floor()}';
    }

    return '$days';
  }

  String _humanUnit(Duration d) {
    final int days = d.inDays.abs();

    if (d.isNegative) {
      if (days >= 365) return context.t('home.yearsExpired');
      if (days >= 30) return context.t('home.monthsExpired');
      return context.t('home.daysExpired');
    }

    if (days >= 365) return context.t('home.years');
    if (days >= 30) return context.t('home.months');
    return context.t('home.days');
  }
}
