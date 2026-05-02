import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:frontendproyecto/utils/api_config.dart';
import 'package:frontendproyecto/widgets/inicio.dart';
import 'package:frontendproyecto/widgets/documents/documentos_screen.dart';
import 'package:frontendproyecto/widgets/vehiculos/vehiculos.dart';
import 'package:frontendproyecto/widgets/users/empresa.dart';
import 'package:frontendproyecto/widgets/certificados/certificaciones.dart';
import 'package:frontendproyecto/widgets/mantenimientos/mantenimientos.dart';
import 'package:frontendproyecto/widgets/users/perfil.dart';

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
  int? _selectedTopIndex;
  String _activeSection = 'Inicio';
  String _userName = 'Nombre Persona';
  String _userCompany = 'Empresa Demo';
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;
  String? _userDocument;
  bool _isLoading = true;
  String _baseUrl = ApiConfig.fallbackBaseUrl();
  final List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _initBaseUrl();
    _loadUserData();
  }

  Future<void> _initBaseUrl() async {
    final resolved = await ApiConfig.loadBaseUrl();
    if (!mounted) return;
    setState(() => _baseUrl = resolved);
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
    } catch (e) {
      debugPrint('Error cargando datos de conductor: $e');
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

  Future<void> _loadUserDataFromBackend(String userId) async {
    try {
      final uri = ApiConfig.resolve(_baseUrl, '/api/usuarios/$userId');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = json.decode(response.body) as Map<String, dynamic>;
        
        setState(() {
          // Nombre del usuario
          final String nombre = userData['nombre']?.toString() ?? '';
          final String apellido = userData['apellido']?.toString() ?? '';
          _userName = [nombre, apellido]
              .where((part) => part.isNotEmpty)
              .join(' ')
              .trim();
          if (_userName.isEmpty) {
            _userName = widget.personName;
          }

          // Empresa del usuario
          final dynamic rawEmpresa = userData['empresa'];
          if (rawEmpresa is Map<String, dynamic>) {
            _userCompany = rawEmpresa['nombreEmpresa']?.toString() ?? widget.companyName;
          } else if (rawEmpresa is Map) {
            _userCompany = rawEmpresa['nombreEmpresa']?.toString() ?? widget.companyName;
          } else {
            _userCompany = widget.companyName;
          }

          // Otros datos del usuario
          _userEmail = userData['correo']?.toString();
          _userPhone = userData['telefono']?.toString();
          _userAddress = userData['direccion']?.toString();
          _userDocument = userData['numeroDocumento']?.toString();
          _isLoading = false;
          debugPrint('✅ Datos de conductor cargados del backend: $_userName | $_userCompany');
        });
      } else {
        debugPrint('⚠️ Error al obtener perfil del backend: ${response.statusCode}');
        // Usar datos del constructor como fallback (datos reales del login)
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
    } on TimeoutException {
      debugPrint('⚠️ Timeout al obtener perfil del backend - usando datos del login');
      setState(() {
        _userName = widget.personName;
        _userCompany = widget.companyName;
        _userEmail = null;
        _userPhone = null;
        _userAddress = null;
        _userDocument = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Excepción al obtener perfil del backend: $e - usando datos del login');
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
    _MenuOption('Certificaciones', Icons.verified_rounded, 'Certificaciones'),
    _MenuOption('Perfil', Icons.person_rounded, 'Perfil'),
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

  void _onTopMenuTap(int index) {
    setState(() {
      _selectedTopIndex = index;
      _activeSection = _upperMenuOptions[index].label;
    });
  }

  void _activateSection(String section) {
    setState(() {
      _activeSection = section;
      final int topIdx = _upperMenuOptions.indexWhere((option) => option.label == section);
      _selectedTopIndex = topIdx != -1 ? topIdx : null;
      final int lowerIdx = _lowerMenuOptions.indexWhere((option) => option.label == section);
      _selectedLowerIndex = lowerIdx != -1 ? lowerIdx : null;
    });
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
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
        label: Text(option.label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => _onTopMenuTap(index),
        selectedColor: _accentColor,
        backgroundColor: _accentColor.withValues(alpha: 0.12),
        showCheckmark: false,
        side: BorderSide(
          color: selected ? _chipBorderColor : Colors.white24,
        ),
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
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  // Center: Search bar
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.14),
                          hintText: 'Buscar viajes, documentos o información',
                          hintStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
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
              'Menú',
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
                    option.label,
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
              GestureDetector(
                onTap: _navigateToMessages,
                child: Icon(Icons.notifications_none, color: Colors.white, size: isCompact ? 24 : 28),
              ),
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
          onNavigateToProfile: _navigateToProfile,
          onNavigateToMessages: _navigateToMessages,
        );
      case 'Documentos':
        return DocumentosScreen(
          role: 'Conductor',
          userId: widget.userId,
          canUpload: false,
        );
      case 'Certificaciones':
        return CertificacionesWidget(
          role: 'Conductor',
          userId: widget.userId ?? '1',
          jsonPath: 'assets/certificaciones_data.json',
        );
      case 'Perfil':
        return PerfilWidget(
          role: 'Conductor',
          userId: widget.userId ?? '1',
          jsonPath: 'assets/user_profile.json',
          userName: _userName,
          userCompany: _userCompany,
          userEmail: _userEmail,
          userPhone: _userPhone,
          userAddress: _userAddress,
          userDocument: _userDocument,
        );
      case 'Mensajes':
        return _buildMessagesContent();
      case 'Vehículo':
        return VehiculosWidget(
          role: 'Conductor',
          ownerId: widget.userId,
          jsonPath: 'assets/vehicles_data.json',
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

  Widget _buildMessagesContent() {
    if (_alerts.isEmpty) {
      return _buildEmptyState(
        'Mensajes corporativos',
        'No hay mensajes recientes para la empresa.',
      );
    }

    final List<Map<String, dynamic>> ordered =
        List<Map<String, dynamic>>.from(_alerts)
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
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ...ordered.map(_buildMessageCard),
        ],
      ),
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
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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

  Widget _buildMessageCard(Map<String, dynamic> alert) {
    final String title = alert['title']?.toString() ?? 'Mensaje';
    final String message = alert['message']?.toString() ?? '';
    final String severity = alert['severity']?.toString().toLowerCase() ?? 'medium';
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
              Icon(Icons.mark_email_unread_rounded, color: borderColor, size: 18),
              const SizedBox(width: 8),
              Text(
                tag,
                style: TextStyle(color: borderColor, fontSize: 12, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (message.isNotEmpty) ...
            [
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
      return const Scaffold(
        backgroundColor: Color(0xFF131760),
        body: Center(child: CircularProgressIndicator()),
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
                        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                      ),
                      child: _buildContentView(),
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
                          child: _buildContentView(),
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
    );
  }
}
