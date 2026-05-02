import 'package:flutter/material.dart';

import '../../services/document_service.dart';

class EditDocumentModal {
  static Future<void> show({
    required BuildContext context,
    required int documentoId,
    required int idTipo,
    required String tipoDocumento,
    required DateTime fechaVencimiento,
    required String? titular,
    required String? responsable,
    required String? observaciones,
    required String? area,
    required bool isVehicleDocument,
    required String vehicleId,
    required String ownerUserId,
    required String responsableUserId,
    required String empresaNombre,
    required String vehiclePlate,
    required List<Map<String, dynamic>> tiposDocumento,
    required VoidCallback onSuccess,
    List<Map<String, dynamic>>? documentosActuales,
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return _EditDocumentDialog(
          documentoId: documentoId,
          idTipo: idTipo,
          tipoDocumento: tipoDocumento,
          fechaVencimiento: fechaVencimiento,
          titular: titular,
          responsable: responsable,
          observaciones: observaciones,
          area: area,
          isVehicleDocument: isVehicleDocument,
          vehicleId: vehicleId,
          ownerUserId: ownerUserId,
          responsableUserId: responsableUserId,
          empresaNombre: empresaNombre,
          vehiclePlate: vehiclePlate,
          tiposDocumento: tiposDocumento,
          onSuccess: onSuccess,
          documentosActuales: documentosActuales ?? [],
        );
      },
    );
  }
}

class _EditDocumentDialog extends StatefulWidget {
  final int documentoId;
  final int idTipo;
  final String tipoDocumento;
  final DateTime fechaVencimiento;
  final String? titular;
  final String? responsable;
  final String? observaciones;
  final String? area;
  final bool isVehicleDocument;
  final String vehicleId;
  final String ownerUserId;
  final String responsableUserId;
  final String empresaNombre;
  final String vehiclePlate;
  final List<Map<String, dynamic>> tiposDocumento;
  final VoidCallback onSuccess;
  final List<Map<String, dynamic>> documentosActuales;

  const _EditDocumentDialog({
    required this.documentoId,
    required this.idTipo,
    required this.tipoDocumento,
    required this.fechaVencimiento,
    required this.titular,
    required this.responsable,
    required this.observaciones,
    required this.area,
    required this.isVehicleDocument,
    required this.vehicleId,
    required this.ownerUserId,
    required this.responsableUserId,
    required this.empresaNombre,
    required this.vehiclePlate,
    required this.tiposDocumento,
    required this.onSuccess,
    required this.documentosActuales,
  });

  @override
  State<_EditDocumentDialog> createState() => _EditDocumentDialogState();
}

class _EditDocumentDialogState extends State<_EditDocumentDialog> {
  late int selectedDocumentTypeId;
  late String? selectedArea;
  late DateTime selectedExpiryDate;
  late TextEditingController observationsController;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    selectedArea = widget.area;
    selectedExpiryDate = widget.fechaVencimiento;
    observationsController = TextEditingController(
      text: widget.observaciones ?? '',
    );

    // Verificar que el documento inicial esté en la lista filtrada
    final filteredDocs = _getFilteredDocumentTypes();
    final idTipoExists = filteredDocs.any((doc) => doc['id'] == widget.idTipo);

    if (idTipoExists) {
      selectedDocumentTypeId = widget.idTipo;
    } else if (filteredDocs.isNotEmpty) {
      // Si el ID original no está disponible, usar el primero de la lista filtrada
      selectedDocumentTypeId =
          int.tryParse(filteredDocs[0]['id'].toString()) ?? 0;
    } else {
      selectedDocumentTypeId = 0;
    }

