import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../documents/document_preview_modal.dart';
import '../utils/shimmer_skeleton.dart';

class CertificacionesWidget extends StatefulWidget {
  final String role;
  final String? userId;

  final String? personaUserId;
  final String? personaRole;
  final String? personaNombre;

  const CertificacionesWidget({
    super.key,
    required this.role,
    this.userId,
    this.personaUserId,
    this.personaRole,
    this.personaNombre,
  });

  @override
  State<CertificacionesWidget> createState() => _CertificacionesWidgetState();
}

class _TipoSolicitud {
  final int id;
  final String nombre;
  final String descripcion;

  const _TipoSolicitud({
    required this.id,
    required this.nombre,
    required this.descripcion,
  });

  factory _TipoSolicitud.fromMap(Map<String, dynamic> map) {
    return _TipoSolicitud(
      id:
          int.tryParse(
            (map['id'] ?? map['idTipoSolicitud'] ?? map['id_tipo_solicitud'])
                    ?.toString() ??
                '',
          ) ??
          0,
      nombre: map['nombre']?.toString() ?? 'Tipo sin nombre',
      descripcion: map['descripcion']?.toString() ?? '',
    );
  }
}

class _Solicitud {
  final int id;
  final String idUsuario;
  final int idTipo;
  final String descripcion;
  final String estado;
  final DateTime? fechaEnvio;
  final String? urlDocumento;
  final int? idDocumento;
  final int? idVehiculo;
  final String nombreSolicitante;
  final String documentoSolicitante;
  final String correoSolicitante;
  final String telefonoSolicitante;
  final String rolSolicitante;

  const _Solicitud({
    required this.id,
    required this.idUsuario,
    required this.idTipo,
    required this.descripcion,
    required this.estado,
    required this.fechaEnvio,
    required this.urlDocumento,
    required this.idDocumento,
    required this.idVehiculo,
    required this.nombreSolicitante,
    required this.documentoSolicitante,
    required this.correoSolicitante,
    required this.telefonoSolicitante,
    required this.rolSolicitante,
  });

  factory _Solicitud.fromMap(Map<String, dynamic> map) {
    final DateTime? fecha = DateTime.tryParse(
      (map['fechaEnvio'] ?? map['fecha_envio'])?.toString() ?? '',
    );

    final dynamic rawDocumento =
        map['documentoId'] ?? map['idDocumento'] ?? map['id_documento'];

    final dynamic rawVehiculo =
        map['vehiculoId'] ?? map['idVehiculo'] ?? map['id_vehiculo'];

    return _Solicitud(
      id:
          int.tryParse(
            (map['id'] ?? map['idSolicitud'] ?? map['id_solicitud'])
                    ?.toString() ??
                '',
          ) ??
          0,
      idUsuario:
          (map['usuarioId'] ?? map['idUsuario'] ?? map['id_usuario'])
              ?.toString() ??
          '',
      idTipo:
          int.tryParse(
            (map['tipoSolicitudId'] ??
                        map['idTipoSolicitud'] ??
                        map['id_tipo_solicitud'])
                    ?.toString() ??
                '',
          ) ??
          0,
      descripcion: map['descripcion']?.toString() ?? 'Sin descripción',
      estado: map['estado']?.toString() ?? 'EN_REVISION',
      fechaEnvio: fecha,
      urlDocumento: (map['urlDocumento'] ?? map['url_documento'])?.toString(),
      idDocumento: rawDocumento == null
          ? null
          : int.tryParse(rawDocumento.toString()),
      idVehiculo: rawVehiculo == null
          ? null
          : int.tryParse(rawVehiculo.toString()),
      nombreSolicitante: [
        map['nombreSolicitante']?.toString() ??
            map['nombreUsuario']?.toString() ??
            '',
        map['apellidoSolicitante']?.toString() ??
            map['apellidoUsuario']?.toString() ??
            '',
      ].where((item) => item.trim().isNotEmpty).join(' '),
      documentoSolicitante:
          map['documentoSolicitante']?.toString() ??
          map['documentoUsuario']?.toString() ??
          map['numeroDocumento']?.toString() ??
          '',
      correoSolicitante:
          map['correoSolicitante']?.toString() ??
          map['correoUsuario']?.toString() ??
          map['emailUsuario']?.toString() ??
          '',
      telefonoSolicitante:
          map['telefonoSolicitante']?.toString() ??
          map['telefonoUsuario']?.toString() ??
          '',
      rolSolicitante:
          map['rolSolicitante']?.toString() ??
          map['rolUsuario']?.toString() ??
          '',
    );
  }
}

