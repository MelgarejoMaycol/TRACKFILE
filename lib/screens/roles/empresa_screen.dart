import 'package:flutter/material.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/services/notificaciones_service.dart';
import 'package:trackfile/utils/browser_url.dart';
import 'package:trackfile/widgets/documents/documentos_screen.dart';
import 'package:trackfile/widgets/inicio.dart';
import 'package:trackfile/widgets/maintenance/mantenimientos.dart';
import 'package:trackfile/widgets/notifications/notifications.dart';
import 'package:trackfile/widgets/requests/requests.dart';
import 'package:trackfile/widgets/search/global_dashboard_search.dart';
import 'package:trackfile/widgets/users/gestion_personas_widget.dart';
import 'package:trackfile/widgets/users/perfil.dart';
import 'package:trackfile/widgets/utils/shimmer_skeleton.dart';
import 'package:trackfile/widgets/vehicles/vehiculos.dart';

import '../../services/notifications/notificaciones_realtime_service.dart';

class _MenuOption {
  final String label;
  final IconData icon;
  final String section;

  const _MenuOption(this.label, this.icon, this.section);
}

class EmpresaScreen extends StatefulWidget {
  const EmpresaScreen({
    super.key,
    this.usuario,
    this.empresa,
    this.initialSection,
  });
  static const route = '/empresa';

  final Map<String, dynamic>? usuario;
  final Map<String, dynamic>? empresa;
  final String? initialSection;

