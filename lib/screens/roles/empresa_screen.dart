import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/widgets/certificados/certificaciones.dart';
import 'package:trackfile/widgets/documents/documentos_screen.dart';
import 'package:trackfile/widgets/inicio.dart';
import 'package:trackfile/widgets/mantenimientos/mantenimientos.dart';
import 'package:trackfile/widgets/users/gestion_personas_widget.dart';
import 'package:trackfile/widgets/users/perfil.dart';
import 'package:trackfile/widgets/vehiculos/vehiculos.dart';

class _MenuOption {
  final String label;
  final IconData icon;
  final String section;

  const _MenuOption(this.label, this.icon, this.section);
}

class EmpresaScreen extends StatefulWidget {
  const EmpresaScreen({super.key, this.usuario, this.empresa});
  static const route = '/empresa';

  final Map<String, dynamic>? usuario;
  final Map<String, dynamic>? empresa;

  @override
  State<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  static const Color _primaryColor = Color(0xFF3330BE);
  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);

  static const String _dashboardAsset = 'assets/empresa_dashboard.json';
  static const String _companyProfileAsset = 'assets/companies_data.json';

  static const List<_MenuOption> _bottomMenuOptions = [
    _MenuOption('Inicio', Icons.dashboard_rounded, 'Inicio'),
    _MenuOption('Conductores', Icons.groups_rounded, 'Conductores'),
    _MenuOption('Propietarios', Icons.apartment_rounded, 'Propietarios'),
    _MenuOption('Documentos', Icons.folder_special_rounded, 'Documentos'),
    _MenuOption('Perfil', Icons.person_rounded, 'Perfil'),
  ];

  static const List<_MenuOption> _topMenuOptions = [
    _MenuOption('Mensajes', Icons.chat_rounded, 'Mensajes'),
    _MenuOption('Certificaciones', Icons.verified_rounded, 'Certificaciones'),
    _MenuOption('Vehículos', Icons.directions_bus_filled_rounded, 'Vehículos'),
    _MenuOption('Mantenimientos', Icons.build_rounded, 'Mantenimientos'),
  ];

  int _selectedBottomIndex = 0;
  int? _selectedTopIndex;
  String _activeSection = 'Inicio';
  bool _isLoading = true;
  String? _selectedDocumentsUserId;
  String? _selectedMaintenanceUserId;
  String? _selectedMaintenanceRole;
  String? _selectedMaintenancePersonName;

  String? _selectedDocumentsVehicleId;
  String? _selectedDocumentsVehiclePlate;

  String? _selectedMaintenanceVehicleId;
  String? _selectedMaintenanceVehiclePlate;
  String? _selectedPersonaVehiculoUserId;
  String? _selectedPersonaVehiculoTipo;
  String? _selectedPersonaVehiculoNombre;

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _fleetVehicles = [];
  List<Map<String, dynamic>> _alerts = [];

  String _companyName = 'Mi empresa';
  String _representative = '';
  String _nit = '--';
  String? _companyLogo;
  String? _companyId;
  String? _companyEmail;
  String? _companyPhone;
  String? _companyDescription;
  String? _companyVision;
  String? _companyMission;
  int _notifications = 0;

  @override
  void initState() {
    super.initState();
    _hydrateCompany();
    _loadDashboard();
  }

  void _hydrateCompany() {
    final Map<String, dynamic>? rawCompany =
        _asMap(widget.empresa) ?? _asMap(widget.usuario?['empresa']);
    final Map<String, dynamic>? rawUser = _asMap(widget.usuario);

    if (rawCompany != null) {
      _companyName =
          rawCompany['nombreEmpresa']?.toString() ??
          rawCompany['nombre']?.toString() ??
          _companyName;
      _representative =
          rawCompany['representanteLegal']?.toString() ?? _representative;
      _nit = rawCompany['nit']?.toString() ?? _nit;
      _companyLogo = rawCompany['logo']?.toString();
      _companyId =
          rawCompany['id_empresa']?.toString() ?? rawCompany['id']?.toString();
      _companyEmail =
          rawCompany['contacto_email']?.toString() ??
          rawCompany['email']?.toString() ??
          _companyEmail;
      _companyPhone =
          rawCompany['contacto_telefono']?.toString() ??
          rawCompany['telefono']?.toString() ??
          rawCompany['celular']?.toString() ??
          _companyPhone;
      _companyDescription =
          rawCompany['descripcion']?.toString() ?? _companyDescription;
      _companyVision = rawCompany['vision']?.toString() ?? _companyVision;
      _companyMission = rawCompany['mision']?.toString() ?? _companyMission;
    }

    if (_representative.isEmpty && rawUser != null) {
      final String nombre = rawUser['nombre']?.toString() ?? '';
      final String apellido = rawUser['apellido']?.toString() ?? '';
      final String combined = [
        nombre,
        apellido,
      ].where((part) => part.isNotEmpty).join(' ').trim();
      if (combined.isNotEmpty) {
        _representative = combined;
      }
    }
  }

  Future<void> _refrescarEmpresaDesdeBackend() async {
    final empresa = await ApiService.getMiEmpresa();

    if (!mounted || empresa == null) return;

    setState(() {
      _companyName =
          empresa['nombreEmpresa']?.toString() ??
          empresa['nombre']?.toString() ??
          _companyName;

      _companyPhone =
          empresa['telefono']?.toString() ??
          empresa['celular']?.toString() ??
          _companyPhone;

      _companyEmail =
          empresa['correo']?.toString() ??
          empresa['email']?.toString() ??
          _companyEmail;

      _nit = empresa['nit']?.toString() ?? _nit;

      _companyId =
          empresa['id']?.toString() ??
          empresa['idEmpresa']?.toString() ??
          empresa['id_empresa']?.toString() ??
          _companyId;
    });

    await _loadDashboard();
  }

  Map<String, dynamic>? _asMap(dynamic source) {
    if (source == null) return null;
    if (source is Map<String, dynamic>) {
      return Map<String, dynamic>.from(source);
    }
    if (source is Map) {
      return source.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Future<void> _loadDashboard() async {
    try {
      final String raw = await rootBundle.loadString(_dashboardAsset);
      final Map<String, dynamic> data =
          json.decode(raw) as Map<String, dynamic>;

      final Map<String, dynamic> summary =
          data['summary'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};

      final List<Map<String, dynamic>> documents =
          (data['documents'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((entry) {
                final DateTime? expiry = DateTime.tryParse(
                  entry['expiryDate']?.toString() ?? '',
                );
                final DateTime? payment = DateTime.tryParse(
                  entry['paymentDate']?.toString() ?? '',
                );
                return {
                  'name': entry['name']?.toString() ?? 'Documento',
                  'category': entry['category']?.toString() ?? '',
                  'responsible': entry['responsible']?.toString() ?? '',
                  'status': entry['status']?.toString() ?? '',
                  'paymentDate': payment,
                  'expiryDate': expiry,
                };
              })
              .toList();

      final List<Map<String, dynamic>> vehicles =
          (data['vehicles'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((entry) {
                final DateTime? nextExpiry = DateTime.tryParse(
                  entry['nextExpiry']?.toString() ?? '',
                );
                final DateTime? lastService = DateTime.tryParse(
                  entry['lastService']?.toString() ?? '',
                );
                final num? utilizationRaw = entry['utilization'] as num?;
                return {
                  'plate': entry['plate']?.toString() ?? '',
                  'model': entry['model']?.toString() ?? '',
                  'driver': entry['driver']?.toString() ?? '',
                  'status': entry['status']?.toString() ?? '',
                  'nextExpiry': nextExpiry,
                  'lastService': lastService,
                  'utilization': utilizationRaw?.toDouble(),
                };
              })
              .toList();

      final List<Map<String, dynamic>> alerts =
          (data['alerts'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(
                (entry) => {
                  'title': entry['title']?.toString() ?? 'Alerta',
                  'message': entry['message']?.toString() ?? '',
                  'severity': entry['severity']?.toString() ?? 'medium',
                  'tag': entry['tag']?.toString() ?? 'General',
                },
              )
              .toList();

      final int badgeFromAlerts = alerts.where((alert) {
        final String severity =
            alert['severity']?.toString().toLowerCase() ?? '';
        return severity == 'high' || severity == 'alta';
      }).length;
      final int badgeFromSummary =
          (summary['alertsHigh'] as num?)?.toInt() ?? 0;
      final int notifications = badgeFromAlerts > badgeFromSummary
          ? badgeFromAlerts
          : badgeFromSummary;

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _documents = documents;
        _fleetVehicles = vehicles;
        _alerts = alerts;
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando dashboard empresa: $e');
      if (!mounted) return;
      setState(() {
        _summary = {};
        _documents = [];
        _fleetVehicles = [];
        _alerts = [];
        _notifications = 0;
        _isLoading = false;
      });
    }
  }

  void _onBottomMenuTap(int index) {
    setState(() {
      _selectedBottomIndex = index;
      _selectedTopIndex = null;
      _activeSection = _bottomMenuOptions[index].section;

      if (_activeSection == 'Documentos') {
        _selectedDocumentsUserId = null;
        _selectedDocumentsVehicleId = null;
        _selectedDocumentsVehiclePlate = null;
      }
    });
  }

  void _onTopMenuTap(int index) {
    setState(() {
      _selectedTopIndex = index;
      _selectedBottomIndex = -1;
      _activeSection = _topMenuOptions[index].section;
      if (_topMenuOptions[index].section == 'Vehículos') {
        _selectedPersonaVehiculoUserId = null;
        _selectedPersonaVehiculoTipo = null;
        _selectedPersonaVehiculoNombre = null;
      }
      if (_topMenuOptions[index].section == 'Mantenimientos') {
        _selectedMaintenanceUserId = null;
        _selectedMaintenanceRole = null;
        _selectedMaintenancePersonName = null;
        _selectedMaintenanceVehicleId = null;
        _selectedMaintenanceVehiclePlate = null;
      }
    });
  }

  void _activateSection(String section) {
    if (_bottomMenuOptions.any((option) => option.section == section)) {
      final int index = _bottomMenuOptions.indexWhere(
        (option) => option.section == section,
      );
      _onBottomMenuTap(index);
      return;
    }

    if (_topMenuOptions.any((option) => option.section == section)) {
      final int index = _topMenuOptions.indexWhere(
        (option) => option.section == section,
      );
      _onTopMenuTap(index);
      return;
    }

    setState(() => _activeSection = section);
  }

  Widget _buildContentView() {
    switch (_activeSection) {
      case 'Inicio':
        return InicioWidget(
          role: 'Empresa',
          jsonPath: _dashboardAsset,
          userProfilePath: _companyProfileAsset,
          userId: _companyId ?? widget.usuario?['id']?.toString(),
          onNavigateToDocuments: () => _activateSection('Documentos'),
          onNavigateToMessages: () => _activateSection('Mensajes'),
          onNavigateToProfile: () => _activateSection('Perfil'),
        );
      case 'Conductores':
        return GestionPersonasWidget(
          tipoInicial: TipoGestionPersona.conductor,
          permitirCambiarTipo: false,
          nombreEmpresa: _companyName,
          onVerDocumentosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedDocumentsUserId = usuarioId.toString();
                  _selectedBottomIndex = 3;
                  _selectedTopIndex = null;
                  _activeSection = 'Documentos';
                });
              },
          onVerMantenimientosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedMaintenanceUserId = usuarioId.toString();
                  _selectedMaintenanceRole = tipoPersona;
                  _selectedMaintenancePersonName = nombrePersona;
                  _selectedBottomIndex = -1;
                  _selectedTopIndex = 3;
                  _activeSection = 'Mantenimientos';
                });
              },
          onVerVehiculosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedPersonaVehiculoUserId = usuarioId.toString();
                  _selectedPersonaVehiculoTipo = tipoPersona;
                  _selectedPersonaVehiculoNombre = nombrePersona;

                  _selectedBottomIndex = -1;
                  _selectedTopIndex = 2;
                  _activeSection = 'Vehículos';
                });
              },
        );

      case 'Propietarios':
        return GestionPersonasWidget(
          tipoInicial: TipoGestionPersona.propietario,
          permitirCambiarTipo: false,
          nombreEmpresa: _companyName,
          onVerDocumentosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedDocumentsUserId = usuarioId.toString();
                  _selectedBottomIndex = 3;
                  _selectedTopIndex = null;
                  _activeSection = 'Documentos';
                });
              },
          onVerMantenimientosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedMaintenanceUserId = usuarioId.toString();
                  _selectedMaintenanceRole = tipoPersona;
                  _selectedMaintenancePersonName = nombrePersona;
                  _selectedBottomIndex = -1;
                  _selectedTopIndex = 3;
                  _activeSection = 'Mantenimientos';
                });
              },
          onVerVehiculosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedPersonaVehiculoUserId = usuarioId.toString();
                  _selectedPersonaVehiculoTipo = tipoPersona;
                  _selectedPersonaVehiculoNombre = nombrePersona;

                  _selectedBottomIndex = -1;
                  _selectedTopIndex = 2;
                  _activeSection = 'Vehículos';
                });
              },
        );
      case 'Documentos':
        return DocumentosScreen(
          role: 'Empresa',
          userId: _selectedDocumentsUserId,
          canUpload:
              _selectedDocumentsUserId == null &&
              _selectedDocumentsVehicleId == null,
          initialVehicleId: _selectedDocumentsVehicleId,
          initialVehiclePlate: _selectedDocumentsVehiclePlate,
        );
      case 'Perfil':
        return PerfilWidget(
          role: 'EMPRESA',
          userId: widget.usuario?['id']?.toString(),
          userName: _representative,
          userCompany: _companyName,
          userEmail: _companyEmail,
          userPhone: _companyPhone,
          userAddress: widget.empresa?['direccion']?.toString(),
          userDocument: _nit,
          onEmpresaActualizada: _refrescarEmpresaDesdeBackend,
        );
      case 'Mensajes':
        return _buildMessagesContent();
      case 'Certificaciones':
        return CertificacionesWidget(
          role: 'Empresa',
          userId: widget.usuario?['id']?.toString(),
        );
      case 'Vehículos':
        return _buildFleetContent();
      case 'Mantenimientos':
        return _buildMaintenanceContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessagesContent() {
    if (_alerts.isEmpty) {
      return _buildEmptyState(
        'Mensajes corporativos',
        'No hay mensajes recientes para la empresa.',
      );
    }

    final List<Map<String, dynamic>>
    ordered = List<Map<String, dynamic>>.from(_alerts)
      ..sort((a, b) {
        final String severityA = a['severity']?.toString().toLowerCase() ?? '';
        final String severityB = b['severity']?.toString().toLowerCase() ?? '';
        return _severityRank(severityB).compareTo(_severityRank(severityA));
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mensajes corporativos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...ordered.map(_buildMessageCard),
        ],
      ),
    );
  }

  Widget _buildFleetContent() {
    return VehiculosWidget(
      role: 'Empresa',
      personaUserId: _selectedPersonaVehiculoUserId,
      personaTipo: _selectedPersonaVehiculoTipo,
      personaNombre: _selectedPersonaVehiculoNombre,
      jsonPath: 'assets/vehicles_data.json',
      onVerDocumentosVehiculo:
          ({required int vehiculoId, required String placa}) {
            setState(() {
              _selectedDocumentsUserId = null;
              _selectedDocumentsVehicleId = vehiculoId.toString();
              _selectedDocumentsVehiclePlate = placa;

              _selectedBottomIndex = 3;
              _selectedTopIndex = null;
              _activeSection = 'Documentos';
            });
          },
      onVerMantenimientosVehiculo:
          ({required int vehiculoId, required String placa}) {
            setState(() {
              _selectedMaintenanceUserId = null;
              _selectedMaintenanceRole = null;
              _selectedMaintenancePersonName = null;

              _selectedMaintenanceVehicleId = vehiculoId.toString();
              _selectedMaintenanceVehiclePlate = placa;

              _selectedBottomIndex = -1;
              _selectedTopIndex = 3;
              _activeSection = 'Mantenimientos';
            });
          },
    );
  }

  Widget _buildMaintenanceContent() {
    return MantenimientosWidget(
      role: 'Empresa',
      userId: widget.usuario?['id']?.toString(),
      personaUserId: _selectedMaintenanceUserId,
      personaRole: _selectedMaintenanceRole,
      personaNombre: _selectedMaintenancePersonName,
      vehiculoId: _selectedMaintenanceVehicleId,
      vehiculoPlaca: _selectedMaintenanceVehiclePlate,
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    final double avatarSize = 52;

    Widget avatarContent;
    if (_companyLogo != null && _companyLogo!.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.asset(
          _companyLogo!,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLogoFallback(false),
        ),
      );
    } else {
      avatarContent = _buildLogoFallback(false);
    }

    final String representativeLabel = _representative.isNotEmpty
        ? _representative
        : 'Sin asignar';

    final List<Widget> chips = _topMenuOptions.asMap().entries.map((entry) {
      final int index = entry.key;
      final _MenuOption option = entry.value;
      final bool selected = _selectedTopIndex == index;
      return ChoiceChip(
        avatar: Icon(
          option.icon,
          size: 13,
          color: selected ? Colors.white : Colors.white70,
        ),
        label: Text(option.label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => _onTopMenuTap(index),
        selectedColor: _accentColor,
        backgroundColor: _accentColor.withValues(alpha: 0.12),
        showCheckmark: false,
        side: BorderSide(color: selected ? _chipBorderColor : Colors.white24),
        labelStyle: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      );
    }).toList();

    return Column(
      children: [
        Container(
          color: _primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Logo + Company Info
                  CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundColor: Colors.white24,
                    child: avatarContent,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Rep: $representativeLabel | NIT: $_nit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  // Center: Search bar
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.14),
                          hintText: 'Buscar por documento, propietario o placa',
                          hintStyle: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right: Bell icon with notification
                  Align(
                    alignment: Alignment.centerRight,
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _activateSection('Mensajes'),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        if (_notifications > 0)
                          Positioned(
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_notifications',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom row: Menu buttons
        Container(
          color: _primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: chips.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: e.value,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    final double avatarSize = isCompact ? 48 : 56;
    Widget avatarContent;
    if (_companyLogo != null && _companyLogo!.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.asset(
          _companyLogo!,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLogoFallback(isCompact),
        ),
      );
    } else {
      avatarContent = _buildLogoFallback(isCompact);
    }

    final String representativeLabel = _representative.isNotEmpty
        ? _representative
        : 'Sin asignar';

    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 8 : 10,
        horizontal: isCompact ? 12 : 20,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: Colors.white24,
            child: avatarContent,
          ),
          SizedBox(width: isCompact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Representante: $representativeLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isCompact ? 10 : 11,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'NIT: $_nit',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: isCompact ? 9 : 10,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _activateSection('Mensajes'),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: isCompact ? 20 : 24,
                  ),
                ),
                if (_notifications > 0)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_notifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoFallback(bool isCompact) {
    final String letter = _companyName.trim().isNotEmpty
        ? _companyName.trim()[0].toUpperCase()
        : 'E';
    return Text(
      letter,
      style: TextStyle(
        color: Colors.white,
        fontSize: isCompact ? 24 : 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildQuickBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndWelcome({required bool isCompact}) {
    final DateTime now = DateTime.now();
    final int fleetTotal =
        (_summary['fleetSize'] as num?)?.toInt() ?? _fleetVehicles.length;
    final int expiredComputed = _documents
        .where(
          (doc) => (doc['expiryDate'] as DateTime?)?.isBefore(now) ?? false,
        )
        .length;
    final int docsExpired = expiredComputed > 0
        ? expiredComputed
        : (_summary['documentsExpired'] as num?)?.toInt() ??
              (_summary['documentsPending'] as num?)?.toInt() ??
              0;

    final bool isDesktop = !isCompact;

    if (isDesktop) {
      // Desktop layout: two-column, larger search input and nicer spacing
      return Container(
        color: _primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left column: title and quick badges
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panel corporativo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildQuickBadge(
                              Icons.directions_bus_rounded,
                              '$fleetTotal vehículos',
                            ),
                            _buildQuickBadge(
                              Icons.insert_drive_file_rounded,
                              '$docsExpired vencidos',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right column: big search box
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  hintText:
                                      'Buscar por documento, propietario o placa',
                                  hintStyle: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildQuickBadge(
                                    Icons.directions_bus_rounded,
                                    '$fleetTotal vehículos',
                                  ),
                                  _buildQuickBadge(
                                    Icons.insert_drive_file_rounded,
                                    '$docsExpired vencidos',
                                  ),
                                ],
                              ),
                            ],
                          ),
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

    // Mobile / compact layout: responsive stacked layout
    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.95,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel corporativo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.14),
                  hintText: 'Buscar por documento, propietario o placa',
                  hintStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildQuickBadge(
                    Icons.directions_bus_rounded,
                    '$fleetTotal vehículos',
                  ),
                  _buildQuickBadge(
                    Icons.insert_drive_file_rounded,
                    '$docsExpired vencidos',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopMenuBar({required bool isCompact}) {
    if (_topMenuOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final double iconSize = isCompact ? 14 : 16;
    final double fontSize = isCompact ? 12 : 13;
    final double spacing = isCompact ? 8 : 10;

    final List<Widget> chips = _topMenuOptions.asMap().entries.map((entry) {
      final int index = entry.key;
      final _MenuOption option = entry.value;
      final bool selected = _selectedTopIndex == index;
      return ChoiceChip(
        avatar: Icon(
          option.icon,
          size: iconSize,
          color: selected ? Colors.white : Colors.white70,
        ),
        label: Text(option.label, style: TextStyle(fontSize: fontSize)),
        selected: selected,
        onSelected: (_) => _onTopMenuTap(index),
        selectedColor: _accentColor,
        backgroundColor: _accentColor.withValues(alpha: 0.12),
        showCheckmark: false,
        side: BorderSide(color: selected ? _chipBorderColor : Colors.white24),
        labelStyle: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 10,
          vertical: isCompact ? 6 : 8,
        ),
      );
    }).toList();

    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.96,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...chips.asMap().entries.map((e) {
                  return Padding(
                    padding: EdgeInsets.only(right: spacing),
                    child: e.value,
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 200,
      color: _primaryColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Menú',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _bottomMenuOptions.asMap().entries.map((entry) {
                final int index = entry.key;
                final _MenuOption option = entry.value;
                final bool selected = _selectedBottomIndex == index;
                return _buildLeftNavItem(option, index, selected);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftNavItem(_MenuOption option, int index, bool selected) {
    return InkWell(
      onTap: () => _onBottomMenuTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _accentColor.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: _accentColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(option.icon, size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({required bool isCompact}) {
    final double height = isCompact ? 58 : 64;
    return Container(
      height: height,
      color: _primaryColor,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _bottomMenuOptions.asMap().entries.map((entry) {
            final int index = entry.key;
            final _MenuOption option = entry.value;
            final bool selected = _selectedBottomIndex == index;
            return _buildBottomNavItem(option, index, selected, isCompact);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    _MenuOption option,
    int index,
    bool selected,
    bool isCompact,
  ) {
    return InkWell(
      onTap: () => _onBottomMenuTap(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? _accentColor.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, size: isCompact ? 20 : 22, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 9 : 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> alert) {
    final String title = alert['title']?.toString() ?? 'Mensaje';
    final String message = alert['message']?.toString() ?? '';
    final String severity =
        alert['severity']?.toString().toLowerCase() ?? 'medium';
    final String tag = alert['tag']?.toString() ?? 'General';
    final Color borderColor = _alertSeverityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mark_email_unread_rounded,
                color: borderColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                tag,
                style: TextStyle(
                  color: borderColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _alertSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'alta':
        return const Color(0xFFE66B6B);
      case 'medium':
      case 'media':
        return const Color(0xFFEFB549);
      case 'low':
      case 'baja':
        return const Color(0xFF16C79A);
      default:
        return Colors.white70;
    }
  }

  int _severityRank(String severity) {
    switch (severity) {
      case 'high':
      case 'alta':
        return 3;
      case 'medium':
      case 'media':
        return 2;
      case 'low':
      case 'baja':
        return 1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _surfaceColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 860;
            final double radius = isCompact ? 24 : 28;
            if (isCompact) {
              // Layout móvil: menú superior + contenido + menú inferior
              return Column(
                children: [
                  _buildHeader(isCompact: isCompact),
                  _buildSearchAndWelcome(isCompact: isCompact),
                  _buildTopMenuBar(isCompact: isCompact),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.topLeft,
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(radius),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey<String>(_activeSection),
                          child: _buildContentView(),
                        ),
                      ),
                    ),
                  ),
                  _buildBottomBar(isCompact: isCompact),
                ],
              );
            } else {
              // Layout desktop: menú izquierdo + topbar + contenido
              return Column(
                children: [
                  _buildDesktopTopBar(),
                  Expanded(
                    child: Row(
                      children: [
                        _buildLeftSidebar(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: double.infinity,
                            alignment: Alignment.topLeft,
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(radius),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: KeyedSubtree(
                                key: ValueKey<String>(_activeSection),
                                child: _buildContentView(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
