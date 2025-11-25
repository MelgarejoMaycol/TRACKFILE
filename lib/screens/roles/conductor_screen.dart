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
    Key? key,
    this.profileImagePath = '',
    this.companyName = 'Empresa Demo',
    this.personName = 'Nombre Persona',
    this.notificationsCount = 0,
    this.userId,
  }) : super(key: key);

  @override
  State<ConductorScreen> createState() => _ConductorScreenState();
}

class _ConductorScreenState extends State<ConductorScreen> {
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
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 64,
      color: const Color(0xFF3330BE),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomIcon(Icons.home, 0, 'Inicio'),
          _buildBottomIcon(Icons.map, 1, 'Rutas'),
          _buildBottomIcon(Icons.add_box, 2, 'Nuevo'),
          _buildBottomIcon(Icons.chat, 3, 'Mensajes'),
          _buildBottomIcon(Icons.person, 4, 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildBottomIcon(IconData icon, int idx, String label) {
    final selected = _selectedIndex == idx;
    return InkWell(
      onTap: () => _onBottomTap(idx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? Colors.white : Colors.white70),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Color(0xFF3330BE),
      padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white24,
            backgroundImage: widget.profileImagePath.isNotEmpty ? NetworkImage(widget.profileImagePath) : null,
            child: widget.profileImagePath.isEmpty ? Icon(Icons.person, size: 36, color: Colors.white) : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userName, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(_userCompany, style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Stack(
            children: [
              Icon(Icons.notifications_none, color: Colors.white, size: 28),
              if (widget.notificationsCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${widget.notificationsCount}', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndWelcome() {
    return Container(
      color: Color(0xFF3330BE),
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: Offset(-8, 0),
                child: Text('Bienvenido', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
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
        'Contenido: ${_selectedIndex}',
        style: const TextStyle(fontSize: 20, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF3330BE),
      body: SafeArea(
        child: Row(
          children: [
            _buildLeftSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchAndWelcome(),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF131760),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                        ),
                      ),
                      child: _buildContentForIndex(),
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
