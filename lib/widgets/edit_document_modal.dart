import 'package:flutter/material.dart';
import '../services/document_service.dart';

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
    bool isVehicleDocument = false,
    String vehicleId = '',
    String ownerUserId = '', // ID del usuario propietario del documento
    required List<Map<String, dynamic>> tiposDocumento,
    required List<Map<String, dynamic>> usuarios,
    required VoidCallback onSuccess,
  }) async {
    final TextEditingController observacionesController =
        TextEditingController(text: observaciones ?? '');
    DateTime selectedDate = fechaVencimiento;
    int? selectedTipoId = idTipo;
    String? selectedArea = area;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Obtener áreas permitidas según el tipo actual
            final permittedAreas = _getPermittedAreas(selectedTipoId, tiposDocumento);
            
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
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
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Responsable (solo lectura)
                      _buildReadOnlyField('Responsable', responsable ?? 'No asignado'),
                      const SizedBox(height: 16),

                      // Titular (solo lectura)
                      _buildReadOnlyField('Titular', titular ?? 'No asignado'),
                      const SizedBox(height: 16),

                      // Tipo de documento (dropdown editable)
                      Text(
                        'Tipo de Documento',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButton<int>(
                          value: selectedTipoId,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          dropdownColor: const Color(0xFF19456B),
                          items: tiposDocumento
                              .map((e) => DropdownMenuItem(
                                    value: int.tryParse(e['id'].toString()) ?? 0,
                                    child: Text(
                                      e['nombre'].toString(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedTipoId = value;
                              // Validar el área actual contra las nuevas permitidas
                              final newPermittedAreas =
                                  _getPermittedAreas(value, tiposDocumento);
                              if (selectedArea == null ||
                                  selectedArea!.isEmpty ||
                                  !newPermittedAreas.contains(selectedArea)) {
                                // Si el área no es válida, asignar la primera permitida
                                selectedArea =
                                    newPermittedAreas.isNotEmpty ? newPermittedAreas[0] : null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Área (dropdown dinámico según tipo de documento)
                      Text(
                        'Área',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildAreaDropdown(
                        selectedTipoId: selectedTipoId ?? 0,
                        tiposDocumento: tiposDocumento,
                        currentArea: selectedArea ?? '',
                        permittedAreas: permittedAreas,
                        onAreaChanged: (newArea) {
                          setState(() {
                            selectedArea = newArea;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Fecha de vencimiento
                      Text(
                        'Fecha de Vencimiento',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
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
                            setState(() => selectedDate = picked);
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
                                '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Observaciones
                      Text(
                        'Observaciones',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: observacionesController,
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
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                // Convertir vehicleId a int si existe y es documento de vehículo
                                int? idVehiculo = (isVehicleDocument && vehicleId.isNotEmpty)
                                    ? int.tryParse(vehicleId)
                                    : null;
                                
                                // Convertir ownerUserId a int si existe y es documento personal
                                int? idUsuario = (!isVehicleDocument && ownerUserId.isNotEmpty)
                                    ? int.tryParse(ownerUserId)
                                    : null;
                                
                                await DocumentService.updateDocument(
                                  documentoId: documentoId,
                                  idTipo: selectedTipoId ?? idTipo,
                                  area: selectedArea ?? area ?? '',
                                  fechaVencimiento: selectedDate,
                                  observaciones: observacionesController.text,
                                  idVehiculo: idVehiculo,
                                  idUsuario: idUsuario,
                                );

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  onSuccess();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al guardar: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text(
                              'Guardar Cambios',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16C79A),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          },
        );
      },
    );
  }

  // Obtiene las áreas permitidas para un tipo de documento
  static List<String> _getPermittedAreas(int? documentTypeId, List<Map<String, dynamic>> tiposDocumento) {
    if (documentTypeId == null) {
      return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
    }

    final docType = tiposDocumento.firstWhere(
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

    // RUT → Administrativa
    if (nombre == 'RUT') {
      return const ['ADMINISTRATIVO'];
    }

    // CERTIFICADO_PROPIEDAD → Legal
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

    // OTRO → Administrativa
    if (nombre == 'OTRO') {
      return const ['ADMINISTRATIVO'];
    }

    // Por defecto, todas las áreas
    return const ['TECNICA', 'LEGAL', 'ADMINISTRATIVO'];
  }

  // Widget para el dropdown de área
  static Widget _buildAreaDropdown({
    required int selectedTipoId,
    required List<Map<String, dynamic>> tiposDocumento,
    required String currentArea,
    required List<String> permittedAreas,
    required Function(String?) onAreaChanged,
  }) {
    final areaOptions = {
      'TECNICA': ('🔧 Técnica', Icons.build),
      'LEGAL': ('⚖️ Legal', Icons.balance),
      'ADMINISTRATIVO': ('📋 Administrativo', Icons.description),
    };

    // Validar que el área actual esté en las permitidas
    bool currentAreaIsValid = currentArea.isNotEmpty && permittedAreas.contains(currentArea);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButton<String>(
        value: currentAreaIsValid ? currentArea : null,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF19456B),
        hint: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.category, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Selecciona el área',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Icon(displayInfo.$2, color: Colors.white70, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    displayInfo.$1,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: onAreaChanged,
      ),
    );
  }

  static Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
