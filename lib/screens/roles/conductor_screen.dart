import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trackfile/l10n/app_language.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/services/notificaciones_service.dart';
import 'package:trackfile/services/notifications/notificaciones_realtime_service.dart';
import 'package:trackfile/widgets/chatbot/faq_chatbot.dart';
import 'package:trackfile/widgets/documents/documentos_screen.dart';
import 'package:trackfile/widgets/inicio.dart';
import 'package:trackfile/widgets/maintenance/mantenimientos.dart';
import 'package:trackfile/widgets/notifications/notifications.dart';
import 'package:trackfile/widgets/requests/requests.dart';
import 'package:trackfile/widgets/search/global_dashboard_search.dart';
import 'package:trackfile/widgets/users/empresa.dart';
import 'package:trackfile/widgets/users/perfil.dart';
import 'package:trackfile/widgets/utils/shimmer_skeleton.dart';
import 'package:trackfile/widgets/vehicles/vehiculos.dart';

class _MenuOption {
  final String label;
  final IconData icon;
  final String section;

  const _MenuOption(this.label, this.icon, this.section);
}

class ConductorScreen extends StatefulWidget {
  final String profileImagePath;
  final String companyName;
  final String personName;
  final int notificationsCount;
  final String? userId; // ID del usuario
  final String? initialSection;

  const ConductorScreen({
    super.key,
    this.profileImagePath = '',
    this.companyName = 'Empresa Demo',
    this.personName = 'Nombre Persona',
    this.notificationsCount = 0,
    this.userId,
    this.initialSection,
  });

  @override
  State<ConductorScreen> createState() => _ConductorScreenState();
}

