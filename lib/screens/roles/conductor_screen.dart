import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:frontendproyecto/widgets/inicio.dart';

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

  int _selectedIndex = 0;
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

  final List<String> _leftMenuItems = [
    'Inicio',
    'Empresa',
    'Documentos',
    'Solicitudes',
    'Calendario',
  ];

  void _onLeftMenuTap(int idx) {
    setState(() => _selectedIndex = idx);
  }

  void _onBottomTap(int idx) {
    setState(() => _selectedIndex = idx);
  }

  Widget _buildLeftSidebar() {
    const double gap = 40.0; // mayor espacio entre botones
    final int lastIndex = _leftMenuItems.length - 1;
    return Container(
      width: 72,
      color: Colors.transparent,
      child: Column(
        // Alinear la lista hacia arriba (inicio)
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 220), // empujar el grupo significativamente hacia abajo
          // los items
          ..._leftMenuItems.asMap().entries.map((e) {
            final i = e.key;
            final label = e.value;
            final selected = _selectedIndex == i;
            return Padding(
              padding: EdgeInsets.only(bottom: i == lastIndex ? 20.0 : gap),
              child: GestureDetector(
                onTap: () => _onLeftMenuTap(i),
                child: Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar({required bool isCompact}) {
    return Container(
      height: isCompact ? 60 : 64,
      color: _primaryColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomIcon(Icons.home, 0, 'Inicio', isCompact: isCompact),
          _buildBottomIcon(Icons.map, 1, 'Rutas', isCompact: isCompact),
          _buildBottomIcon(Icons.add_box, 2, 'Nuevo', isCompact: isCompact),
          _buildBottomIcon(Icons.chat, 3, 'Mensajes', isCompact: isCompact),
          _buildBottomIcon(Icons.person, 4, 'Perfil', isCompact: isCompact),
        ],
      ),
    );
  }

  Widget _buildBottomIcon(IconData icon, int idx, String label, {required bool isCompact}) {
    final selected = _selectedIndex == idx;
    return InkWell(
      onTap: () => _onBottomTap(idx),
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
            final label = _leftMenuItems[index];
            final selected = _selectedIndex == index;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => _onLeftMenuTap(index),
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
          itemCount: _leftMenuItems.length,
        ),
      ),
    );
  }

  Widget _buildContentForIndex() {
    if (_selectedIndex == 0) {
      return InicioWidget(
        role: 'Conductor',
        jsonPath: 'assets/documents_data.json',
        userProfilePath: 'assets/user_profile.json',
        userId: widget.userId ?? '1', // Usa el userId del widget o '1' por defecto
      );
    }

    return Center(
      child: Text(
        'Contenido: $_selectedIndex',
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
                      child: _buildContentForIndex(),
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
                          child: _buildContentForIndex(),
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