class _Historial {
  final int id;
  final int idSolicitud;
  final String accion;
  final DateTime? fecha;
  final String observaciones;

  const _Historial({
    required this.id,
    required this.idSolicitud,
    required this.accion,
    required this.fecha,
    required this.observaciones,
  });

  factory _Historial.fromMap(Map<String, dynamic> map) {
    final DateTime? fecha = DateTime.tryParse(map['fecha']?.toString() ?? '');

    return _Historial(
      id:
          int.tryParse(
            (map['id'] ?? map['idHistorial'] ?? map['id_historial'])
                    ?.toString() ??
                '',
          ) ??
          0,
      idSolicitud:
          int.tryParse(
            (map['solicitudId'] ?? map['idSolicitud'] ?? map['id_solicitud'])
                    ?.toString() ??
                '',
          ) ??
          0,
      accion: map['accion']?.toString() ?? 'EN_REVISION',
      fecha: fecha,
      observaciones: map['observaciones']?.toString() ?? '',
    );
  }
}

class _SolicitudDetalle {
  final _Solicitud solicitud;
  final _TipoSolicitud? tipo;
  final List<_Historial> historial;

  const _SolicitudDetalle({
    required this.solicitud,
    required this.tipo,
    required this.historial,
  });

  String get estadoActual => solicitud.estado.toUpperCase();

  _Historial? get ultimoMovimiento {
    if (historial.isEmpty) {
      return null;
    }
    final List<_Historial> ordered = List<_Historial>.from(historial)
      ..sort((a, b) {
        final DateTime aDate =
            a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate =
            b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return ordered.first;
  }
}

class _CertificacionesWidgetState extends State<CertificacionesWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _surfaceColor = Color(0xFF131741);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);
  static const Color _infoColor = Color(0xFF3DA9F5);

  final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy');
  late final String _roleNormalized;