class _ConductorScreenState extends State<ConductorScreen> {
  static const Color _primaryColor = Color(0xFF3330BE);
  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);

  int? _selectedUpperIndex;
  int? _selectedLowerIndex = 0;
  int? _selectedTopIndex;
  String _activeSection = 'Inicio';
  int _contentRefreshKey = 0;
  final TextEditingController _pageSearchController = TextEditingController();
  String? _initialInnerSearch;
  late final List<GlobalSearchOption> _globalSearchOptions;
  String _userName = 'Nombre Persona';
  String _userCompany = 'Empresa Demo';
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;
  String? _userDocument;
  bool _isLoading = true;
  int _inicioRefreshKey = 0;
  int _notificationsCount = 0;
  String? _selectedDocumentsVehicleId;
  String? _selectedDocumentsVehiclePlate;

  String? _selectedMaintenanceVehicleId;
  String? _selectedMaintenanceVehiclePlate;

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection ?? 'Inicio';
    _syncSelectedMenuWithSection(_activeSection);
    NotificacionesRealtimeService.start(onChanged: _loadNotificationsCount);
    _loadUserData();
    _loadNotificationsCount();
    _globalSearchOptions = _buildGlobalSearchOptions();
  }

  @override
  void didUpdateWidget(covariant ConductorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextSection = widget.initialSection ?? 'Inicio';
    final active = nextSection == 'Vehículos' ? 'Vehículo' : nextSection;
    if (active == _activeSection) {
      return;
    }

    setState(() {
      _contentRefreshKey++;
      _activeSection = active;
      _syncSelectedMenuWithSection(active);
      _initialInnerSearch = null;
      _selectedDocumentsVehicleId = null;
      _selectedDocumentsVehiclePlate = null;
      _selectedMaintenanceVehicleId = null;
      _selectedMaintenanceVehiclePlate = null;
    });
  }

  Future<void> _loadUserData() async {
    try {
      // Intentar obtener datos del backend si hay userId
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        await _loadUserDataFromBackend(widget.userId!);
      } else {
        // Usar datos del constructor (datos reales del login)
        setState(() {
          _userName = widget.personName;
          _userCompany = widget.companyName;
          _userEmail = null;
          _userPhone = null;
          _userAddress = null;
          _userDocument = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Usar datos del constructor como fallback (son datos reales del login)
      setState(() {
        _userName = widget.personName;
        _userCompany = widget.companyName;
        _userEmail = null;
        _userPhone = null;
        _userAddress = null;
        _userDocument = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final count = await NotificacionesService.contador();

      if (!mounted) return;

      setState(() {
        _notificationsCount = count;
      });
    } catch (_) {
    }
  }

  Future<void> _loadUserDataFromBackend(String userId) async {
    try {
      final perfilBackend = await ApiService.getMiPerfil();
      final empresaBackend = await ApiService.getMiEmpresa();

      if (!mounted) return;

      if (perfilBackend == null) {
        throw Exception('Perfil vacío');
      }

      final String nombre = perfilBackend['nombre']?.toString() ?? '';
      final String apellido = perfilBackend['apellido']?.toString() ?? '';

      String nombreCompleto = [
        nombre,
        apellido,
      ].where((part) => part.isNotEmpty).join(' ').trim();

      if (nombreCompleto.isEmpty) {
        nombreCompleto = widget.personName;
      }

      String empresaActualizada = widget.companyName;

      final empresa = empresaBackend ?? perfilBackend['empresa'];

      if (empresa is Map<String, dynamic>) {
        empresaActualizada =
            empresa['nombreEmpresa']?.toString() ??
            empresa['nombre']?.toString() ??
            widget.companyName;
      }

      setState(() {
        _userName = nombreCompleto;
        _userCompany = empresaActualizada;
        _userEmail = perfilBackend['correo']?.toString();
        _userPhone = perfilBackend['telefono']?.toString();
        _userAddress = perfilBackend['direccion']?.toString();
        _userDocument = perfilBackend['numeroDocumento']?.toString();
        _isLoading = false;
      });

    } catch (_) {

      if (!mounted) return;

      setState(() {
        _userName = widget.personName;
        _userCompany = widget.companyName;
        _userEmail = null;
        _userPhone = null;
        _userAddress = null;
        _userDocument = null;
        _isLoading = false;
      });
    }
  }

  final List<_MenuOption> _upperMenuOptions = const [
    _MenuOption('Mensajes', Icons.chat_bubble_rounded, 'Mensajes'),
    _MenuOption('Vehículo', Icons.directions_car_filled_rounded, 'Vehículo'),
    _MenuOption('Empresa', Icons.apartment_rounded, 'Empresa'),
    _MenuOption('Mantenimientos', Icons.build_rounded, 'Mantenimientos'),
  ];

  final List<_MenuOption> _lowerMenuOptions = const [
    _MenuOption('Inicio', Icons.dashboard_rounded, 'Inicio'),
    _MenuOption('Documentos', Icons.folder_special_rounded, 'Documentos'),
    _MenuOption('Solicitudes', Icons.verified_rounded, 'Solicitudes'),
    _MenuOption('Perfil', Icons.person_rounded, 'Perfil'),
  ];

  void _syncSelectedMenuWithSection(String section) {
    final upperIndex = _upperMenuOptions.indexWhere(
      (option) => option.section == section || option.label == section,
    );

    final lowerIndex = _lowerMenuOptions.indexWhere(
      (option) => option.section == section || option.label == section,
    );

    if (lowerIndex != -1) {
      _selectedLowerIndex = lowerIndex;
      _selectedUpperIndex = null;
      _selectedTopIndex = null;
      return;
    }

    if (upperIndex != -1) {
      _selectedUpperIndex = upperIndex;
      _selectedTopIndex = upperIndex;
      _selectedLowerIndex = null;
      return;
    }

    _selectedLowerIndex = null;
    _selectedUpperIndex = null;
    _selectedTopIndex = null;
  }

  void _goToSection(String section) {
    final active = section == 'Vehículos' ? 'Vehículo' : section;

    setState(() {
      _contentRefreshKey++;
      _activeSection = active;
      _syncSelectedMenuWithSection(active);
    });

    final slug = switch (section) {
      'Inicio' => 'inicio',
      'Documentos' => 'documentos',
      'Solicitudes' => 'solicitudes',
      'Perfil' => 'perfil',
      'Mensajes' => 'mensajes',
      'Vehículo' || 'Vehículos' => 'vehiculos',
      'Empresa' => 'empresa-info',
      'Mantenimientos' => 'mantenimientos',
      _ => 'inicio',
    };

    context.go('/dashboard/conductor/$slug');
  }

  void _onUpperMenuTap(int idx) {
    _goToSection(_upperMenuOptions[idx].section);
  }

  void _onLowerMenuTap(int idx) {
    _goToSection(_lowerMenuOptions[idx].section);
  }

  void _onBottomTap(String label) {
    _goToSection(label);
  }

  void _navigateToDocuments() {
    _goToSection('Documentos');
  }

  void _navigateToProfile() {
    _goToSection('Perfil');
  }

  void _navigateToMessages() {
    _goToSection('Mensajes');
  }

  void _onTopMenuTap(int index) {
    _goToSection(_upperMenuOptions[index].section);
  }

  void _activateSection(String section) {
    _goToSection(section);
  }

  Widget _buildDesktopTopBar() {
    final double avatarSize = 52;

    Widget avatarContent;
    if (widget.profileImagePath.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.asset(
          widget.profileImagePath,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: _accentColor,
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    } else {
      avatarContent = CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: _accentColor,
        child: Text(
          _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final List<Widget> chips = _upperMenuOptions.asMap().entries.map((entry) {
      final int index = entry.key;
      final _MenuOption option = entry.value;
      final bool selected = _selectedTopIndex == index;
      return ChoiceChip(
        avatar: Icon(
          option.icon,
          size: 13,
          color: selected ? Colors.white : Colors.white70,
        ),
        label: Text(
          context.sectionLabel(option.section),
          style: const TextStyle(fontSize: 11),
        ),
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
                  // Left: Logo + User Info
                  InkWell(
                    onTap: _navigateToProfile,
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
                                _userName,
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
                                _userCompany,
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
                      child: _buildPageSearchField(
                        hintText:
                            context.t('dashboard.searchHint'),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right: Bell icon
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _activateSection('Mensajes'),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
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

  Widget _buildLeftSidebar() {
    return Container(
      width: 200,
      color: _primaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
            child: Text(
              context.t('dashboard.menu'),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _lowerMenuOptions.asMap().entries.map((entry) {
                final int index = entry.key;
                final _MenuOption option = entry.value;
                return _buildSidebarButton(
                  option: option,
                  selected: _selectedLowerIndex == index,
                  isLast: index == _lowerMenuOptions.length - 1,
                  onTap: () => _onLowerMenuTap(index),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton({
    required _MenuOption option,
    required bool selected,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: _accentColor.withValues(alpha: 0.15),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: selected
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? _accentColor.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  color: Colors.white.withValues(alpha: 0.87),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.sectionLabel(option.section),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
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

  Widget _buildBottomBar({required bool isCompact}) {
    return Container(
      height: isCompact ? 60 : 64,
      color: _primaryColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _lowerMenuOptions.asMap().entries.map((entry) {
          final int index = entry.key;
          final _MenuOption option = entry.value;
          final bool selected = _selectedLowerIndex == index;
          return _buildBottomIcon(
            icon: option.icon,
            label: option.label,
            selected: selected,
            isCompact: isCompact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomIcon({
    required IconData icon,
    required String label,
    required bool selected,
    required bool isCompact,
  }) {
    return InkWell(
      onTap: () {
        _onBottomTap(label);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? _accentColor.withValues(alpha: 0.28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCompact ? 22 : 24, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              context.sectionLabel(label),
              style: TextStyle(
                fontSize: isCompact ? 10 : 11,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 20 : 28,
        horizontal: isCompact ? 16 : 20,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _navigateToProfile,
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isCompact ? 30 : 36,
                    backgroundColor: Colors.white24,
                    backgroundImage: widget.profileImagePath.isNotEmpty
                        ? NetworkImage(widget.profileImagePath)
                        : null,
                    child: widget.profileImagePath.isEmpty
                        ? Icon(
                            Icons.person,
                            size: isCompact ? 32 : 36,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  SizedBox(width: isCompact ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isCompact ? 2 : 4),
                        Text(
                          _userCompany,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isCompact ? 13 : 14,
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
                onTap: _navigateToMessages,
                child: Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                  size: isCompact ? 24 : 28,
                ),
              ),
              if (_notificationsCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 5 : 6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_notificationsCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 9 : 10,
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

  Widget _buildSearchAndWelcome({required bool isCompact}) {
    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: isCompact ? 0.92 : 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(-8, 0),
                child: Text(
                  context.t('dashboard.welcome'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 8 : 10),
              _buildPageSearchField(
                hintText:
                    context.t('dashboard.searchHint'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMenuTabs() {
    return Container(
      color: _primaryColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final _MenuOption option = _upperMenuOptions[index];
            final bool selected = _selectedUpperIndex == index;
            return ChoiceChip(
              label: Text(context.sectionLabel(option.section)),
              selected: selected,
              onSelected: (_) {
                _onUpperMenuTap(index);
              },
              selectedColor: _accentColor,
              backgroundColor: _accentColor.withValues(alpha: 0.12),
              showCheckmark: false,
              visualDensity: VisualDensity.comfortable,
              labelStyle: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: selected ? _chipBorderColor : Colors.white24,
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemCount: _upperMenuOptions.length,
        ),
      ),
    );
  }

  Widget _buildContentView() {
    switch (_activeSection) {
      case 'Inicio':
        return InicioWidget(
          key: ValueKey(_inicioRefreshKey),
          role: 'Conductor',
          userId: widget.userId ?? '1',
          onNavigateToDocuments: _navigateToDocuments,
          onNavigateToProfile: _navigateToProfile,
          onNavigateToMessages: _navigateToMessages,
        );
      case 'Documentos':
        return DocumentosScreen(
          role: 'Conductor',
          userId: widget.userId,
          canUpload: false,
          initialVehicleId: _selectedDocumentsVehicleId,
          initialVehiclePlate: _selectedDocumentsVehiclePlate,
        );
      case 'Solicitudes':
        return SolicitudesWidget(
          role: 'Conductor',
          userId: widget.userId ?? '1',
          initialSearch: _activeSection == 'Solicitudes'
              ? _initialInnerSearch
              : null,
        );
      case 'Perfil':
        return PerfilWidget(
          role: 'Conductor',
          userId: widget.userId ?? '1',
          userName: _userName,
          userCompany: _userCompany,
          userEmail: _userEmail,
          userPhone: _userPhone,
          userAddress: _userAddress,
          userDocument: _userDocument,
          onPerfilActualizado: () async {
            await _loadUserData();
            if (!mounted) return;
            setState(() {
              _inicioRefreshKey++;
            });
          },
          onEmpresaActualizada: () async {
            await _loadUserData();
            if (!mounted) return;
            setState(() {
              _inicioRefreshKey++;
            });
          },
        );
      case 'Mensajes':
        return MensajesWidget(
          role: 'Conductor',
          userId: widget.userId,
          onNotificationsChanged: _loadNotificationsCount,
        );
      case 'Vehículo':
        return VehiculosWidget(
          role: 'Conductor',
          ownerId: widget.userId,
          initialSearch: _activeSection == 'Vehículo'
              ? _initialInnerSearch
              : null,
          onVerDocumentosVehiculo:
              ({required int vehiculoId, required String placa}) {
                setState(() {
                  _selectedDocumentsVehicleId = vehiculoId.toString();
                  _selectedDocumentsVehiclePlate = placa;

                  _activeSection = 'Documentos';
                  _selectedLowerIndex = 1;
                  _selectedUpperIndex = null;
                });
              },

          onVerMantenimientosVehiculo:
              ({required int vehiculoId, required String placa}) {
                setState(() {
                  _selectedMaintenanceVehicleId = vehiculoId.toString();
                  _selectedMaintenanceVehiclePlate = placa;

                  _activeSection = 'Mantenimientos';
                  _selectedUpperIndex = 3;
                  _selectedLowerIndex = null;
                });
              },
        );
      case 'Empresa':
        return EmpresaWidget(
          userId: widget.userId,
          jsonPath: 'assets/companies_data.json',
        );
      case 'Mantenimientos':
        return MantenimientosWidget(
          role: 'Conductor',
          userId: widget.userId ?? '1',
          vehiculoId: _selectedMaintenanceVehicleId,
          vehiculoPlaca: _selectedMaintenanceVehiclePlate,
          initialSearch: _activeSection == 'Mantenimientos'
              ? _initialInnerSearch
              : null,
        );
      case 'Calendario':
        return _buildPlaceholderSection('Calendario de actividades');
      default:
        return _buildPlaceholderSection(_activeSection);
    }
  }

  Widget _buildPlaceholderSection(String label) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(fontSize: 20, color: Colors.white),
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
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 860;
                final double radius = isCompact ? 24 : 28;

                if (isCompact) {
                  return Column(
                    children: [
                      _buildHeader(isCompact: true),
                      _buildSearchAndWelcome(isCompact: true),
                      _buildMobileMenuTabs(),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(radius),
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(
                              '$_activeSection-$_contentRefreshKey',
                            ),
                            child: _buildContentView(),
                          ),
                        ),
                      ),
                      _buildBottomBar(isCompact: true),
                    ],
                  );
                }

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
                              decoration: BoxDecoration(
                                color: _surfaceColor,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(radius),
                                ),
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(
                                  '$_activeSection-$_contentRefreshKey',
                                ),
                                child: _buildContentView(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          FaqChatbot(role: 'Conductor', userId: widget.userId),
        ],
      ),
    );
  }
}
