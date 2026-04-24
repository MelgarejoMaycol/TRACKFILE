import 'package:flutter/material.dart';

class DocumentModal {
  static void show({
    required BuildContext context,
    required String documentName,
    DateTime? creationDate,
    required DateTime expiryDate,
    String? ownerName,
    String? area,
    String? category,
    String? vehiclePlate,
    String? role,
    int? daysRemaining,
    VoidCallback? onDownload,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                      Expanded(
                        child: Text(
                          documentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Información para EMPRESA
                  if (role?.toLowerCase() == 'empresa') ...[
                    if (ownerName != null && ownerName.isNotEmpty) ...[
                      _buildModalRow(
                        Icons.person,
                        'Propietario/Responsable',
                        ownerName,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (vehiclePlate != null && vehiclePlate.isNotEmpty) ...[
                      _buildModalRow(
                        Icons.directions_car,
                        'Placa del Vehículo',
                        vehiclePlate,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (category != null && category.isNotEmpty) ...[
                      _buildModalRow(
                        Icons.label,
                        'Tipo de Documento',
                        category,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (area != null && area.isNotEmpty) ...[
                      _buildModalRow(
                        Icons.domain,
                        'Área',
                        area,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ]
                  
                  // Información para CONDUCTOR y PROPIETARIO
                  else ...[
                    if (category != null && category.isNotEmpty) ...[
                      _buildModalRow(
                        Icons.label,
                        'Tipo de Documento',
                        category,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (area != null && area.isNotEmpty) ...[
                      _buildModalRow(
                        Icons.domain,
                        'Área',
                        area,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (vehiclePlate != null && vehiclePlate.isNotEmpty) ...[
                      _buildModalRow(
                        Icons.directions_car,
                        'Placa del Vehículo',
                        vehiclePlate,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  
                  // Información común para todos
                  _buildModalRow(
                    Icons.calendar_today,
                    'Fecha de Creación',
                    creationDate != null ? _formatDate(creationDate) : 'No disponible',
                  ),
                  const SizedBox(height: 16),
                  _buildModalRow(
                    Icons.event,
                    'Fecha de Vencimiento',
                    _formatDate(expiryDate),
                  ),
                  const SizedBox(height: 16),
                  _buildModalRow(
                    Icons.timer,
                    'Días Restantes',
                    daysRemaining != null 
                      ? (daysRemaining < 0 ? 'Vencido' : daysRemaining == 0 ? 'Se vence hoy' : '$daysRemaining días')
                      : () {
                          final DateTime todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                          final DateTime expiryOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                          final int days = expiryOnly.difference(todayOnly).inDays;
                          return days < 0 ? 'Vencido' : days == 0 ? 'Se vence hoy' : '$days días';
                        }(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (onDownload != null) {
                          onDownload();
                        } else {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Descargando $documentName...'),
                              backgroundColor: const Color(0xFF16C79A),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'Descargar Documento',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16C79A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  static Widget _buildModalRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