    // Validar que el área inicial sea válida
    final initialPermittedAreas = _getPermittedAreas(selectedDocumentTypeId);
    if (selectedArea == null ||
        selectedArea!.isEmpty ||
        !initialPermittedAreas.contains(selectedArea)) {
      selectedArea = initialPermittedAreas.isNotEmpty
          ? initialPermittedAreas[0]
          : null;
    }
  }

  @override
  void dispose() {
    observationsController.dispose();
    super.dispose();
  }

  /// Categoriza documentos según su aplicabilidad
  String _categorizeDocumentType(String nombreDocumento) {
    final nombre = nombreDocumento.toUpperCase().trim();
    if (nombre == 'LICENCIA') return 'CONDUCTOR';
    if (nombre == 'RUT' || nombre == 'CERTIFICADO_PROPIEDAD'){
      return 'PROPIETARIO';
    }
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
    if (nombre == 'CEDULA' || nombre == 'PASAPORTE') return 'AMBOS_PERSONA';
    return 'FLEXIBLE';
  }

  /// Obtiene las áreas permitidas para un tipo de documento
  List<String> _getPermittedAreas(int? documentTypeId) {
    if (documentTypeId == null) {
      return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
    }

    final docType = widget.tiposDocumento.firstWhere(
      (d) => d['id'] == documentTypeId,
      orElse: () => <String, dynamic>{},
    );

    if (docType.isEmpty) {
      return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
    }

    final nombre = docType['nombre']?.toString().toUpperCase() ?? '';

    // LICENCIA, CEDULA, PASAPORTE → Legal
    if (nombre == 'LICENCIA' || nombre == 'CEDULA' || nombre == 'PASAPORTE') {
      return const ['LEGAL'];
    }
    // RUT → Administrativa
    if (nombre == 'RUT') {
      return const ['ADMINISTRATIVO'];
    }
    // CERTIFICADO_PROPIEDAD → Legal
    if (nombre == 'CERTIFICADO_PROPIEDAD') {
      return const ['LEGAL'];
    }
    // SOAT, SEGURO, etc → Legal
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
    // OTRO → Administrativa
    if (nombre == 'OTRO') {
      return const ['ADMINISTRATIVO'];
    }

    return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
  }

  /// Obtiene documentos filtrados según si es de usuario o vehículo
  /// No diferencia entre conductor y propietario para documentos personales
  List<Map<String, dynamic>> _getFilteredDocumentTypes() {
    if (widget.tiposDocumento.isEmpty) return [];

    final filtered = widget.tiposDocumento.where((doc) {
      final docName = doc['nombre']?.toString() ?? '';
      final category = _categorizeDocumentType(docName);

      if (widget.isVehicleDocument) {
        // Si es vehículo: mostrar VEHICULO o FLEXIBLE
        return category == 'VEHICULO' || category == 'FLEXIBLE';
      } else {
        // Si es usuario: mostrar todo excepto VEHICULO
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

    return uniqueById.values.toList();
  }

  Future<void> _updateDocument() async {
    setState(() {
      isUpdating = true;
    });

    try {
      // Validar datos
      if (selectedDocumentTypeId == 0 ||
          selectedArea == null ||
          selectedArea!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor completa todos los campos'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => isUpdating = false);
        return;
      }

      // Enviar idVehiculo SOLO para documentos de vehículo
      // Para documentos de usuario: enviar idUsuario (propietario del documento)
      int? idVehiculo = widget.isVehicleDocument
          ? int.tryParse(widget.vehicleId)
          : null;
      int? responsableUsuarioId; // Nunca enviar responsableUsuarioId/
      int? idUsuario = !widget.isVehicleDocument
          ? int.tryParse(widget.ownerUserId)
          : null;

      debugPrint(
        '🔐 [_updateDocument] idVehiculo: $idVehiculo, responsableUsuarioId: $responsableUsuarioId, idUsuario: $idUsuario, isVehicleDocument: ${widget.isVehicleDocument}',
      );

      // Desactivar y Buscar documentos duplicados (mismo tipo pero documento diferente)
      await _deactivateDuplicateDocuments();

      await DocumentService.updateDocument(
        documentoId: widget.documentoId,
        idTipo: selectedDocumentTypeId,
        area: selectedArea!,
        fechaVencimiento: selectedExpiryDate,
        observaciones: observationsController.text,
        idVehiculo: idVehiculo,
        responsableUsuarioId: responsableUsuarioId,
        idUsuario: idUsuario,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Documento actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  /// Busca y deactiva documentos duplicados del mismo tipo
  /// Cuando se edita un documento a un tipo que ya existe activo
  /// el anterior debe deactivarse
  Future<void> _deactivateDuplicateDocuments() async {
    try {
      if (widget.documentosActuales.isEmpty) {
        debugPrint('ℹ️ No hay documentos para comparar');
        return;
      }

      // Buscar documentos activos del mismo tipo
      final duplicates = widget.documentosActuales.where((doc) {
        final int docId =
            int.tryParse(doc['documentoId']?.toString() ?? '0') ?? 0;
        final int docIdTipo =
            int.tryParse(doc['idTipo']?.toString() ?? '0') ?? 0;
        final bool docEstado =
            doc['estadoDocumento'] == true ||
            doc['estadoDocumento'].toString().toLowerCase() == 'true';
        final String docVehicleId = doc['vehicleId']?.toString() ?? '';
        final String docOwnerId = doc['ownerId']?.toString() ?? '';

        // Condición: documento DIFERENTE, MISMO TIPO, ACTIVO
        if (docId == widget.documentoId) {
          return false; // No es el documento que estamos editando
        }

        if (docIdTipo != selectedDocumentTypeId) {
          return false; // No es del mismo tipo
        }

        if (!docEstado) {
          return false; // Ya está inactivo
        }

        // Si es documento de vehículo: comparar vehicleId
        if (widget.isVehicleDocument) {
          return docVehicleId == widget.vehicleId;
        }

        // Si es documento de usuario: comparar ownerId (idUsuario)
        return docOwnerId == widget.ownerUserId;
      }).toList();
      debugPrint('🔎 Duplicados encontrados: ${duplicates.length}');
      // Deactivar cada documento duplicado encontrado
      for (final duplicate in duplicates) {
        final int duplicateId =
            int.tryParse(duplicate['documentoId']?.toString() ?? '0') ?? 0;
        if (duplicateId > 0) {
          debugPrint('🔴 Deactivando documento duplicado $duplicateId');
          await DocumentService.updateDocumentStatus(
            documentoId: duplicateId,
            estado: false,
          );
          debugPrint('✅ Documento $duplicateId desactivado exitosamente');
        }
      }

      if (duplicates.isNotEmpty) {
        debugPrint(
          '📋 Se deactivaron ${duplicates.length} documento(s) duplicado(s)',
        );
      }
    } catch (e) {
      debugPrint('❌ Error en _deactivateDuplicateDocuments: $e');
      // No fallar la operación principal
    }
  }

  @override
  Widget build(BuildContext context) {
    //final filteredDocuments = _getFilteredDocumentTypes();
    //final permittedAreas = _getPermittedAreas(selectedDocumentTypeId);

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
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Editar Documento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: isUpdating
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Información de referencia (solo lectura)
              _buildReadOnlyField(
                'Responsable',
                widget.responsable ?? 'No asignado',
              ),
              const SizedBox(height: 16),

              if (!widget.isVehicleDocument)
                _buildReadOnlyField('Titular', widget.titular ?? 'No asignado')
              else
                _buildReadOnlyField('Vehículo', widget.vehiclePlate),
              const SizedBox(height: 16),

              // Tipo de documento (solo lectura)
              _buildReadOnlyField('Tipo de Documento', widget.tipoDocumento),
              const SizedBox(height: 4),
              // Área (solo lectura)
              _buildReadOnlyField('Área', selectedArea ?? 'No asignada'),
              const SizedBox(height: 16),
              // Fecha de vencimiento (editable)
              Text(
                'Fecha de Vencimiento',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: isUpdating
                    ? null
                    : () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedExpiryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                primaryColor: const Color(0xFF4F4CE8),
                                scaffoldBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => selectedExpiryDate = picked);
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedExpiryDate.day.toString().padLeft(2, '0')}/${selectedExpiryDate.month.toString().padLeft(2, '0')}/${selectedExpiryDate.year}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Observaciones (editable)
              Text(
                'Observaciones',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: observationsController,
                enabled: !isUpdating,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Notas adicionales...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isUpdating
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: isUpdating ? null : _updateDocument,
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      isUpdating ? 'Guardando...' : 'Guardar Cambios',
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

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.lock_outline, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}