  bool _isLoading = true;
  bool _hasError = false;
  List<_SolicitudDetalle> _detalles = const [];
  Map<String, int> _conteoEstados = const {};
  List<_TipoSolicitud> _tiposSolicitud = const [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedSolicitudId;
  bool get _viendoPersona =>
      widget.personaUserId != null && widget.personaUserId!.trim().isNotEmpty;

  bool get _puedeGestionarSolicitudes =>
      _roleNormalized == 'empresa' ||
      _roleNormalized == 'admin' ||
      _roleNormalized == 'secretaria';

  @override
  void initState() {
    super.initState();
    _roleNormalized = widget.role.toLowerCase();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final List<Map<String, dynamic>> tiposRaw =
          await ApiService.getTiposSolicitud();

      final List<Map<String, dynamic>> solicitudesRaw =
          await ApiService.getSolicitudes();

      final List<_TipoSolicitud> tipos = tiposRaw
          .map(_TipoSolicitud.fromMap)
          .where((tipo) => tipo.id != 0)
          .toList();

      final Map<int, _TipoSolicitud> tiposById = {
        for (final tipo in tipos) tipo.id: tipo,
      };

      final List<_Solicitud> solicitudes = solicitudesRaw
          .map(_Solicitud.fromMap)
          .where((solicitud) => solicitud.id != 0)
          .toList();

      final List<_SolicitudDetalle> todosDetalles = [];

      for (final solicitud in solicitudes) {
        final List<Map<String, dynamic>> historialRaw =
            await ApiService.getHistorialSolicitud(solicitud.id);

        final List<_Historial> historial = historialRaw
            .map(_Historial.fromMap)
            .toList();

        todosDetalles.add(
          _SolicitudDetalle(
            solicitud: solicitud,
            tipo: tiposById[solicitud.idTipo],
            historial: historial,
          ),
        );
      }

      final List<_SolicitudDetalle> detallesSeleccionados =
          _selectDetallesForRole(todosDetalles);

      if (!mounted) return;

      setState(() {
        _tiposSolicitud = tipos;
        _assignDetalles(detallesSeleccionados);
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('❌ Error cargando certificaciones desde API: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerCertificacionesPage();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < 600;
        final bool isTableCompact = width < 1200;
        return _buildRoleContent(isCompact, isTableCompact);
      },
    );
  }

  Widget _buildRoleContent(bool isCompact, bool isTableCompact) {
    debugPrint(
      '=== BUILD ROLE CONTENT === Role: $_roleNormalized | isCompact: $isCompact',
    );
    if (_viendoPersona) {
      return _buildPersonaCertificacionesLayout(isCompact, isTableCompact);
    }
    switch (_roleNormalized) {
      case 'propietario':
      case 'conductor':
        return _buildOwnerConductorLayout(isCompact, isTableCompact);
      case 'empresa':
      case 'admin':
      case 'secretaria':
        return _buildCommonLayout(
          isCompact: isCompact,
          title: 'Panel de certificaciones',
          subtitle:
              'Visualiza y gestiona las solicitudes enviadas por los conductores.',
          tableDetalles: _detalles,
          tableCompact: isTableCompact,
        );
      default:
        final List<_SolicitudDetalle> aprobadas = _detalles
            .where(
              (detalle) =>
                  _normalizeStatus(detalle.estadoActual).startsWith('APROB'),
            )
            .toList();
        return _buildCommonLayout(
          isCompact: isCompact,
          title: 'Estado de certificaciones',
          subtitle:
              'Seguimiento de las solicitudes que realiza el conductor (certificado laboral, antecedentes y mas).',
          tableDetalles: aprobadas,
          tableCompact: isTableCompact,
          tableTitle: 'Historial de certificados aprobados',
          tableEmptyMessage: 'Aun no tienes certificaciones aprobadas.',
        );
    }
  }

  List<_SolicitudDetalle> _filtrarDetalles(List<_SolicitudDetalle> detalles) {
    final String query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return detalles;

    return detalles.where((detalle) {
      final String tipo = detalle.tipo?.nombre.toLowerCase() ?? '';
      final String nombre = detalle.solicitud.nombreSolicitante.toLowerCase();
      final String documento = detalle.solicitud.documentoSolicitante
          .toLowerCase();
      final String estado = _statusLabel(detalle.estadoActual).toLowerCase();
      final String estadoRaw = detalle.estadoActual.toLowerCase();

      if (_puedeGestionarSolicitudes) {
        return tipo.contains(query) ||
            nombre.contains(query) ||
            documento.contains(query) ||
            estado.contains(query) ||
            estadoRaw.contains(query);
      }

      return tipo.contains(query) ||
          estado.contains(query) ||
          estadoRaw.contains(query);
    }).toList();
  }

  Widget _buildSearchBox(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: const Icon(
            Icons.search_rounded,
            color: Colors.white60,
            size: 20,
          ),
          hintText: _puedeGestionarSolicitudes
              ? 'Buscar por nombre, documento o tipo de solicitud...'
              : 'Buscar por tipo de solicitud...',
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          suffixIcon: _searchQuery.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCommonLayout({
    required bool isCompact,
    required String title,
    required String subtitle,
    required List<_SolicitudDetalle>? tableDetalles,
    required bool tableCompact,
    String? tableTitle,
    String? tableEmptyMessage,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        24,
        isCompact ? 16 : 24,
        isCompact ? 120 : 64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isCompact ? 700 : 1600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              _buildSummaryChips(isCompact),
              const SizedBox(height: 14),

              if (tableDetalles != null) ...[
                _buildSearchBox(isCompact),
                const SizedBox(height: 14),
                _buildEmpresaTwoColumnLayout(
                  _filtrarDetalles(tableDetalles),
                  tableCompact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerConductorLayout(bool isCompact, bool isTableCompact) {
    final List<_SolicitudDetalle> enRevision = _detalles
        .where(
          (detalle) =>
              _normalizeStatus(detalle.estadoActual).contains('REVISION'),
        )
        .toList();

    final List<_SolicitudDetalle> historialFinal = _detalles
        .where(
          (detalle) =>
              !_normalizeStatus(detalle.estadoActual).contains('REVISION'),
        )
        .toList();

    historialFinal.sort((a, b) {
      final DateTime aFecha =
          a.solicitud.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bFecha =
          b.solicitud.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bFecha.compareTo(aFecha);
    });

    final List<_SolicitudDetalle> detallesOrdenados = [
      ...enRevision,
      ...historialFinal,
    ];

    return Stack(
      children: [
        _buildCommonLayout(
          isCompact: isCompact,
          title: 'Certificaciones',
          subtitle: 'Solicita y consulta el estado de tus certificados.',
          tableDetalles: detallesOrdenados,
          tableCompact: isTableCompact,
        ),

        Positioned(
          right: isCompact ? 18 : 28,
          bottom: isCompact ? 24 : 28,
          child: FloatingActionButton.extended(
            onPressed: _showSolicitudCertificadoModal,
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            elevation: 8,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              isCompact ? 'Solicitar' : 'Solicitar certificado',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonaCertificacionesLayout(
    bool isCompact,
    bool isTableCompact,
  ) {
    final String nombre = widget.personaNombre ?? 'la persona';
    final String rol = widget.personaRole ?? 'Usuario';

    final List<_SolicitudDetalle> enRevision = _detalles
        .where(
          (detalle) =>
              _normalizeStatus(detalle.estadoActual).contains('REVISION'),
        )
        .toList();

    final List<_SolicitudDetalle> historialFinal = _detalles
        .where(
          (detalle) =>
              !_normalizeStatus(detalle.estadoActual).contains('REVISION'),
        )
        .toList();

    historialFinal.sort((a, b) {
      final DateTime aFecha =
          a.solicitud.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bFecha =
          b.solicitud.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bFecha.compareTo(aFecha);
    });

    final List<_SolicitudDetalle> detallesOrdenados = [
      ...enRevision,
      ...historialFinal,
    ];

    return _buildCommonLayout(
      isCompact: isCompact,
      title: 'Certificaciones de $nombre',
      subtitle:
          'Consulta solicitudes, certificados e historial de esta persona. Rol: $rol.',
      tableDetalles: detallesOrdenados,
      tableCompact: isTableCompact,
    );
  }

  Widget _buildEmpresaTwoColumnLayout(
    List<_SolicitudDetalle> detalles,
    bool tableCompact,
  ) {
    final List<_SolicitudDetalle> enRevision = detalles
        .where((d) => _normalizeStatus(d.estadoActual).contains('REVISION'))
        .toList();

    final List<_SolicitudDetalle> historialFinal = detalles
        .where((d) => !_normalizeStatus(d.estadoActual).contains('REVISION'))
        .toList();

    if (detalles.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stack = constraints.maxWidth < 900;

        final Widget? revisionPanel = enRevision.isEmpty
            ? null
            : _buildSectionPanel(
                title: 'En revisión',
                count: enRevision.length,
                color: _warningColor,
                icon: Icons.hourglass_top_rounded,
                emptyMessage: 'No hay solicitudes en revisión',
                children: enRevision
                    .map(
                      (detalle) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildSolicitudCard(detalle),
                      ),
                    )
                    .toList(),
              );

        final Widget? historialPanel = historialFinal.isEmpty
            ? null
            : _buildSectionPanel(
                title: 'Historial',
                count: historialFinal.length,
                color: _successColor,
                icon: Icons.history_rounded,
                emptyMessage: 'No hay solicitudes en historial',
                children: historialFinal
                    .map(
                      (detalle) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildSolicitudCard(detalle),
                      ),
                    )
                    .toList(),
              );

        if (revisionPanel == null && historialPanel != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _warningColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: _warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No tienes solicitudes en revisión actualmente.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              historialPanel,
            ],
          );
        }

        if (historialPanel == null && revisionPanel != null) {
          return revisionPanel;
        }

        if (stack) {
          return Column(
            children: [
              revisionPanel!,
              const SizedBox(height: 18),
              historialPanel!,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: revisionPanel!),
              const SizedBox(width: 20),
              Expanded(child: historialPanel!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionPanel({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required String emptyMessage,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (children.isNotEmpty)
            ...children
          else
            SizedBox(
              height: 220,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: Text(
                    emptyMessage,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryChips(bool isCompact) {
    final List<MapEntry<String, int>> orderedEntries =
        _conteoEstados.entries.toList()..sort(
          (a, b) => _statusPriority(a.key).compareTo(_statusPriority(b.key)),
        );

    if (orderedEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: orderedEntries.map((entry) {
        final Color color = _statusColor(entry.key);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_statusIcon(entry.key), color: color, size: 17),
              const SizedBox(width: 7),
              Text(
                _statusLabel(entry.key),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                entry.value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _statusIcon(String value) {
    final String normalized = value.toUpperCase();

    if (normalized.startsWith('APROB') || normalized.startsWith('ACEPT')) {
      return Icons.check_circle_rounded;
    }

    if (normalized.startsWith('RECHAZ')) {
      return Icons.cancel_rounded;
    }

    if (normalized.contains('REVISION')) {
      return Icons.hourglass_top_rounded;
    }

    if (normalized.contains('ENVI')) {
      return Icons.send_rounded;
    }

    return Icons.description_rounded;
  }

  Future<void> _verDocumento(_Solicitud solicitud) async {
    final String? url = solicitud.urlDocumento;

    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Esta solicitud no tiene documento disponible.'),
          backgroundColor: _warningColor,
        ),
      );
      return;
    }

    DocumentPreviewModal.show(
      context: context,
      documentName: 'Certificado',
      fileUrl: url.trim(),
      expiryDate: null,
      observations: solicitud.descripcion,
    );
  }

  Widget _buildSolicitudCard(_SolicitudDetalle detalle) {
    final _Solicitud solicitud = detalle.solicitud;
    final _TipoSolicitud? tipo = detalle.tipo;
    final Color estadoColor = _statusColor(detalle.estadoActual);
    final bool isExpanded = _expandedSolicitudId == solicitud.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _expandedSolicitudId = isExpanded ? null : solicitud.id;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: isExpanded ? 190 : 70,
                  color: estadoColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: estadoColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                _statusIcon(detalle.estadoActual),
                                color: estadoColor,
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tipo?.nombre ?? 'Sin tipo',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    solicitud.nombreSolicitante.isEmpty
                                        ? 'Sin solicitante'
                                        : solicitud.nombreSolicitante,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),
                            Flexible(
                              flex: 0,
                              child: _buildEstadoTag(detalle.estadoActual),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: Colors.white70,
                            ),
                          ],
                        ),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: -1,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: isExpanded
                              ? Padding(
                                  key: ValueKey('open-${solicitud.id}'),
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _buildInfoBadge(
                                            Icons.calendar_month_rounded,
                                            'Envío: ${_formatOnlyDateColombia(solicitud.fechaEnvio)}',
                                          ),
                                          if (solicitud.idVehiculo != null)
                                            _buildInfoBadge(
                                              Icons.directions_car_rounded,
                                              'Vehículo vinculado',
                                            ),
                                        ],
                                      ),

                                      if (_puedeGestionarSolicitudes) ...[
                                        const SizedBox(height: 12),
                                        _buildSolicitanteBox(solicitud),
                                      ],

                                      const SizedBox(height: 12),

                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _showHistorialDetalle(
                                                    detalle,
                                                  ),
                                              icon: const Icon(
                                                Icons.timeline_rounded,
                                                size: 18,
                                              ),
                                              label: const Text('Historial'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white70,
                                              ),
                                            ),

                                            if (solicitud.urlDocumento !=
                                                    null &&
                                                solicitud.urlDocumento!
                                                    .trim()
                                                    .isNotEmpty)
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _verDocumento(solicitud),
                                                icon: const Icon(
                                                  Icons.visibility_rounded,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Ver documento',
                                                ),
                                              ),

                                            if (_puedeGestionarSolicitudes &&
                                                detalle.estadoActual ==
                                                    'EN_REVISION')
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showResponderSolicitudModal(
                                                      detalle,
                                                    ),
                                                icon: const Icon(
                                                  Icons.reply_rounded,
                                                  size: 18,
                                                ),
                                                label: const Text('Responder'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _accentColor,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('closed'),
                                  height: 0,
                                  width: double.infinity,
                                ),
                        ),
                      ],
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

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitanteBox(_Solicitud solicitud) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos del solicitante',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nombre: ${solicitud.nombreSolicitante.isEmpty ? 'No disponible' : solicitud.nombreSolicitante}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (solicitud.documentoSolicitante.isNotEmpty)
            Text(
              'Documento: ${solicitud.documentoSolicitante}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (solicitud.correoSolicitante.isNotEmpty)
            Text(
              'Correo: ${solicitud.correoSolicitante}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (solicitud.telefonoSolicitante.isNotEmpty)
            Text(
              'Teléfono: ${solicitud.telefonoSolicitante}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Future<void> _showSolicitudCertificadoModal() async {
    final TextEditingController descriptionController = TextEditingController();
    String selectedTipoId = '';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Solicitar certificado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completa el formulario para solicitar un nuevo certificado laboral.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Tipo de certificado
                    Text(
                      'Tipo de certificado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedTipoId.isEmpty
                            ? null
                            : selectedTipoId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          hintText: 'Selecciona un tipo',
                          hintStyle: const TextStyle(color: Colors.white54),
                        ),
                        dropdownColor: _cardColor,
                        style: const TextStyle(color: Colors.white),
                        icon: const Icon(
                          Icons.expand_more,
                          color: Colors.white70,
                        ),
                        items: _buildTiposCertificadoItems(),
                        onChanged: (value) {
                          setState(() => selectedTipoId = value ?? '');
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Descripción
                    Text(
                      'Descripción',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                          hintText: 'Describe brevemente tu solicitud...',
                          hintStyle: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedTipoId.isEmpty
                                ? null
                                : () => _submitSolicitudCertificado(
                                    selectedTipoId,
                                    descriptionController.text,
                                    null,
                                    ctx,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              disabledBackgroundColor: _accentColor.withValues(
                                alpha: 0.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Solicitar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _buildTiposCertificadoItems() {
    return _tiposSolicitud
        .map(
          (tipo) => DropdownMenuItem<String>(
            value: tipo.id.toString(),
            child: Text(tipo.nombre),
          ),
        )
        .toList();
  }

  Future<void> _submitSolicitudCertificado(
    String tipoId,
    String descripcion,
    String? vehiculoId,
    BuildContext ctx,
  ) async {
    Navigator.pop(ctx);

    final int? tipoSolicitudId = int.tryParse(tipoId);
    final int? vehiculoSolicitudId = vehiculoId == null
        ? null
        : int.tryParse(vehiculoId);

    if (tipoSolicitudId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona un tipo de solicitud válido.'),
          backgroundColor: _dangerColor,
        ),
      );
      return;
    }

    final Map<String, dynamic>? nuevaSolicitud =
        await ApiService.crearSolicitud(
          tipoSolicitudId: tipoSolicitudId,
          descripcion: descripcion.trim().isEmpty
              ? 'Solicitud de certificación'
              : descripcion.trim(),
          vehiculoId: vehiculoSolicitudId,
        );

    if (!mounted) return;

    if (nuevaSolicitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo crear la solicitud.'),
          backgroundColor: _dangerColor,
        ),
      );
      return;
    }

    await _loadData();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Solicitud enviada correctamente.'),
        backgroundColor: _successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildEstadoTag(String estado) {
    final Color color = _statusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        _statusLabel(estado),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showHistorialDetalle(_SolicitudDetalle detalle) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<_Historial> ordered =
            List<_Historial>.from(detalle.historial)..sort((a, b) {
              final DateTime aDate =
                  a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
              final DateTime bDate =
                  b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Historial de la solicitud',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: ordered.isEmpty
                      ? const Center(
                          child: Text(
                            'Aún no se registran movimientos.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: ordered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white24, height: 28),
                          itemBuilder: (context, index) {
                            final registro = ordered[index];
                            final color = _statusColor(registro.accion);

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: color.withValues(
                                    alpha: 0.18,
                                  ),
                                  child: Icon(
                                    _statusIcon(registro.accion),
                                    color: color,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _statusLabel(registro.accion),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _formatOnlyDateColombia(registro.fecha),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (registro
                                          .observaciones
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          registro.observaciones,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'No fue posible cargar la informacion.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadData, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Colors.white54,
            size: 48,
          ),
          const SizedBox(height: 14),
          const Text(
            'No hay solicitudes registradas.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando se cree una solicitud de certificacion aparecera aqui.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Map<String, int> _recalcularConteo(List<_SolicitudDetalle> detalles) {
    final Map<String, int> conteo = <String, int>{};
    for (final _SolicitudDetalle detalle in detalles) {
      final String key = detalle.estadoActual;
      conteo.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return conteo;
  }

  void _assignDetalles(List<_SolicitudDetalle> detalles) {
    _detalles = detalles;
    _conteoEstados = _recalcularConteo(detalles);
  }

  List<_SolicitudDetalle> _selectDetallesForRole(
    List<_SolicitudDetalle> todos,
  ) {
    if (todos.isEmpty) return const [];

    if (_viendoPersona) {
      final String personaId = widget.personaUserId!.trim();

      return todos
          .where((detalle) => detalle.solicitud.idUsuario == personaId)
          .toList();
    }

    final String? userId = widget.userId?.trim();

    if (_roleNormalized == 'empresa' ||
        _roleNormalized == 'admin' ||
        _roleNormalized == 'secretaria') {
      return todos;
    }

    if (userId == null || userId.isEmpty) {
      return const [];
    }

    if (_roleNormalized == 'conductor' || _roleNormalized == 'propietario') {
      return todos
          .where((detalle) => detalle.solicitud.idUsuario == userId)
          .toList();
    }

    return const [];
  }

  Future<void> _showResponderSolicitudModal(_SolicitudDetalle detalle) async {
    final TextEditingController observacionesController =
        TextEditingController();

    String estadoSeleccionado = 'ACEPTADA';

    PlatformFile? archivoSeleccionado;
    bool subiendoArchivo = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enviar respuesta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Estado',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      initialValue: estadoSeleccionado,
                      dropdownColor: _cardColor,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ACEPTADA',
                          child: Text('Aceptar'),
                        ),
                        DropdownMenuItem(
                          value: 'RECHAZADA',
                          child: Text('Rechazar'),
                        ),
                      ],
                      onChanged: subiendoArchivo
                          ? null
                          : (value) {
                              setModalState(() {
                                estadoSeleccionado = value ?? 'ACEPTADA';
                              });
                            },
                    ),
                    if (estadoSeleccionado == 'ACEPTADA') ...[
                      const Text(
                        'Certificado PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: subiendoArchivo
                            ? null
                            : () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf'],
                                      withData: true,
                                    );

                                if (result == null || result.files.isEmpty)
                                  return;

                                setModalState(() {
                                  archivoSeleccionado = result.files.first;
                                });
                              },
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          archivoSeleccionado == null
                              ? 'Seleccionar PDF'
                              : archivoSeleccionado!.name,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Observaciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: observacionesController,
                      enabled: !subiendoArchivo,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribe una observación...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: subiendoArchivo
                            ? null
                            : () async {
                                if (estadoSeleccionado == 'ACEPTADA' &&
                                    archivoSeleccionado == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Debes seleccionar un PDF.',
                                      ),
                                      backgroundColor: _warningColor,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  subiendoArchivo = true;
                                });

                                final respuesta =
                                    await ApiService.responderSolicitudConArchivo(
                                      solicitudId: detalle.solicitud.id,
                                      estado: estadoSeleccionado,
                                      observaciones:
                                          observacionesController.text
                                              .trim()
                                              .isEmpty
                                          ? estadoSeleccionado == 'ACEPTADA'
                                                ? 'Solicitud revisada y aprobada correctamente.'
                                                : 'Solicitud rechazada.'
                                          : observacionesController.text.trim(),
                                      archivo: estadoSeleccionado == 'ACEPTADA'
                                          ? archivoSeleccionado
                                          : null,
                                    );

                                if (!mounted) return;

                                if (respuesta == null) {
                                  setModalState(() {
                                    subiendoArchivo = false;
                                  });
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'No se pudo responder la solicitud.',
                                      ),
                                      backgroundColor: _dangerColor,
                                    ),
                                  );
                                  return;
                                }
                                if (mounted) Navigator.pop(ctx);

                                await _loadData();

                                if (!mounted) return;

                                setState(() {
                                  _expandedSolicitudId = null;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });

                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      estadoSeleccionado == 'ACEPTADA'
                                          ? 'Solicitud aceptada correctamente.'
                                          : 'Solicitud rechazada correctamente.',
                                    ),
                                    backgroundColor:
                                        estadoSeleccionado == 'ACEPTADA'
                                        ? _successColor
                                        : _dangerColor,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: estadoSeleccionado == 'ACEPTADA'
                              ? _successColor
                              : _dangerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: subiendoArchivo
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Subiendo archivo...'),
                                ],
                              )
                            : Text(
                                estadoSeleccionado == 'ACEPTADA'
                                    ? 'Aceptar solicitud'
                                    : 'Rechazar solicitud',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatOnlyDateColombia(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }

    final DateTime colombiaDate = value.toUtc().subtract(
      const Duration(hours: 5),
    );

    return _dateOnlyFormat.format(colombiaDate);
  }

  String _normalizeStatus(String value) => value.toUpperCase();

  int _statusPriority(String value) {
    const Map<String, int> order = {
      'ENVIADA': 0,
      'EN_REVISION': 1,
      'RECHAZADA': 2,
      'RECHAZADO': 2,
      'APROBADA': 3,
      'APROBADO': 3,
      'ACEPTADA': 3,
    };
    return order[_normalizeStatus(value)] ?? 9;
  }

  String _statusLabel(String value) {
    final String normalized = value.toUpperCase();
    switch (normalized) {
      case 'ACEPTADA':
      case 'APROBADA':
      case 'APROBADO':
        return 'Aceptada';
      case 'RECHAZADA':
      case 'RECHAZADO':
        return 'Rechazada';
      case 'EN_REVISION':
        return 'En revision';
      case 'ENVIADA':
        return 'Enviada';
      default:
        return normalized[0].toUpperCase() +
            normalized.substring(1).toLowerCase();
    }
  }

  Color _statusColor(String value) {
    final String normalized = value.toUpperCase();
    if (normalized.startsWith('APROB') || normalized.startsWith('ACEPT')) {
      return _successColor;
    }
    if (normalized.startsWith('RECHAZ')) {
      return _dangerColor;
    }
    if (normalized.contains('REVISION')) {
      return _warningColor;
    }
    if (normalized.contains('ENVI')) {
      return _infoColor;
    }
    return _accentColor;
  }
}
