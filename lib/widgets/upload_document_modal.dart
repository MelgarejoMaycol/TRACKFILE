import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert' show jsonEncode;
import '../services/document_service.dart';

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
  String? selectedVehicleValue; // Usar String para evitar autocompletado: "vehicle_ID"
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

  @override
  void initState() {
    super.initState();
    _loadPersonas();
    _loadDocumentTypes();
    selectedVehicleValue = null; // Explícitamente null al inicio
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
    if (persona['nombreCompleto'] != null) return persona['nombreCompleto'].toString();
    if (persona['nombre'] != null) return persona['nombre'].toString();
    if (persona['nomina'] != null) return persona['nomina'].toString();
    if (persona['usuario'] != null && persona['usuario'] is Map) {
      if (persona['usuario']['nombre'] != null) return persona['usuario']['nombre'].toString();
      if (persona['usuario']['nombreCompleto'] != null) return persona['usuario']['nombreCompleto'].toString();
    }
    return 'Sin nombre';
  }

  /// Extrae el documento de una persona
  String _getDocumentoPersona(Map<String, dynamic> persona) {
    if (persona['numeroDocumento'] != null) return persona['numeroDocumento'].toString();
    if (persona['documento'] != null) return persona['documento'].toString();
    if (persona['rut'] != null) return persona['rut'].toString();
    if (persona['usuario'] != null && persona['usuario'] is Map) {
      if (persona['usuario']['numeroDocumento'] != null) return persona['usuario']['numeroDocumento'].toString();
    }
    return 'Sin documento';
  }

  /// Extrae el ID de una persona
  int _getIdPersona(Map<String, dynamic> persona) {
    if (persona['id'] != null) return int.tryParse(persona['id'].toString()) ?? 0;
    if (persona['idConductor'] != null) return int.tryParse(persona['idConductor'].toString()) ?? 0;
    if (persona['idPropietario'] != null) return int.tryParse(persona['idPropietario'].toString()) ?? 0;
    return 0;
  }

  Future<void> _loadPersonas() async {
    setState(() {
      isLoadingPersonas = true;
      personasLoadError = null; // Resetear error
    });

    try {
      debugPrint('📋 [Modal] Cargando conductores y propietarios...');
      debugPrint('📋 [Modal] Token pasado a modal: ${widget.token?.isNotEmpty == true ? "presente (${widget.token!.length} chars)" : "NULO"}');
      
      final conds = await DocumentService.getConductores(token: widget.token);
      debugPrint('📋 [Modal] Conductores recibidos: ${conds.length}');
      for (int i = 0; i < conds.length && i < 3; i++) {
        debugPrint('   ===== CONDUCTOR $i =====');
        debugPrint('   JSON: ${jsonEncode(conds[i])}');
        conds[i].forEach((key, value) {
          debugPrint('     $key: $value (tipo: ${value.runtimeType})');
        });
      }
      
      final props = await DocumentService.getPropietarios(token: widget.token);
      debugPrint('📋 [Modal] Propietarios recibidos: ${props.length}');
      for (int i = 0; i < props.length && i < 3; i++) {
        debugPrint('   ===== PROPIETARIO $i =====');
        debugPrint('   JSON: ${jsonEncode(props[i])}');
        props[i].forEach((key, value) {
          debugPrint('     $key: $value (tipo: ${value.runtimeType})');
        });
      }

      if (mounted) {
        setState(() {
          conductores = conds;
          propietarios = props;
          isLoadingPersonas = false;
        });
        
        if (conds.isEmpty && props.isEmpty) {
          debugPrint('⚠️ [Modal] ¡SIN CONDUCTORES NI PROPIETARIOS!');
        }
      }
    } catch (e) {
      debugPrint('❌ [Modal] Error cargando personas: $e');
      if (mounted) {
        // Limpiar el mensaje de error para que sea más user-friendly
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11); // Remover "Exception: "
        }
        
        setState(() {
          isLoadingPersonas = false;
          personasLoadError = errorMessage;
        });
      }
    }
  }

  Future<void> _loadDocumentTypes() async {
    setState(() {
      isLoadingDocumentTypes = true;
    });

    try {
      debugPrint('📋 [Modal] Cargando tipos de documento...');
      final types = await DocumentService.getDocumentTypes(token: widget.token);
      debugPrint('📋 [Modal] Tipos de documento recibidos: ${types.length}');
      for (int i = 0; i < types.length; i++) {
        debugPrint('   Tipo $i: ${types[i]}');
      }

      if (mounted) {
        setState(() {
          documentTypes = types;
          isLoadingDocumentTypes = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [Modal] Error cargando tipos de documento: $e');
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
      selectedVehicleValue = null;  // Mantener null - el usuario debe seleccionar explícitamente
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
        _showErrorSnackBar('Error cargando vehículos: $e');
        setState(() {
          isLoadingVehiculos = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF11698E), Color(0xFF19456B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subir Documento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: isUploading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Sección: Seleccionar Conductor/Propietario
              _buildPersonaSection(),
              const SizedBox(height: 12),
              
              // Sección: Seleccionar Vehículo (dinámico)
              if (selectedPersonaId != null && vehiculos.isNotEmpty)
                _buildVehicleSection(),
              if (selectedPersonaId != null && vehiculos.isEmpty && !isLoadingVehiculos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta persona no tiene vehículos asignados',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Sección: Seleccionar archivo
              _buildFilePickerSection(),
              const SizedBox(height: 12),
              
              // Tipo de documento
              _buildDocumentTypeSection(),
              const SizedBox(height: 12),
              
              // Área
              _buildAreaSection(),
              const SizedBox(height: 12),
              
              // Fecha de vencimiento
              _buildExpiryDateSection(),
              const SizedBox(height: 12),
              
              // Observaciones
              _buildObservationsSection(),
              const SizedBox(height: 16),
              
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isUploading ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: isUploading
                        ? null
                        : (selectedFilePath == null ||
                                selectedDocumentTypeId == null ||
                                selectedExpiryDate == null ||
                                selectedPersonaId == null)
                            ? null
                            : _uploadDocument,
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.upload, color: Colors.white),
                    label: Text(
                      isUploading ? 'Subiendo...' : 'Subir',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16C79A),
                      disabledBackgroundColor: Colors.grey,
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
      ),
    );
  }

  Widget _buildPersonaSection() {
    final bool isEmpresa = widget.userRole.toLowerCase() == 'empresa';
    final String labelText = isEmpresa ? 'Conductor' : 'Conductor o Propietario';

    if (isLoadingPersonas) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: const SizedBox(
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error del servidor',
                        style: TextStyle(
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
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isEmpresa
                      ? '• Verifica que iniciaste sesión como EMPRESA\n• Asegúrate que hay conductores asignados a tu empresa\n• Contacta al administrador si el problema persiste'
                      : '• Contacta al administrador del sistema\n• Si el problema persiste, intenta refrescar la página',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadPersonas,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reintentar'),
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
    bool hasData = conductores.isNotEmpty || (isEmpresa ? false : propietarios.isNotEmpty);
    
    if (!hasData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No hay conductores disponibles',
                        style: TextStyle(
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
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.person_search, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Seleccione el Conductor o Propietario',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: [
              // Conductores
              if (conductores.isNotEmpty)
                const DropdownMenuItem<String>(
                  enabled: false,
                  value: 'header_conductores',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '👤 CONDUCTORES',
                      style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 11),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                const DropdownMenuItem<String>(
                  enabled: false,
                  value: 'header_propietarios',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '🏠 PROPIETARIOS',
                      style: TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold, fontSize: 11),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }),
              ],
            ],
            onChanged: (value) {
              if (value != null && value.contains('_')) {
                final parts = value.split('_');
                final tipo = parts[0];
                final id = int.tryParse(parts[1]) ?? 0;

                // Buscar el idUsuario de la persona seleccionada
                int? idUsuario;
                if (tipo == 'conductor') {
                  final persona = conductores.firstWhere(
                    (c) => _getIdPersona(c) == id,
                    orElse: () => <String, dynamic>{},
                  );
                  idUsuario = persona['idUsuario'] as int?;
                } else if (tipo == 'propietario') {
                  final persona = propietarios.firstWhere(
                    (p) => _getIdPersona(p) == id,
                    orElse: () => <String, dynamic>{},
                  );
                  idUsuario = persona['idUsuario'] as int?;
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
    if (isLoadingVehiculos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehículo Asignado (Opcional)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: const SizedBox(
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    // Seleccionar vehículo es opcional, ya que selectedVehicleId se maneja en el dropdown

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehículo Asignado',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedVehicleValue != null ? Colors.green : Colors.white24,
              width: selectedVehicleValue != null ? 2 : 1,
            ),
          ),
          child: DropdownButton<String?>(
            value: selectedVehicleValue,  // null = sin seleccionar
            isDense: true,
            underline: Container(),
            dropdownColor: const Color(0xFF19456B),
            isExpanded: true,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Seleccione el Vehículo (Opcional)',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: vehiculos.isEmpty
                ? [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          'No hay vehículos disponibles',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                  ]
                : [
                    // Primer item: "Sin seleccionar"
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          '-- Sin seleccionar --',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                    // Items de vehículos
                    ...vehiculos.map((v) {
                      final id = v['id'] is String ? int.parse(v['id'].toString()) : v['id'];
                      final value = 'vehicle_$id';
                      final placa = v['placa'] ?? 'Sin placa';
                      final marca = v['marca'] ?? '';
                      final modelo = v['modelo'] ?? '';
                      final label = '$placa - $marca $modelo'.trim();

                      return DropdownMenuItem<String?>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            label,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
            onChanged: (value) {
              setState(() {
                selectedVehicleValue = value;
                debugPrint('📍 [Vehicle Selection] onChanged value: $value');
                
                if (value != null && value.startsWith('vehicle_')) {
                  // Extraer el ID del valor
                  final idStr = value.replaceFirst('vehicle_', '');
                  selectedVehicleId = int.tryParse(idStr);
                  
                  debugPrint('📍 [Vehicle Selection] ID extraído: $selectedVehicleId');
                  debugPrint('📍 [Vehicle Selection] Buscando en lista de ${vehiculos.length} vehículos...');
                  
                  if (selectedVehicleId != null) {
                    final foundVehicle = vehiculos.firstWhere((v) {
                      final id = v['id'] is String ? int.parse(v['id'].toString()) : v['id'];
                      final match = id == selectedVehicleId;
                      debugPrint('   - Comparando: ${v['placa']} (id: ${v['id']}, tipo: ${v['id'].runtimeType}) == $selectedVehicleId? $match');
                      return match;
                    }, orElse: () => {});
                    
                    selectedVehiclePlaca = foundVehicle['placa'];
                    
                    debugPrint('📍 [Vehicle Selection] Vehículo seleccionado:');
                    debugPrint('   - Placa: $selectedVehiclePlaca');
                    debugPrint('   - ID: $selectedVehicleId');
                    debugPrint('   - Objeto completo: $foundVehicle');
                  }
                } else {
                  selectedVehicleId = null;
                  selectedVehiclePlaca = null;
                  debugPrint('📍 [Vehicle Selection] Vehículo deseleccionado');
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
        const Text(
          'Archivo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    selectedFileName ?? 'Seleccionar archivo',
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
    // Obtener nombre del tipo seleccionado desde la lista dinámica

    if (isLoadingDocumentTypes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de Documento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: const SizedBox(
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    if (documentTypes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de Documento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'No se cargaron tipos de documentos. Revise la conexión.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Documento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedDocumentTypeId != null ? Colors.purple : Colors.white24,
              width: selectedDocumentTypeId != null ? 2 : 1,
            ),
          ),
          child: DropdownButton<int>(
            value: selectedDocumentTypeId,
            isDense: true,
            underline: Container(),
            dropdownColor: const Color(0xFF19456B),
            isExpanded: true,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Seleccione el Tipo de Documento',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: documentTypes.map((type) {
              final id = type['id'];
              final nombre = type['nombre'] ?? type['nombre_tipo'] ?? 'Sin nombre';
              return DropdownMenuItem<int>(
                value: id,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedDocumentTypeId = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAreaSection() {
    // Obtener nombre del área seleccionada

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Área',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedArea != null && selectedArea!.isNotEmpty ? Colors.orange : Colors.white24,
              width: selectedArea != null && selectedArea!.isNotEmpty ? 2 : 1,
            ),
          ),
          child: DropdownButton<String>(
            value: selectedArea,
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
                      'Seleccione el tipo de Área',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'TECNICO',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'Técnico',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'LEGAL',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'Legal',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'ADMINISTRATIVO',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'Administrativo',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                selectedArea = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha de Vencimiento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      : 'Seleccionar fecha',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observaciones (opcional)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: observationController,
          maxLines: 3,
          enabled: !isUploading,
          decoration: InputDecoration(
            hintText: 'Agrega notas sobre el documento...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white12,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white),
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
        debugPrint('📁 Archivo seleccionado: ${file.name}');
        debugPrint('   - Path: ${file.path}');
        debugPrint('   - Bytes disponibles: ${file.bytes != null ? "sí (${file.bytes!.length} bytes)" : "no"}');
        
        setState(() {
          selectedFilePath = file.path ?? '';
          selectedFileName = file.name;
          selectedFileBytes = file.bytes; // Guardar bytes para web
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error seleccionando archivo: $e');
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
    // Validar solo los campos obligatorios (vehículo es opcional)
    if (selectedFilePath == null ||
        selectedDocumentTypeId == null ||
        selectedExpiryDate == null ||
        selectedPersonaId == null ||
        selectedArea == null ||
        selectedFileBytes == null) { // Validar que tengamos bytes del archivo
      _showErrorSnackBar('⚠️ Completa: Persona, Tipo, Archivo, Área y Fecha');
      return;
    }

    // Obtener el ID numérico del usuario seleccionado
    // selectedPersonaId ya es un int, no necesita split
    int? selectedPersonaIdInt = selectedPersonaId;

    setState(() {
      isUploading = true;
    });

    try {
      debugPrint('📤 Iniciando upload...');
      debugPrint('   - Persona seleccionada: $selectedPersonaIdInt ($selectedPersonaTipo)');
      debugPrint('   - Vehículo ID: $selectedVehicleId (tipo: ${selectedVehicleId?.runtimeType})');
      debugPrint('   - Vehículo Placa: $selectedVehiclePlaca');
      debugPrint('   - Vehículo Value: $selectedVehicleValue');
      debugPrint('   - Tipo: $selectedDocumentTypeId');
      debugPrint('   - Archivo: $selectedFileName');
      debugPrint('   - Token: ${widget.token?.isNotEmpty == true ? "presente (${widget.token!.length} chars)" : "NULO"}');
      
      // Debug: mostrar todos los vehículos disponibles
      if (vehiculos.isNotEmpty) {
        debugPrint('   📋 Vehículos disponibles en memoria:');
        for (int i = 0; i < vehiculos.length; i++) {
          final v = vehiculos[i];
          debugPrint('      [$i] Placa: ${v['placa']}, ID: ${v['id']} (tipo: ${v['id'].runtimeType})');
        }
      }

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
        personaIdUsuario: selectedPersonaIdUsuario, // Pasar el idUsuario correcto
        token: widget.token,
        fileBytes: selectedFileBytes, // Pasar bytes para web
      );

      if (mounted) {
        setState(() {
          isUploading = false;
        });

        if (result != null) {
          debugPrint('✅ Respuesta del servidor: $result');
          _showSuccessSnackBar('✅ Documento subido exitosamente');
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              Navigator.of(context).pop();
              widget.onSuccess?.call();
            }
          });
        } else {
          debugPrint('❌ Resultado NULL del upload');
          _showErrorSnackBar('❌ Error - Revisa los logs');
        }
      }
    } catch (e) {
      debugPrint('❌ Excepción en upload: $e');
      if (mounted) {
        setState(() {
          isUploading = false;
        });
        _showErrorSnackBar('❌ $e');
      }
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
