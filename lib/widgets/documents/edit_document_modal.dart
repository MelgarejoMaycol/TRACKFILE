import 'package:flutter/material.dart';

import '../../services/document_service.dart';

class EditDocumentModal {
  static Future<void> show({
    required BuildContext context,
    required int documentoId,
    required int idTipo,
    required String area,
    required DateTime fechaVencimiento,
    required String observaciones,
    required int? idVehiculo,
    required int? idUsuario,
    required VoidCallback onSuccess,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _EditDocumentDateDialog(
        documentoId: documentoId,
        idTipo: idTipo,
        area: area,
        fechaVencimiento: fechaVencimiento,
        observaciones: observaciones,
        idVehiculo: idVehiculo,
        idUsuario: idUsuario,
        onSuccess: onSuccess,
      ),
    );
  }
}

class _EditDocumentDateDialog extends StatefulWidget {
  final int documentoId;
  final int idTipo;
  final String area;
  final DateTime fechaVencimiento;
  final String observaciones;
  final int? idVehiculo;
  final int? idUsuario;
  final VoidCallback onSuccess;

  const _EditDocumentDateDialog({
    required this.documentoId,
    required this.idTipo,
    required this.area,
    required this.fechaVencimiento,
    required this.observaciones,
    required this.idVehiculo,
    required this.idUsuario,
    required this.onSuccess,
  });

  @override
  State<_EditDocumentDateDialog> createState() =>
      _EditDocumentDateDialogState();
}

class _EditDocumentDateDialogState extends State<_EditDocumentDateDialog> {
  late DateTime _fechaSeleccionada;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = widget.fechaVencimiento;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);

    try {
      await DocumentService.updateDocument(
        documentoId: widget.documentoId,
        idTipo: widget.idTipo,
        area: widget.area,
        fechaVencimiento: _fechaSeleccionada,
        observaciones: widget.observaciones,
        idVehiculo: widget.idVehiculo,
        idUsuario: widget.idUsuario,
        responsableUsuarioId: null,
      );

      if (!mounted) return;

      Navigator.pop(context);
      widget.onSuccess();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fecha actualizada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la fecha: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
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
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeroHeader(context),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _guardando
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _fechaSeleccionada,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );

                              if (picked != null) {
                                setState(() => _fechaSeleccionada = picked);
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${_fechaSeleccionada.day.toString().padLeft(2, '0')}/${_fechaSeleccionada.month.toString().padLeft(2, '0')}/${_fechaSeleccionada.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.edit_calendar,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _guardando
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _guardando ? 'Guardando...' : 'Guardar',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F4CE8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
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
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar fecha',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Actualiza la fecha de vencimiento del documento.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
