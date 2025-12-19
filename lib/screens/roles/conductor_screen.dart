import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:frontendproyecto/widgets/inicio.dart';
import 'package:frontendproyecto/widgets/documentos.dart';
import 'package:frontendproyecto/widgets/mensajes.dart';

class _MenuOption {
  final String label;
  final IconData icon;
  final String subtitle;

  const _MenuOption(this.label, this.icon, this.subtitle);
}

class ConductorScreen extends StatefulWidget {
  final String profileImagePath;
  final String companyName;
  final String personName;
  final int notificationsCount;
  final String? userId; // ID del usuario

  const ConductorScreen({
    super.key,
    this.profileImagePath = '',
    this.companyName = 'Empresa Demo',
    this.personName = 'Nombre Persona',
    this.notificationsCount = 0,
    this.userId,
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
  String _activeSection = 'Inicio';
  String _userName = 'Nombre Persona';
  String _userCompany = 'Empresa Demo';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/user_profile.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      Map<String, dynamic>? userData;
      if (jsonData['users'] != null) {
        final List<dynamic> users = jsonData['users'];
        if (widget.userId != null) {
          userData = users.firstWhere(
            (user) => user['id'].toString() == widget.userId,
            orElse: () => users.isNotEmpty ? users[0] : null,
          );
        } else {
          userData = users.isNotEmpty ? users[0] : null;
        }
      }

      if (userData != null) {
        setState(() {
          _userName = userData!['name'] ?? widget.personName;
          _userCompany = userData['company'] ?? widget.companyName;
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = widget.personName;
          _userCompany = widget.companyName;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de usuario: $e');
      setState(() {
        _userName = widget.personName;
        _userCompany = widget.companyName;
        _isLoading = false;
      });
    }
  }

  final List<_MenuOption> _upperMenuOptions = const [
    _MenuOption('Mensajes', Icons.chat_bubble_rounded, 'Conversaciones y alertas'),
    _MenuOption('Pagos', Icons.payments_rounded, 'Cuotas y obligaciones'),
    _MenuOption('Vehículo', Icons.directions_car_filled_rounded, 'Asignaciones activas'),
    _MenuOption('Empresa', Icons.apartment_rounded, 'Gestión corporativa'),
    _MenuOption('Calendario', Icons.calendar_month_rounded, 'Programación diaria'),
  ];

  final List<_MenuOption> _lowerMenuOptions = const [
    _MenuOption('Inicio', Icons.dashboard_rounded, 'Resumen general'),
    _MenuOption('Documentos', Icons.folder_special_rounded, 'RUT, contratos y más'),
    _MenuOption('Certificaciones', Icons.verified_rounded, 'Reporte de cumplimiento'),
    _MenuOption('Perfil', Icons.person_rounded, 'Datos del conductor'),
  ];

  void _onUpperMenuTap(int idx) {
    setState(() {
      _selectedUpperIndex = idx;
      _selectedLowerIndex = null;
      _activeSection = _upperMenuOptions[idx].label;
    });
  }

  void _onLowerMenuTap(int idx) {
    setState(() {
      _selectedLowerIndex = idx;
      _selectedUpperIndex = null;
      _activeSection = _lowerMenuOptions[idx].label;
    });
  }

  void _onBottomTap(String label) {
    setState(() {
      _activeSection = label;
      final int upperIdx = _upperMenuOptions.indexWhere((option) => option.label == label);
      _selectedUpperIndex = upperIdx != -1 ? upperIdx : null;
      final int lowerIdx = _lowerMenuOptions.indexWhere((option) => option.label == label);
      _selectedLowerIndex = lowerIdx != -1 ? lowerIdx : null;
    });
  }

  void _navigateToDocuments() {
    final int docsIndex = _lowerMenuOptions.indexWhere((option) => option.label == 'Documentos');
    if (docsIndex != -1) {
      _onLowerMenuTap(docsIndex);
    }
  }

  void _navigateToPayments() {
    final int paymentsIndex = _upperMenuOptions.indexWhere((option) => option.label == 'Pagos');
    if (paymentsIndex != -1) {
      _onUpperMenuTap(paymentsIndex);
    }
  }

  void _navigateToProfile() {
    final int profileIndex = _lowerMenuOptions.indexWhere((option) => option.label == 'Perfil');
    if (profileIndex != -1) {
      _onLowerMenuTap(profileIndex);
    }
  }

  void _navigateToMessages() {
    final int messagesIndex = _upperMenuOptions.indexWhere((option) => option.label == 'Mensajes');
    if (messagesIndex != -1) {
      _onUpperMenuTap(messagesIndex);
    }
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 216,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _surfaceColor.withValues(alpha: 0.92),
            _primaryColor.withValues(alpha: 0.88),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQuickAccessButton(),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 42, 26, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel de control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _upperMenuOptions.asMap().entries.map((entry) {
                final int index = entry.key;
                final _MenuOption option = entry.value;
                return _buildSidebarButton(
                  option: option,
                  selected: _selectedUpperIndex == index,
                  isLast: index == _upperMenuOptions.length - 1,
                  onTap: () => _onUpperMenuTap(index),
                );
              }).toList(),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
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
    final Color labelColor = selected ? Colors.white : Colors.white.withValues(alpha: 0.86);
    final Color subtitleColor = selected ? Colors.white70 : Colors.white54;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: _accentColor.withValues(alpha: 0.18),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: selected
                  ? _accentColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.32),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 4,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              _accentColor,
                              _accentColor.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                    color: selected ? null : Colors.transparent,
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? _accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                        color: selected
                          ? _accentColor.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(
                    option.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 11,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 26,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accentColor.withValues(alpha: 0.2),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
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

  Widget _buildQuickAccessButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withValues(alpha: 0.18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.86),
                  Colors.white.withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentColor,
                    ),
                    child: const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Accesos directos',
                          style: TextStyle(
                            color: Color(0xFF131760),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Configura tus rutas frecuentes',
                          style: TextStyle(
                            color: Color(0xFF131760),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _surfaceColor.withValues(alpha: 0.8),
                    size: 16,
                  ),
                ],
              ),
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
          color: selected ? _accentColor.withValues(alpha: 0.28) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCompact ? 22 : 24, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: isCompact ? 10 : 11, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 20 : 28, horizontal: isCompact ? 16 : 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: isCompact ? 30 : 36,
            backgroundColor: Colors.white24,
            backgroundImage: widget.profileImagePath.isNotEmpty ? NetworkImage(widget.profileImagePath) : null,
            child: widget.profileImagePath.isEmpty
                ? Icon(Icons.person, size: isCompact ? 32 : 36, color: Colors.white)
                : null,
          ),
          SizedBox(width: isCompact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(_userCompany, style: TextStyle(color: Colors.white70, fontSize: isCompact ? 13 : 14)),
              ],
            ),
          ),
          Stack(
            children: [
              Icon(Icons.notifications_none, color: Colors.white, size: isCompact ? 24 : 28),
              if (widget.notificationsCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 5 : 6),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '${widget.notificationsCount}',
                      style: TextStyle(color: Colors.white, fontSize: isCompact ? 9 : 10),
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
                  'Bienvenido',
                  style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 20, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: isCompact ? 8 : 10),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.14),
                  hintText: 'Buscar',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
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
              label: Text(option.label),
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
          role: 'Conductor',
          jsonPath: 'assets/documents_data.json',
          userProfilePath: 'assets/user_profile.json',
          userId: widget.userId ?? '1',
          onNavigateToDocuments: _navigateToDocuments,
          onNavigateToPayments: _navigateToPayments,
          onNavigateToProfile: _navigateToProfile,
          onNavigateToMessages: _navigateToMessages,
        );
      case 'Documentos':
        return DocumentosWidget(
          role: 'Conductor',
          jsonPath: 'assets/documents_data.json',
        );
      case 'Certificaciones':
        return _buildPlaceholderSection('Certificaciones');
      case 'Perfil':
        return _buildPlaceholderSection('Perfil del conductor');
      case 'Mensajes':
        return MensajesWidget(
          role: 'Conductor',
          userId: widget.userId,
        );
      case 'Pagos':
        return _buildPlaceholderSection('Pagos pendientes');
      case 'Vehículo':
        return _buildPlaceholderSection('Vehículo asignado');
      case 'Empresa':
        return _buildPlaceholderSection('Gestión de empresa');
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
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF3330BE),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 700;

            if (isCompact) {
              return Column(
                children: [
                  _buildHeader(isCompact: true),
                  _buildSearchAndWelcome(isCompact: true),
                  _buildMobileMenuTabs(),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: _buildContentView(),
                    ),
                  ),
                  _buildBottomBar(isCompact: true),
                ],
              );
            }

            return Row(
              children: [
                _buildLeftSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(isCompact: false),
                      _buildSearchAndWelcome(isCompact: false),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                            ),
                          ),
                          child: _buildContentView(),
                        ),
                      ),
                      _buildBottomBar(isCompact: false),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
