// ignore_for_file: use_build_context_synchronously
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_language.dart';
import '../../services/document_service.dart';
import '../utils/shimmer_skeleton.dart';

class UploadDocumentModal {
  static void show({
    required BuildContext context,
    required String userId,
    required String userRole,
    String? token,
    VoidCallback? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _UploadDocumentDialog(
          userId: userId,
          userRole: userRole,
          token: token,
          onSuccess: onSuccess,
        );
      },
    );
  }
}

class _UploadDocumentDialog extends StatefulWidget {
  final String userId;
  final String userRole;
  final String? token;
  final VoidCallback? onSuccess;

  const _UploadDocumentDialog({
    required this.userId,
    required this.userRole,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<_UploadDocumentDialog> {
  String? selectedFilePath;
  String? selectedFileName;
  List<int>? selectedFileBytes; // Para archivos en web

  // Nuevos campos dinámicos
  int? selectedPersonaId;
  String? selectedPersonaTipo; // 'conductor' o 'propietario'
  int? selectedPersonaIdUsuario; // ID del usuario de la persona seleccionada
  String?
  selectedVehicleValue; // Usar String para evitar autocompletado: "vehicle_ID"
  int? selectedVehicleId;
  String? selectedVehiclePlaca;

  int? selectedDocumentTypeId;
  String? selectedArea;
  DateTime? selectedExpiryDate;
  bool isUploading = false;
  bool isLoadingPersonas = false;
  bool isLoadingVehiculos = false;
  String? personasLoadError; // Almacenar error de carga de personas

  List<Map<String, dynamic>> conductores = [];
  List<Map<String, dynamic>> propietarios = [];
  List<Map<String, dynamic>> vehiculos = [];
  List<Map<String, dynamic>> documentTypes = [];
  bool isLoadingDocumentTypes = false;

  final TextEditingController observationController = TextEditingController();

  // Getter para determinar si el modal completo está cargando
  bool get _isLoadingModal => isLoadingPersonas || isLoadingDocumentTypes;

  @override
  void initState() {
    super.initState();
    selectedVehicleValue = null;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadPersonas(), _loadDocumentTypes()]);
  }

  @override
  void dispose() {
    observationController.dispose();
    super.dispose();
  }

  /// Extrae el nombre completo de una persona (conductor o propietario)
  /// Intenta múltiples campos posibles para mayor compatibilidad
  String _getNombrePersona(Map<String, dynamic> persona) {
    // Intenta campos posibles en orden de preferencia
    if (persona['nombreCompleto'] != null) {
      return persona['nombreCompleto'].toString();
    }

    if (persona['nombre'] != null) return persona['nombre'].toString();
    if (persona['nomina'] != null) return persona['nomina'].toString();
    if (persona['usuario'] != null && persona['usuario'] is Map) {
      if (persona['usuario']['nombre'] != null) {
        return persona['usuario']['nombre'].toString();
      }

      if (persona['usuario']['nombreCompleto'] != null) {
        return persona['usuario']['nombreCompleto'].toString();
      }
    }
    return 'Sin nombre';
  }

  /// Extrae el documento de una persona
  String _getDocumentoPersona(Map<String, dynamic> persona) {
    if (persona['numeroDocumento'] != null) {
      return persona['numeroDocumento'].toString();
    }
    if (persona['documento'] != null) return persona['documento'].toString();
    if (persona['rut'] != null) return persona['rut'].toString();
    if (persona['usuario'] != null && persona['usuario'] is Map) {
      if (persona['usuario']['numeroDocumento'] != null) {
        return persona['usuario']['numeroDocumento'].toString();
      }
    }
    return 'Sin documento';
  }

  /// Extrae el ID de una persona
  int _getIdPersona(Map<String, dynamic> persona) {
    final raw =
        persona['idRegistroRol'] ??
        persona['id'] ??
        persona['idConductor'] ??
        persona['idPropietario'];

    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int? _getUsuarioIdPersona(Map<String, dynamic> persona) {
    final raw =
        persona['idUsuario'] ??
        persona['usuarioId'] ??
        persona['id_usuario'] ??
        (persona['usuario'] is Map ? persona['usuario']['id'] : null);

    return int.tryParse(raw?.toString() ?? '');
  }

  /// Categoriza documentos según su aplicabilidad
  /// Retorna: 'CONDUCTOR', 'PROPIETARIO', 'VEHICULO', o 'FLEXIBLE'
  String _categorizeDocumentType(String nombreDocumento) {
    final nombre = nombreDocumento.toUpperCase().trim();

    // Documentos del CONDUCTOR (solo para conductores)
    if (nombre == 'LICENCIA') return 'CONDUCTOR';

    // Documentos del PROPIETARIO (solo para propietarios)
    if (nombre == 'RUT' || nombre == 'CERTIFICADO_PROPIEDAD') {
      return 'PROPIETARIO';
    }

    // Documentos del VEHÍCULO
    if (nombre == 'SOAT' ||
        nombre == 'TECNOMECANICA' ||
        nombre == 'TARJETA_OPERACION' ||
        nombre == 'SEGURO' ||
        nombre == 'CONTRACTUAL' ||
        nombre == 'EXTRACONTRACTUAL' ||
        nombre == 'POLIZA_TODO_RIESGO' ||
        nombre == 'PERMISO_CIRCULACION') {
      return 'VEHICULO';
    }

    // Documentos para AMBOS (Conductor y Propietario) - Identidad
    if (nombre == 'CEDULA' || nombre == 'PASAPORTE') return 'AMBOS_PERSONA';

    // OTRO y sin categoría definida = válido para todos
    return 'FLEXIBLE';
  }

  /// Obtiene las áreas permitidas para un tipo de documento
  /// Según la especificación exacta de tipos de documento
  List<String> _getPermittedAreas(int? documentTypeId) {
    if (documentTypeId == null) {
      return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
    }

    final docType = documentTypes.firstWhere(
      (d) => d['id'] == documentTypeId,
      orElse: () => <String, dynamic>{},
    );

    if (docType.isEmpty) {
      return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
    }

    final nombre = docType['nombre']?.toString().toUpperCase() ?? '';

    // ===== DOCUMENTOS PERSONALES (CONDUCTOR / PROPIETARIO) =====

    // LICENCIA, CEDULA, PASAPORTE → Legal
    if (nombre == 'LICENCIA' || nombre == 'CEDULA' || nombre == 'PASAPORTE') {
      return const ['LEGAL'];
    }

    // RUT → Administrativa (solo propietario)
    if (nombre == 'RUT') {
      return const ['ADMINISTRATIVO'];
    }

    // CERTIFICADO_PROPIEDAD → Legal (solo propietario)
    if (nombre == 'CERTIFICADO_PROPIEDAD') {
      return const ['LEGAL'];
    }

    // ===== DOCUMENTOS DE VEHÍCULO =====

    // SOAT, SEGURO, CONTRACTUAL, EXTRACONTRACTUAL, POLIZA_TODO_RIESGO, PERMISO_CIRCULACION → Legal
    if (nombre == 'SOAT' ||
        nombre == 'SEGURO' ||
        nombre == 'CONTRACTUAL' ||
        nombre == 'EXTRACONTRACTUAL' ||
        nombre == 'POLIZA_TODO_RIESGO' ||
        nombre == 'PERMISO_CIRCULACION') {
      return const ['LEGAL'];
    }

    // TECNOMECANICA → Técnica
    if (nombre == 'TECNOMECANICA') {
      return const ['TECNICA'];
    }

    // TARJETA_OPERACION → Administrativa
    if (nombre == 'TARJETA_OPERACION') {
      return const ['ADMINISTRATIVO'];
    }

    // OTRO → Administrativa (flexible, puede ser personal o vehículo)
    if (nombre == 'OTRO') {
      return const ['ADMINISTRATIVO'];
    }

    // Por defecto, todas las áreas
    return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
  }

  /// Obtiene los documentos filtrados según contexto (usuario/vehículo)
  /// No diferencia entre conductor y propietario para documentos personales
  List<Map<String, dynamic>> _getFilteredDocumentTypes() {
    if (documentTypes.isEmpty) return [];

    final bool hasVehicle = selectedVehicleId != null && selectedVehicleId! > 0;

    final filtered = documentTypes.where((doc) {
      final docName = doc['nombre']?.toString() ?? '';
      final category = _categorizeDocumentType(docName);

      if (hasVehicle) {
        // Si hay vehículo: mostrar VEHICULO o FLEXIBLE
        return category == 'VEHICULO' || category == 'FLEXIBLE';
      } else {
        // Si NO hay vehículo: mostrar todo excepto VEHICULO
        // Esto incluye: CONDUCTOR, PROPIETARIO, AMBOS_PERSONA, FLEXIBLE
        return category != 'VEHICULO';
      }
    }).toList();

    // Remover duplicados por ID
    final Map<int, Map<String, dynamic>> uniqueById = {};
    for (final doc in filtered) {
      final id = int.tryParse(doc['id'].toString()) ?? 0;
      if (id > 0 && !uniqueById.containsKey(id)) {
        uniqueById[id] = doc;
      }
    }
    final uniqueFiltered = uniqueById.values.toList();

    return uniqueFiltered;
  }

  /// Valida si se requiere observación obligatoria
  bool _isObservationRequired() {
    if (selectedDocumentTypeId == null) return false;

    final docType = documentTypes.firstWhere(
      (d) => d['id'] == selectedDocumentTypeId,
      orElse: () => <String, dynamic>{},
    );

    if (docType.isEmpty) return false;

    final nombre = docType['nombre']?.toString().toUpperCase() ?? '';

    // Observación obligatoria solo para OTRO
    return nombre == 'OTRO';
  }

  Future<void> _loadPersonas() async {
    setState(() {
      isLoadingPersonas = true;
      personasLoadError = null;
    });

    try {
      final usuarios = await DocumentService.getUsuariosEmpresa(
        token: widget.token,
      );

      final condsApi = await DocumentService.getConductores(
        token: widget.token,
      );
      final propsApi = await DocumentService.getPropietarios(
        token: widget.token,
      );

      final Map<String, Map<String, dynamic>> conductoresMap = {};
      final Map<String, Map<String, dynamic>> propietariosMap = {};

      for (final user in usuarios) {
        final rol = (user['rol'] ?? '').toString().toUpperCase();
        final usuarioId =
            (user['id'] ?? user['idUsuario'] ?? user['id_usuario'])?.toString();

        if (usuarioId == null || usuarioId.isEmpty) continue;

        final base = {
          ...user,
          'idUsuario': int.tryParse(usuarioId),
          'usuarioId': int.tryParse(usuarioId),
          'nombreCompleto': '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'
              .trim(),
        };

        if (rol.contains('CONDUCTOR')) {
          conductoresMap[usuarioId] = {...base, 'id': int.tryParse(usuarioId)};
        }

        if (rol.contains('PROPIETARIO')) {
          propietariosMap[usuarioId] = {...base, 'id': int.tryParse(usuarioId)};
        }
      }

      for (final c in condsApi) {
        final usuarioId = _getUsuarioIdPersona(c)?.toString();
        if (usuarioId == null || usuarioId.isEmpty) continue;

        conductoresMap[usuarioId] = {
          ...?conductoresMap[usuarioId],
          ...c,
          'idUsuario': int.tryParse(usuarioId),
          'usuarioId': int.tryParse(usuarioId),
          'idRegistroRol': c['id'],
        };
      }

      for (final p in propsApi) {
        final usuarioId = _getUsuarioIdPersona(p)?.toString();
        if (usuarioId == null || usuarioId.isEmpty) continue;

        propietariosMap[usuarioId] = {
          ...?propietariosMap[usuarioId],
          ...p,
          'idUsuario': int.tryParse(usuarioId),
          'usuarioId': int.tryParse(usuarioId),
          'idRegistroRol': p['id'],
        };
      }

      if (!mounted) return;

      setState(() {
        conductores = conductoresMap.values.toList();
        propietarios = propietariosMap.values.toList();
        isLoadingPersonas = false;
      });
    } catch (e) {

      if (!mounted) return;

      setState(() {
        isLoadingPersonas = false;
        personasLoadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadDocumentTypes() async {
    setState(() {
      isLoadingDocumentTypes = true;
    });

    try {
      final types = await DocumentService.getDocumentTypes(token: widget.token);

      if (mounted) {
        setState(() {
          documentTypes = types;
          isLoadingDocumentTypes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoadingDocumentTypes = false;
        });
      }
    }
  }

  Future<void> _loadVehiculos(int personaId, String personaTipo) async {
    // Reset: no seleccionar automáticamente ningún vehículo
    setState(() {
      isLoadingVehiculos = true;
      vehiculos = [];
      selectedVehicleValue =
          null; // Mantener null - el usuario debe seleccionar explícitamente
      selectedVehicleId = null;
      selectedVehiclePlaca = null;
    });

    try {
      List<Map<String, dynamic>> veh;
      if (personaTipo == 'conductor') {
        veh = await DocumentService.getVehiculosPorConductor(
          conductorId: personaId,
          token: widget.token,
        );
      } else {
        veh = await DocumentService.getVehiculosPorPropietario(
          propietarioId: personaId,
          token: widget.token,
        );
      }

      if (mounted) {
        setState(() {
          vehiculos = veh;
          isLoadingVehiculos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('${context.t('vehicles.loadError')}: $e');
        setState(() {
          isLoadingVehiculos = false;
        });
      }
    }
  }

  Widget _buildLoadingModalState(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: _modalDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUploadHeroHeader(context),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerSkeleton(
                        width: double.infinity,
                        height: 54,
                        borderRadius: 14,
                      ),
                      const SizedBox(height: 12),
                      const ShimmerSkeleton(
                        width: double.infinity,
                        height: 54,
                        borderRadius: 14,
                      ),
                      const SizedBox(height: 12),
                      const ShimmerSkeleton(
                        width: double.infinity,
                        height: 58,
                        borderRadius: 14,
                      ),
                      const SizedBox(height: 12),
                      const ShimmerSkeleton(
                        width: double.infinity,
                        height: 54,
                        borderRadius: 14,
                      ),
                      const SizedBox(height: 12),
                      const ShimmerSkeleton(
                        width: double.infinity,
                        height: 54,
                        borderRadius: 14,
                      ),
                      const SizedBox(height: 12),
                      const ShimmerSkeleton(
                        width: double.infinity,
                        height: 54,
                        borderRadius: 14,
                      ),
                      const SizedBox(height: 12),
                      const ShimmerSkeleton(
                        width: double.infinity,
                        height: 92,
                        borderRadius: 14,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: const [
                          Expanded(
                            child: ShimmerSkeleton(
                              height: 48,
                              borderRadius: 16,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ShimmerSkeleton(
                              height: 48,
                              borderRadius: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadHeroHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4F4CE8)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F4CE8).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('documents.uploadTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('documents.uploadSubtitle'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: isUploading ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  BoxDecoration _modalDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF20276D), Color(0xFF121842), Color(0xFF0D1234)],
      ),
      border: Border.all(color: Colors.white24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingModal) {
      return _buildLoadingModalState(context);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: _modalDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUploadHeroHeader(context),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPersonaSection(),
                          const SizedBox(height: 12),
                          _buildVehicleSection(),
                          const SizedBox(height: 12),
                          _buildFilePickerSection(),
                          const SizedBox(height: 12),
                          _buildDocumentTypeSection(),
                          const SizedBox(height: 12),
                          _buildAreaSection(),
                          const SizedBox(height: 12),
                          _buildExpiryDateSection(),
                          const SizedBox(height: 12),
                          _buildObservationsSection(),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isUploading
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(context.t('common.cancel')),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploading
                                      ? null
                                      : ((selectedFilePath == null ||
                                                    selectedFilePath!
                                                        .isEmpty) &&
                                                selectedFileBytes == null) ||
                                            selectedDocumentTypeId == null ||
                                            selectedExpiryDate == null ||
                                            selectedPersonaId == null ||
                                            selectedArea == null
                                      ? null
                                      : _uploadDocument,
                                  icon: isUploading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.upload_rounded),
                                  label: Text(
                                    isUploading
                                        ? context.t('documents.uploading')
                                        : context.t('common.upload'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F4CE8),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.white
                                        .withValues(alpha: 0.12),
                                    disabledForegroundColor: Colors.white38,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Container(
                        width: 270,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1F6B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.t('documents.uploadingTitle'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.t('documents.uploadingHelp'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonaSection() {
    final bool isEmpresa = widget.userRole.toLowerCase() == 'empresa';
    const String labelText = 'Usuario';

    if (isLoadingPersonas) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ShimmerSkeleton(
            width: double.infinity,
            height: 50,
            borderRadius: 8,
            margin: EdgeInsets.zero,
          ),
        ],
      );
    }

    // Si hay error cargando personas, mostrar mensaje de error
    if (personasLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('documents.serverError'),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  personasLoadError!,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  isEmpresa
                      ? '• Verifica que iniciaste sesión como EMPRESA\n• Asegúrate que hay conductores asignados a tu empresa\n• Contacta al administrador si el problema persiste'
                      : '• Contacta al administrador del sistema\n• Si el problema persiste, intenta refrescar la página',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadPersonas,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(context.t('common.retry')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
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

    // Validar si hay datos disponibles
    bool hasData = conductores.isNotEmpty || propietarios.isNotEmpty;

    if (!hasData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('documents.noDrivers'),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isEmpresa
                      ? '• Verifica que iniciaste sesión como EMPRESA\n• Asegúrate que hay conductores asignados a tu empresa\n• Contacta al administrador si no ves tus conductores'
                      : '• Verifica que hay conductores o propietarios registrados\n• Contacta al administrador del sistema',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Obtener nombre de la persona seleccionada

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedPersonaId != null ? Colors.blue : Colors.white24,
              width: selectedPersonaId != null ? 2 : 1,
            ),
          ),
          child: DropdownButton<String>(
            value: selectedPersonaId != null
                ? '$selectedPersonaTipo'
                      '_'
                      '$selectedPersonaId'
                : null,
            isDense: true,
            underline: Container(),
            dropdownColor: const Color(0xFF19456B),
            isExpanded: true,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_search,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.t('documents.selectPerson'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: [
              // Conductores
              if (conductores.isNotEmpty)
                DropdownMenuItem<String>(
                  enabled: false,
                  value: 'header_conductores',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '👤 ${context.t('documents.driversHeader')}',
                      style: const TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ...conductores.map((c) {
                final id = _getIdPersona(c);
                final value = 'conductor_$id';
                final nombre = _getNombrePersona(c);
                final documento = _getDocumentoPersona(c);
                final label = '$nombre - $documento';
                return DropdownMenuItem<String>(
                  value: value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),

              // Propietarios (mostrar siempre que haya disponibles)
              if (propietarios.isNotEmpty) ...[
                DropdownMenuItem<String>(
                  enabled: false,
                  value: 'header_propietarios',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '🏠 ${context.t('documents.ownersHeader')}',
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                ...propietarios.map((p) {
                  final id = _getIdPersona(p);
                  final value = 'propietario_$id';
                  final nombre = _getNombrePersona(p);
                  final documento = _getDocumentoPersona(p);
                  final label = '$nombre - $documento';
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }),
              ],
            ],
            onChanged: isUploading
                ? null
                : (value) {
                    if (value != null && value.contains('_')) {
                      final parts = value.split('_');
                      final tipo = parts[0];
                      final id = int.tryParse(parts[1]) ?? 0;

                      // Buscar el idUsuario de la persona seleccionada
                      // El backend devuelve diferentes estructuras según el endpoint:
                      // - /api/propietarios y /api/conductores: {"id": 3, "idUsuario": 23}
                      // - /api/vehiculos: {"propietario": {"usuario": {"id": 23}}}
                      int? idUsuario;
                      if (tipo == 'conductor') {
                        final persona = conductores.firstWhere(
                          (c) => _getIdPersona(c) == id,
                          orElse: () => <String, dynamic>{},
                        );
                        if (persona.isNotEmpty) {
                          // Intentar obtener idUsuario del nivel superior (estructura simplificada)
                          idUsuario = persona['idUsuario'] as int?;

                          // Si no existe, intentar obtener del usuario anidado
                          if (idUsuario == null && persona['usuario'] != null) {
                            idUsuario = persona['usuario']['id'] as int?;
                          }
                        }
                      } else if (tipo == 'propietario') {
                        final persona = propietarios.firstWhere(
                          (p) => _getIdPersona(p) == id,
                          orElse: () => <String, dynamic>{},
                        );
                        if (persona.isNotEmpty) {
                          // Intentar obtener idUsuario del nivel superior (estructura simplificada)
                          idUsuario = persona['idUsuario'] as int?;

                          // Si no existe, intentar obtener del usuario anidado
                          if (idUsuario == null && persona['usuario'] != null) {
                            idUsuario = persona['usuario']['id'] as int?;
                          }
                        }
                      }

                      setState(() {
                        selectedPersonaTipo = tipo;
                        selectedPersonaId = id;
                        selectedPersonaIdUsuario = idUsuario;
                      });

                      _loadVehiculos(id, tipo);
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSection() {
    final bool isEnabled = selectedPersonaId != null;

    // If no user is selected, show disabled state
    if (!isEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('section.vehicles'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.t('documents.selectUserFirst'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // If loading vehicles, show shimmer skeleton
    if (isLoadingVehiculos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('section.vehicles'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ShimmerSkeleton(
            width: double.infinity,
            height: 50,
            borderRadius: 8,
            margin: EdgeInsets.zero,
          ),
        ],
      );
    }

    // If user has no vehicles, show warning message
    if (vehiculos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('section.vehicles'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.t('documents.noUserVehicles'),
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // If user is enabled and has vehicles, show dropdown
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('section.vehicles'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedVehicleValue != null
                  ? Colors.green
                  : Colors.white24,
              width: selectedVehicleValue != null ? 2 : 1,
            ),
          ),
          child: DropdownButton<String?>(
            value: selectedVehicleValue,
            isDense: true,
            underline: Container(),
            dropdownColor: const Color(0xFF19456B),
            isExpanded: true,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.t('documents.selectVehicleOptional'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: [
              // Primer item: "Sin seleccionar"
              DropdownMenuItem<String?>(
                value: null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    context.t('documents.noneSelected'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              // Items de vehículos
              ...vehiculos.map((v) {
                final id = v['id'] is String
                    ? int.parse(v['id'].toString())
                    : v['id'];
                final value = 'vehicle_$id';
                final placa = v['placa'] ?? context.t('documents.noPlate');
                final marca = v['marca'] ?? '';
                final modelo = v['modelo'] ?? '';
                final label = '$placa - $marca $modelo'.trim();

                return DropdownMenuItem<String?>(
                  value: value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
            ],
            onChanged: isUploading
                ? null
                : (value) {
                    setState(() {
                      selectedVehicleValue = value;
                      if (value != null && value.startsWith('vehicle_')) {
                        // Extraer el ID del valor
                        final idStr = value.replaceFirst('vehicle_', '');
                        selectedVehicleId = int.tryParse(idStr);
                        if (selectedVehicleId != null) {
                          final foundVehicle = vehiculos.firstWhere((v) {
                            final id = v['id'] is String
                                ? int.parse(v['id'].toString())
                                : v['id'];
                            final match = id == selectedVehicleId;
                            return match;
                          }, orElse: () => {});

                          selectedVehiclePlaca = foundVehicle['placa'];
                        }
                      } else {
                        selectedVehicleId = null;
                        selectedVehiclePlaca = null;
                      }
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildFilePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('documents.file'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isUploading ? null : _pickFile,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedFileName ?? context.t('documents.selectFile'),
                    style: TextStyle(
                      color: selectedFileName != null
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTypeSection() {
    if (isLoadingDocumentTypes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('documents.type'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ShimmerSkeleton(
            width: double.infinity,
            height: 50,
            borderRadius: 8,
            margin: EdgeInsets.zero,
          ),
        ],
      );
    }

    if (documentTypes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('documents.type'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.t('documents.noTypesLoaded'),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final filteredDocs = _getFilteredDocumentTypes();
    final bool hasVehicle = selectedVehicleId != null && selectedVehicleId! > 0;

    String docTypeInfo = '';
    if (hasVehicle) {
      docTypeInfo = '🚗 ${context.t('documents.vehicleDocuments')}';
    } else {
      docTypeInfo = '👤 ${context.t('documents.userDocuments')}';
    }

    // Validar si el tipo actualmente seleccionado está en la lista filtrada
    bool selectedTypeIsValid = filteredDocs.any((d) {
      final id = int.tryParse(
        (d['id'] ?? d['idTipoDocumento'] ?? d['id_tipo_documento']).toString(),
      );
      return id == selectedDocumentTypeId;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.t('documents.type'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              docTypeInfo,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedDocumentTypeId != null && selectedTypeIsValid
                  ? Colors.purple
                  : Colors.white24,
              width: selectedDocumentTypeId != null && selectedTypeIsValid
                  ? 2
                  : 1,
            ),
          ),
          child: DropdownButton<int>(
            value: selectedTypeIsValid ? selectedDocumentTypeId : null,
            isDense: true,
            underline: Container(),
            dropdownColor: const Color(0xFF19456B),
            isExpanded: true,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.description,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.t('documents.selectType'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: filteredDocs.map((type) {
              final id = int.tryParse(
                (type['id'] ??
                        type['idTipoDocumento'] ??
                        type['id_tipo_documento'])
                    .toString(),
              );
              if (id == null) {
                return DropdownMenuItem<int>(
                  value: -1,
                  enabled: false,
                  child: Text(context.t('documents.invalidType')),
                );
              }
              final nombre =
                  type['nombre'] ??
                  type['nombre_tipo'] ??
                  context.t('documents.noName');
              return DropdownMenuItem<int>(
                value: id,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
            onChanged: isUploading
                ? null
                : (value) {
                    setState(() {
                      selectedDocumentTypeId = value;

                      final areas = _getPermittedAreas(value);
                      selectedArea = areas.length == 1 ? areas.first : null;
                    });
                  },
          ),
        ),
        if (filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasVehicle
                          ? 'No hay documentos de vehículo disponibles. Deselecciona el vehículo para ver documentos personales.'
                          : 'Selecciona un usuario primero para ver los documentos disponibles.',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAreaSection() {
    final permittedAreas = _getPermittedAreas(selectedDocumentTypeId);

    // Validar que el área seleccionada esté en las permitidas
    bool selectedAreaIsValid =
        selectedArea != null && permittedAreas.contains(selectedArea);

    // Opciones de área con sus etiquetas amigables
    final areaOptions = {
      'TECNICA': ('Técnica', Icons.build),
      'LEGAL': ('Legal', Icons.balance),
      'ADMINISTRATIVO': ('Administrativo', Icons.description),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.t('documents.area'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (selectedDocumentTypeId != null)
              Text(
                '${permittedAreas.length} ${context.t(permittedAreas.length == 1 ? 'documents.option' : 'documents.options')}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedAreaIsValid ? Colors.orange : Colors.white24,
              width: selectedAreaIsValid ? 2 : 1,
            ),
          ),
          child: DropdownButton<String>(
            value: selectedAreaIsValid ? selectedArea : null,
            isDense: true,
            underline: Container(),
            dropdownColor: const Color(0xFF19456B),
            isExpanded: true,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.category, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      selectedDocumentTypeId == null
                          ? context.t('documents.selectTypeFirst')
                          : context.t('documents.selectArea'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: permittedAreas.map((area) {
              final displayInfo = areaOptions[area] ?? (area, Icons.category);
              return DropdownMenuItem<String>(
                value: area,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(displayInfo.$2, color: Colors.white70, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        displayInfo.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: selectedDocumentTypeId == null
                ? null
                : (value) {
                    setState(() {
                      selectedArea = value;
                    });
                  },
          ),
        ),
        if (permittedAreas.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.blue, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t('documents.fixedArea'),
                      style: const TextStyle(color: Colors.blue, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpiryDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('documents.expiryDate'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isUploading ? null : _pickExpiryDate,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedExpiryDate != null
                      ? DateFormat('dd/MM/yyyy').format(selectedExpiryDate!)
                      : context.t('documents.selectDate'),
                  style: TextStyle(
                    color: selectedExpiryDate != null
                        ? Colors.white
                        : Colors.white70,
                  ),
                ),
                const Icon(Icons.calendar_today, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildObservationsSection() {
    final isRequired = _isObservationRequired();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.t('documents.observations'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isRequired)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.t('documents.required'),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                context.t('documents.optional'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: observationController,
          maxLines: 3,
          enabled: !isUploading,
          decoration: InputDecoration(
            hintText: isRequired
                ? context.t('documents.observationRequiredHint')
                : context.t('documents.observationOptionalHint'),
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white12,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isRequired
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.white24,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isRequired
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.white24,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isRequired ? Colors.red : Colors.white,
              ),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        if (isRequired)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t('documents.observationRequiredHelp'),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          selectedFilePath = file.path ?? '';
          selectedFileName = file.name;
          selectedFileBytes = file.bytes; // Guardar bytes para web
        });
      }
    } catch (e) {
      _showErrorSnackBar('${context.t('documents.selectFile')}: $e');
    }
  }

  Future<void> _pickExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      setState(() {
        selectedExpiryDate = date;
      });
    }
  }

  Future<void> _uploadDocument() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final requiredFieldsText = context.t('documents.requiredFields');
    final observationRequiredText = context.t(
      'documents.observationRequiredHelp',
    );
    final vehicleTypeErrorText = context.t('documents.vehicleTypeError');
    final userTypeErrorText = context.t('documents.userTypeError');
    final uploadSuccessText = context.t('documents.uploadSuccess');
    final uploadGenericErrorText = context.t('documents.uploadGenericError');

    if (((selectedFilePath == null || selectedFilePath!.isEmpty) &&
            selectedFileBytes == null) ||
        selectedDocumentTypeId == null ||
        selectedExpiryDate == null ||
        selectedPersonaId == null ||
        selectedArea == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('⚠️ $requiredFieldsText'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isObservationRequired() && observationController.text.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('⚠️ $observationRequiredText'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final filteredDocs = _getFilteredDocumentTypes();
    final selectedDocIsValid = filteredDocs.any(
      (d) => d['id'] == selectedDocumentTypeId,
    );

    if (!selectedDocIsValid) {
      final hasVehicle = selectedVehicleId != null && selectedVehicleId! > 0;
      final errorMsg = hasVehicle ? vehicleTypeErrorText : userTypeErrorText;

      messenger.showSnackBar(
        SnackBar(
          content: Text('⚠️ $errorMsg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final selectedPersonaIdInt = selectedPersonaId;

    setState(() {
      isUploading = true;
    });

    try {
      final result = await DocumentService.uploadDocument(
        filePath: selectedFilePath!,
        fileName: selectedFileName ?? 'document',
        vehicleId: selectedVehicleId,
        documentTypeId: selectedDocumentTypeId!,
        area: selectedArea!,
        expiryDate: selectedExpiryDate!,
        observations: observationController.text.isEmpty
            ? null
            : observationController.text,
        responsibleUserId: int.tryParse(widget.userId) ?? 0,
        personaId: selectedPersonaIdInt,
        personaIdUsuario: selectedPersonaIdUsuario,
        token: widget.token,
        fileBytes: selectedFileBytes,
      );

      if (!context.mounted) return;

      setState(() {
        isUploading = false;
      });

      if (result != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ $uploadSuccessText'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        navigator.pop();
        widget.onSuccess?.call();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ $uploadGenericErrorText'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      setState(() {
        isUploading = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
