import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PerfilWidget extends StatefulWidget {
  final String? userId;
  final String? jsonPath;
  final String role;

  const PerfilWidget({
    super.key,
    required this.role,
    this.userId,
    this.jsonPath,
  });

  @override
  State<PerfilWidget> createState() => _PerfilWidgetState();
}

class _PerfilUsuario {
  final String id;
  final String nombre;
  final String empresa;
  final String email;
  final String telefono;
  final String imagen;
  final List<_PerfilStat> estadisticas;
  final List<_PerfilDato> datos;
  final List<_CertificacionItem> certificaciones;
  final List<_VehiculoCompacto> vehiculos;

  const _PerfilUsuario({
    required this.id,
    required this.nombre,
    required this.empresa,
    required this.email,
    required this.telefono,
    required this.imagen,
    required this.estadisticas,
    required this.datos,
    required this.certificaciones,
    required this.vehiculos,
  });

  factory _PerfilUsuario.fromMap(Map<String, dynamic> map) {
    final List<_PerfilStat> stats = (map['stats'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_PerfilStat.fromMap)
        .toList();

    final List<_PerfilDato> datos = (map['details'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_PerfilDato.fromMap)
        .toList();

    final List<_CertificacionItem> certificaciones = (map['certifications'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_CertificacionItem.fromMap)
        .toList();

    final List<_VehiculoCompacto> vehiculos = (map['vehicles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_VehiculoCompacto.fromMap)
        .toList();

    return _PerfilUsuario(
      id: map['id']?.toString() ?? '0',
      nombre: map['name']?.toString() ?? 'Usuario sin nombre',
      empresa: map['company']?.toString() ?? 'Sin empresa asignada',
      email: map['email']?.toString() ?? 'sin-correo@empresa.com',
      telefono: map['phone']?.toString() ?? 'Sin teléfono',
      imagen: map['profileImage']?.toString() ?? '',
      estadisticas: stats.isNotEmpty
          ? stats
          : const [
              _PerfilStat(value: '0', label: 'Años\nen la empresa'),
              _PerfilStat(value: '0', label: 'Años\nde experiencia'),
              _PerfilStat(value: '0', label: 'Asignaciones\ncompletadas'),
            ],
      datos: datos.isNotEmpty
          ? datos
          : const [
              _PerfilDato(label: 'Documento', value: 'No registrado'),
              _PerfilDato(label: 'Rol', value: 'Sin rol'),
              _PerfilDato(label: 'Departamento', value: '-'),
              _PerfilDato(label: 'Ciudad base', value: '-'),
            ],
      certificaciones: certificaciones,
      vehiculos: vehiculos,
    );
  }
}

class _PerfilStat {
  final String value;
  final String label;

  const _PerfilStat({required this.value, required this.label});

  factory _PerfilStat.fromMap(Map<String, dynamic> map) {
    return _PerfilStat(
      value: map['value']?.toString() ?? '0',
      label: map['label']?.toString() ?? '',
    );
  }
}

class _PerfilDato {
  final String label;
  final String value;

  const _PerfilDato({required this.label, required this.value});

  factory _PerfilDato.fromMap(Map<String, dynamic> map) {
    return _PerfilDato(
      label: map['label']?.toString() ?? 'Dato',
      value: map['value']?.toString() ?? '-',
    );
  }
}

class _CertificacionItem {
  final String nombre;
  final String estado;
  final String? vencimiento;

  const _CertificacionItem({required this.nombre, required this.estado, this.vencimiento});

  factory _CertificacionItem.fromMap(Map<String, dynamic> map) {
    return _CertificacionItem(
      nombre: map['name']?.toString() ?? 'Sin nombre',
      estado: map['status']?.toString() ?? 'Sin estado',
      vencimiento: map['expires']?.toString(),
    );
  }
}

class _VehiculoCompacto {
  final String placa;
  final String modelo;
  final String estado;

  const _VehiculoCompacto({required this.placa, required this.modelo, required this.estado});

  factory _VehiculoCompacto.fromMap(Map<String, dynamic> map) {
    return _VehiculoCompacto(
      placa: map['plate']?.toString() ?? 'Sin placa',
      modelo: map['model']?.toString() ?? 'Modelo desconocido',
      estado: map['status']?.toString() ?? 'Sin estado',
    );
  }
}

class _ConfiguracionToggle {
  final String id;
  final String titulo;
  final String descripcion;

  const _ConfiguracionToggle({required this.id, required this.titulo, required this.descripcion});
}

class _ConfiguracionOpcion {
  final String titulo;
  final List<String> opciones;

  const _ConfiguracionOpcion({required this.titulo, required this.opciones});
}

class _PerfilConfiguracion {
  final List<_ConfiguracionToggle> toggles;
  final List<_ConfiguracionOpcion> selects;

  const _PerfilConfiguracion({required this.toggles, required this.selects});
}

class _PerfilWidgetState extends State<PerfilWidget> {
  static const Color _primaryColor = Color(0xFF3330BE);
  static const Color _surfaceColor = Color(0xFF141949);
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipColor = Color(0xFF675CFF);

  bool _isLoading = true;
  bool _hasError = false;
  bool _fallback = false;
  _PerfilUsuario? _perfil;
  late Map<String, bool> _toggleValues;
  late Map<String, String> _selectValues;

  @override
  void initState() {
    super.initState();
    _toggleValues = <String, bool>{};
    _selectValues = <String, String>{};
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    final String path = (widget.jsonPath != null && widget.jsonPath!.isNotEmpty)
        ? widget.jsonPath!
        : 'assets/user_profile.json';
    try {
      final String raw = await rootBundle.loadString(path);
      final dynamic decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Formato inesperado');
      }
      final bool ok = _hidratarEstado(decoded, false);
      if (!ok) {
        throw const FormatException('Perfil no disponible');
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      final bool fallbackLoaded = _cargarFallback();
      if (!fallbackLoaded && mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  bool _hidratarEstado(Map<String, dynamic> data, bool fallback) {
    try {
      final List<Map<String, dynamic>> usuarios = (data['users'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (usuarios.isEmpty) {
        return false;
      }
      final String objetivo = widget.userId?.trim().isNotEmpty == true
          ? widget.userId!.trim()
          : usuarios.first['id']?.toString() ?? '0';
      final Map<String, dynamic> usuario = usuarios.firstWhere(
        (item) => item['id']?.toString() == objetivo,
        orElse: () => usuarios.first,
      );
      final _PerfilUsuario perfil = _PerfilUsuario.fromMap(usuario);
      final _PerfilConfiguracion configuracion = _generarConfiguracion(perfil);
      if (!mounted) {
        return true;
      }
      setState(() {
        _perfil = perfil;
        _toggleValues = {
          for (final _ConfiguracionToggle toggle in configuracion.toggles)
            toggle.id: toggle.id != 'modo_descanso',
        };
        _selectValues = {
          for (final _ConfiguracionOpcion select in configuracion.selects)
            select.titulo: select.opciones.first,
        };
        _isLoading = false;
        _hasError = false;
        _fallback = fallback;
      });
      return true;
    } catch (e) {
      debugPrint('Error preparando perfil: $e');
      return false;
    }
  }

  bool _cargarFallback() {
    try {
      const String rawFallback =
          '{"users":[{"id":"1","name":"Alexis Duarte","company":"Transporte Express","profileImage":"","stats":[{"value":"6","label":"Años\\nen la empresa"},{"value":"9","label":"Años\\nde experiencia"},{"value":"420","label":"Asignaciones\\ncompletadas"}],"email":"alexis.duarte@transporte.com","phone":"+57 320 222 1144","details":[{"label":"Documento","value":"1045852213"},{"label":"Rol","value":"Conductor"},{"label":"Departamento","value":"Operaciones"},{"label":"Ciudad base","value":"Bogotá"}],"certifications":[{"name":"Examen médico","status":"Vigente","expires":"04/2026"},{"name":"Curso carga peligrosa","status":"En renovación","expires":"-"}],"vehicles":[{"plate":"UBZ-215","model":"Hino 500 • 2021","status":"Asignado"},{"plate":"THL-941","model":"Sprinter 3500 • 2019","status":"Disponible"}]}]}';
      final Map<String, dynamic> data = json.decode(rawFallback) as Map<String, dynamic>;
      return _hidratarEstado(data, true);
    } catch (e) {
      debugPrint('Error en fallback de perfil: $e');
      return false;
    }
  }

  _PerfilConfiguracion _generarConfiguracion(_PerfilUsuario perfil) {
    final List<_ConfiguracionToggle> toggles = [
      const _ConfiguracionToggle(
        id: 'notificaciones_app',
        titulo: 'Notificaciones en tiempo real',
        descripcion: 'Avisos sobre asignaciones, pagos y alertas administrativas.',
      ),
      const _ConfiguracionToggle(
        id: 'alertas_email',
        titulo: 'Alertas por correo electrónico',
        descripcion: 'Resumen diario de novedades y pendientes.',
      ),
      const _ConfiguracionToggle(
        id: 'compartir_ubicacion',
        titulo: 'Compartir ubicación durante rutas',
        descripcion: 'Permite monitorear recorridos cuando estás en servicio.',
      ),
      const _ConfiguracionToggle(
        id: 'modo_descanso',
        titulo: 'Modo descanso',
        descripcion: 'Silencia notificaciones fuera de turnos programados.',
      ),
    ];

    final List<_ConfiguracionOpcion> selects = [
      const _ConfiguracionOpcion(
        titulo: 'Idioma de la interfaz',
        opciones: ['Español', 'English'],
      ),
      _ConfiguracionOpcion(
        titulo: 'Tema de la aplicación',
        opciones: perfil.empresa.toLowerCase().contains('express')
            ? ['Iluminado', 'Oscuro']
            : ['Automático', 'Oscuro', 'Claro'],
      ),
    ];

    return _PerfilConfiguracion(toggles: toggles, selects: selects);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError || _perfil == null) {
      return _buildError();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 920;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(isCompact ? 16 : 24, 24, isCompact ? 16 : 24, isCompact ? 120 : 80),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isCompact),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      _buildPerfilCard(isCompact),
                      _buildDetallesCard(isCompact),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildConfiguraciones(isCompact),
                  const SizedBox(height: 22),
                  _buildCertificaciones(isCompact),
                  const SizedBox(height: 22),
                  _buildVehiculos(isCompact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: isCompact ? 24 : 28),
            const SizedBox(width: 10),
            Text(
              'Perfil y configuraciones',
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 19 : 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Administra tu información personal, preferencias y credenciales en la plataforma.',
          style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12.5 : 13.5),
        ),
        if (_fallback) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.orangeAccent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mostramos datos de referencia porque no pudimos cargar tu perfil en este momento.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18),
              const SizedBox(width: 8),
              Text(
                perfil.empresa,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerfilCard(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    return Container(
      width: isCompact ? double.infinity : 360,
      padding: EdgeInsets.fromLTRB(isCompact ? 18 : 22, 22, isCompact ? 18 : 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(perfil.imagen),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil.nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      perfil.email,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      perfil.telefono,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: perfil.estadisticas.map(_buildStatChip).toList(),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Actualizar datos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Cambiar contraseña'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesCard(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    return Container(
      width: isCompact ? double.infinity : 640,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.badge_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Información personal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            children: perfil.datos
                .map((dato) => SizedBox(
                      width: isCompact ? double.infinity : 280,
                      child: _buildDatoTile(dato),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguraciones(bool isCompact) {
    final _PerfilConfiguracion configuracion = _generarConfiguracion(_perfil!);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isCompact ? 18 : 22, 22, isCompact ? 18 : 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.settings_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Configuraciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          ...configuracion.toggles.map(_buildToggleTile),
          const Divider(color: Colors.white24, height: 32),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: configuracion.selects
                .map((select) => SizedBox(
                      width: isCompact ? double.infinity : 300,
                      child: _buildSelectTile(select),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificaciones(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    final bool empty = perfil.certificaciones.isEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isCompact ? 18 : 22, 22, isCompact ? 18 : 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Credenciales y certificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          if (empty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Text(
                'Todavía no registras certificaciones en el sistema.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            Column(
              children: perfil.certificaciones
                  .map((cert) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCertTile(cert),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVehiculos(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    final bool empty = perfil.vehiculos.isEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isCompact ? 18 : 22, 22, isCompact ? 18 : 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Vehículos asignados', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          if (empty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Text(
                'Sin vehículos en asignación actual.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: perfil.vehiculos
                  .map((vehiculo) => SizedBox(
                        width: isCompact ? double.infinity : 320,
                        child: _buildVehiculoTile(vehiculo),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String imagen) {
    if (imagen.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: AssetImage(imagen),
        backgroundColor: Colors.white.withValues(alpha: 0.1),
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      child: const Icon(Icons.person, color: Colors.white, size: 32),
    );
  }

  Widget _buildStatChip(_PerfilStat stat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _chipColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _chipColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(stat.value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(stat.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDatoTile(_PerfilDato dato) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dato.label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            dato.value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(_ConfiguracionToggle toggle) {
    final bool value = _toggleValues[toggle.id] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toggle.titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(toggle.descripcion, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              setState(() {
                _toggleValues[toggle.id] = newValue;
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: _accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectTile(_ConfiguracionOpcion select) {
    final String currentValue = _selectValues[select.titulo] ?? select.opciones.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(select.titulo, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: currentValue,
            isExpanded: true,
            items: select.opciones
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectValues[select.titulo] = value;
              });
            },
            dropdownColor: _surfaceColor,
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white54),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertTile(_CertificacionItem cert) {
    final String estado = cert.estado.isEmpty ? 'Sin estado' : cert.estado;
    final String vencimiento = cert.vencimiento?.isNotEmpty == true ? cert.vencimiento! : 'Sin fecha';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentColor.withValues(alpha: 0.2),
              border: Border.all(color: _accentColor.withValues(alpha: 0.45)),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Estado: $estado', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Vence', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Text(vencimiento, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehiculoTile(_VehiculoCompacto vehiculo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentColor.withValues(alpha: 0.2),
              border: Border.all(color: _accentColor.withValues(alpha: 0.45)),
            ),
            child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehiculo.placa, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(vehiculo.modelo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _chipColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _chipColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              vehiculo.estado,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 42),
          const SizedBox(height: 12),
          const Text('No pudimos mostrar el perfil en este momento.', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _cargarPerfil,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