  @override
  State<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  static const Color _primaryColor = Color(0xFF3330BE);
  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);

  static const List<_MenuOption> _bottomMenuOptions = [
    _MenuOption('Inicio', Icons.dashboard_rounded, 'Inicio'),
    _MenuOption('Conductores', Icons.groups_rounded, 'Conductores'),
    _MenuOption('Propietarios', Icons.apartment_rounded, 'Propietarios'),
    _MenuOption('Documentos', Icons.folder_special_rounded, 'Documentos'),
    _MenuOption('Perfil', Icons.person_rounded, 'Perfil'),
  ];

  static const List<_MenuOption> _topMenuOptions = [
    _MenuOption('Mensajes', Icons.chat_rounded, 'Mensajes'),
    _MenuOption('Solicitudes', Icons.assignment_rounded, 'Solicitudes'),
    _MenuOption('Vehículos', Icons.directions_bus_filled_rounded, 'Vehículos'),
    _MenuOption('Mantenimientos', Icons.build_rounded, 'Mantenimientos'),
  ];

  int _selectedBottomIndex = 0;
  int? _selectedTopIndex;
  String _activeSection = 'Inicio';
  int _contentRefreshKey = 0;
  final TextEditingController _pageSearchController = TextEditingController();
  String? _initialInnerSearch;
  late final List<GlobalSearchOption> _globalSearchOptions;
  bool _isLoading = true;
  String? _selectedDocumentsUserId;
  String? _selectedMaintenanceUserId;
  String? _selectedMaintenanceRole;
  String? _selectedMaintenancePersonName;
  String? _selectedCertificadosUserId;
  String? _selectedCertificadosRole;
  String? _selectedCertificadosPersonName;

  String? _selectedDocumentsVehicleId;
  String? _selectedDocumentsVehiclePlate;

  String? _selectedMaintenanceVehicleId;
  String? _selectedMaintenanceVehiclePlate;
  String? _selectedPersonaVehiculoUserId;
  String? _selectedPersonaVehiculoTipo;
  String? _selectedPersonaVehiculoNombre;

  String _companyName = 'Mi empresa';
  String _representative = '';
  String _nit = '--';
  String? _companyLogo;
  String? _companyId;
  String? _companyEmail;
  String? _companyPhone;
  int _notifications = 0;

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection ?? 'Inicio';
    _syncSelectedMenuWithSection(_activeSection);
    NotificacionesRealtimeService.start(onChanged: _loadNotificationsCount);
    _hydrateCompany();
    _finishLoading();
    _loadNotificationsCount();
    _globalSearchOptions = _buildGlobalSearchOptions();
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

  void _finishLoading() {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final count = await NotificacionesService.contador();

      if (!mounted) return;

      setState(() {
        _notifications = count;
      });
    } catch (e) {
      debugPrint('Error cargando contador de notificaciones empresa: $e');
    }
  }

  void _syncSelectedMenuWithSection(String section) {
    final bottomIndex = _bottomMenuOptions.indexWhere(
      (option) => option.section == section,
    );

    final topIndex = _topMenuOptions.indexWhere(
      (option) => option.section == section,
    );

    if (bottomIndex != -1) {
      _selectedBottomIndex = bottomIndex;
      _selectedTopIndex = null;
      return;
    }

    if (topIndex != -1) {
      _selectedBottomIndex = -1;
      _selectedTopIndex = topIndex;
      return;
    }

    _selectedBottomIndex = -1;
    _selectedTopIndex = null;
  }

  void _goToSection(String section) {
    setState(() {
      _contentRefreshKey++;
      _activeSection = section;
      _syncSelectedMenuWithSection(section);
    });

    final slug = switch (section) {
      'Inicio' => 'inicio',
      'Conductores' => 'conductores',
      'Propietarios' => 'propietarios',
      'Documentos' => 'documentos',
      'Perfil' => 'perfil',
      'Mensajes' => 'mensajes',
      'Solicitudes' => 'solicitudes',
      'Vehículos' => 'vehiculos',
      'Mantenimientos' => 'mantenimientos',
      _ => 'inicio',
    };

    updateBrowserUrl('#/dashboard/empresa/$slug');
  }

  void _onBottomMenuTap(int index) {
    setState(() {
      _initialInnerSearch = null;
      _selectedPersonaVehiculoUserId = null;
      _selectedPersonaVehiculoTipo = null;
      _selectedPersonaVehiculoNombre = null;
      _selectedMaintenanceUserId = null;
      _selectedMaintenanceRole = null;
      _selectedMaintenancePersonName = null;
      _selectedCertificadosUserId = null;
      _selectedCertificadosRole = null;
      _selectedCertificadosPersonName = null;
    });

    _goToSection(_bottomMenuOptions[index].section);
  }

  void _onTopMenuTap(int index) {
    setState(() {
      _initialInnerSearch = null;
    });

    _goToSection(_topMenuOptions[index].section);
  }

  void _activateSection(String section) {
    _goToSection(section);
  }

  Widget _buildContentView() {
    switch (_activeSection) {
      case 'Inicio':
        return InicioWidget(
          role: 'Empresa',
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
          initialSearch: _activeSection == 'Conductores'
              ? _initialInnerSearch
              : null,
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
          onVerCertificadosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedCertificadosUserId = usuarioId.toString();
                  _selectedCertificadosRole = tipoPersona;
                  _selectedCertificadosPersonName = nombrePersona;

                  _selectedBottomIndex = -1;
                  _selectedTopIndex = 1;
                  _activeSection = 'Certificaciones';
                });
              },
        );

      case 'Propietarios':
        return GestionPersonasWidget(
          tipoInicial: TipoGestionPersona.propietario,
          permitirCambiarTipo: false,
          nombreEmpresa: _companyName,
          initialSearch: _activeSection == 'Propietarios'
              ? _initialInnerSearch
              : null,
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
          onVerCertificadosPersona:
              ({
                required int usuarioId,
                required String tipoPersona,
                required String nombrePersona,
              }) {
                setState(() {
                  _selectedCertificadosUserId = usuarioId.toString();
                  _selectedCertificadosRole = tipoPersona;
                  _selectedCertificadosPersonName = nombrePersona;

                  _selectedBottomIndex = -1;
                  _selectedTopIndex = 1;
                  _activeSection = 'Certificaciones';
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
        return MensajesWidget(
          role: 'Empresa',
          userId: widget.usuario?['id']?.toString(),
          onNotificationsChanged: _loadNotificationsCount,
        );
      case 'Solicitudes':
        return SolicitudesWidget(
          role: 'Empresa',
          userId: widget.usuario?['id']?.toString(),
          personaUserId: _selectedCertificadosUserId,
          personaRole: _selectedCertificadosRole,
          personaNombre: _selectedCertificadosPersonName,
          initialSearch: _activeSection == 'Solicitudes'
              ? _initialInnerSearch
              : null,
        );
      case 'Vehículos':
        return _buildFleetContent();
      case 'Mantenimientos':
        return _buildMaintenanceContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFleetContent() {
    return VehiculosWidget(
      role: 'Empresa',
      personaUserId: _selectedPersonaVehiculoUserId,
      personaTipo: _selectedPersonaVehiculoTipo,
      personaNombre: _selectedPersonaVehiculoNombre,
      initialSearch: _activeSection == 'Vehículos' ? _initialInnerSearch : null,
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
      initialSearch: _activeSection == 'Mantenimientos'
          ? _initialInnerSearch
          : null,
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
                  InkWell(
                    onTap: () => _activateSection('Perfil'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

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
                      child: _buildPageSearchField(
                        hintText:
                            'Buscar página: documentos, vehículos, mantenimientos...',
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _activateSection('Mensajes'),
                          child: const Icon(
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
          Expanded(
            child: InkWell(
              onTap: () => _activateSection('Perfil'),
              borderRadius: BorderRadius.circular(14),
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
                ],
              ),
            ),
          ),
          Stack(
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

  Widget _buildSearchAndWelcome({required bool isCompact}) {
    final bool isDesktop = !isCompact;

    if (isDesktop) {
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
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Panel corporativo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildPageSearchField(
                        hintText:
                            'Buscar página: documentos, vehículos, mantenimientos...',
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

    return Container(
      color: _primaryColor,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.95,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Panel corporativo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _buildPageSearchField(
                hintText:
                    'Buscar página: documentos, vehículos, mantenimientos...',
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

  @override
  void dispose() {
    _pageSearchController.dispose();
    super.dispose();
  }

  String _normalizeSearch(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  List<GlobalSearchOption> _buildGlobalSearchOptions() {
    return const [
      GlobalSearchOption(
        label: 'Página: Inicio',
        section: 'Inicio',
        searchText: '',
        icon: Icons.dashboard_rounded,
        type: 'Página',
      ),
      GlobalSearchOption(
        label: 'Página: Documentos',
        section: 'Documentos',
        searchText: '',
        icon: Icons.folder_special_rounded,
        type: 'Página',
      ),
      GlobalSearchOption(
        label: 'Página: Vehículos',
        section: 'Vehículos',
        searchText: '',
        icon: Icons.directions_car_filled_rounded,
        type: 'Página',
      ),
      GlobalSearchOption(
        label: 'Página: Mantenimientos',
        section: 'Mantenimientos',
        searchText: '',
        icon: Icons.build_rounded,
        type: 'Página',
      ),
      GlobalSearchOption(
        label: 'Página: Solicitudes',
        section: 'Solicitudes',
        searchText: '',
        icon: Icons.assignment_rounded,
        type: 'Página',
      ),
      GlobalSearchOption(
        label: 'Página: Perfil',
        section: 'Perfil',
        searchText: '',
        icon: Icons.person_rounded,
        type: 'Página',
      ),
      GlobalSearchOption(
        label: 'Página: Mensajes',
        section: 'Mensajes',
        searchText: '',
        icon: Icons.notifications_rounded,
        type: 'Página',
      ),

      GlobalSearchOption(
        label: 'Mantenimiento: Cambio de aceite',
        section: 'Mantenimientos',
        searchText: 'aceite',
        icon: Icons.local_gas_station_rounded,
        type: 'Mantenimiento',
      ),
      GlobalSearchOption(
        label: 'Mantenimiento: Preventivo',
        section: 'Mantenimientos',
        searchText: 'preventivo',
        icon: Icons.build_circle_rounded,
        type: 'Mantenimiento',
      ),
      GlobalSearchOption(
        label: 'Mantenimiento: Correctivo',
        section: 'Mantenimientos',
        searchText: 'correctivo',
        icon: Icons.car_repair_rounded,
        type: 'Mantenimiento',
      ),

      GlobalSearchOption(
        label: 'Solicitud: Certificado laboral',
        section: 'Solicitudes',
        searchText: 'certificado laboral',
        icon: Icons.verified_rounded,
        type: 'Solicitud',
      ),
      GlobalSearchOption(
        label: 'Solicitud: Constancia laboral',
        section: 'Solicitudes',
        searchText: 'constancia laboral',
        icon: Icons.description_rounded,
        type: 'Solicitud',
      ),
    ];
  }

  void _handlePageSearch(String value) {
    final raw = value.trim();
    final query = _normalizeSearch(raw);

    if (query.isEmpty) return;

    String? section;
    String? innerSearch;

    if (query.contains('inicio') || query.contains('home')) {
      section = 'Inicio';
    } else if (query.contains('document')) {
      section = 'Documentos';
    } else if (query.contains('perfil') || query.contains('cuenta')) {
      section = 'Perfil';
    } else if (query.contains('mensaje') ||
        query.contains('notificacion') ||
        query.contains('alerta')) {
      section = 'Mensajes';
    } else if (query.contains('solicitud') ||
        query.contains('certificado') ||
        query.contains('certificacion')) {
      section = 'Solicitudes';
      innerSearch = raw;
    } else if (query.contains('mantenimiento') ||
        query.contains('taller') ||
        query.contains('revision') ||
        query.contains('preventivo') ||
        query.contains('correctivo') ||
        query.contains('aceite')) {
      section = 'Mantenimientos';
      innerSearch = raw;
    } else if (query.contains('vehiculo') ||
        query.contains('vehiculos') ||
        query.contains('carro') ||
        query.contains('placa') ||
        RegExp(r'^[a-zA-Z]{2,4}\d{2,4}$').hasMatch(raw.replaceAll(' ', ''))) {
      section = 'Vehículos';
      innerSearch = raw.replaceAll('placa', '').trim();
    } else if (query.contains('conductor') || query.contains('conductores')) {
      section = 'Conductores';
      innerSearch = raw
          .replaceAll(RegExp(r'conductor(es)?', caseSensitive: false), '')
          .trim();
    } else if (query.contains('propietario') ||
        query.contains('propietarios')) {
      section = 'Propietarios';
      innerSearch = raw
          .replaceAll(RegExp(r'propietario(s)?', caseSensitive: false), '')
          .trim();
    } else if (query.contains('empresa') || query.contains('compania')) {
      section = 'Empresa';
    } else {
      // Si no reconoce página, intenta buscarlo como placa.
      section = 'Vehículos';
      innerSearch = raw;
    }

    setState(() {
      _initialInnerSearch = innerSearch?.trim().isEmpty == true
          ? null
          : innerSearch;
    });

    _pageSearchController.clear();
    _goToSection(section);
  }

  Widget _buildPageSearchField({required String hintText}) {
    return GlobalDashboardSearch(
      controller: _pageSearchController,
      hintText: hintText,
      options: _globalSearchOptions,
      onSubmitted: _handlePageSearch,
      onSelected: (option) {
        setState(() {
          _initialInnerSearch = option.searchText.trim().isEmpty
              ? null
              : option.searchText.trim();
        });

        _pageSearchController.clear();
        _goToSection(option.section);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerDashboardLoadingPage();
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
                          key: ValueKey('$_activeSection-$_contentRefreshKey'),
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
                                key: ValueKey(
                                  '$_activeSection-$_contentRefreshKey',
                                ),
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
