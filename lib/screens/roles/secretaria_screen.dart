import 'package:flutter/material.dart';

class _MenuOption {
  final String label;
  final IconData icon;
  final String section;

  const _MenuOption(this.label, this.icon, this.section);
}

class SecretariaScreen extends StatefulWidget {
  const SecretariaScreen({super.key});
  static const route = '/secretaria';

  @override
  State<SecretariaScreen> createState() => _SecretariaScreenState();
}

class _SecretariaScreenState extends State<SecretariaScreen> {
  static const Color _primaryColor = Color(0xFF3330BE);
  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _accentColor = Color(0xFF4F4CE8);

  int _selectedBottomIndex = 0;
  String _activeSection = 'Inicio';

  static const List<_MenuOption> _bottomMenuOptions = [
    _MenuOption('Inicio', Icons.dashboard_rounded, 'Inicio'),
    _MenuOption('Agenda', Icons.calendar_month_rounded, 'Agenda'),
    _MenuOption('Documentos', Icons.folder_special_rounded, 'Documentos'),
    _MenuOption('Mensajes', Icons.mail_rounded, 'Mensajes'),
    _MenuOption('Tareas', Icons.task_alt_rounded, 'Tareas'),
  ];

  void _onBottomMenuTap(int index) {
    setState(() {
      _selectedBottomIndex = index;
      _activeSection = _bottomMenuOptions[index].section;
    });
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

  Widget _buildLeftNavItem(
    _MenuOption option,
    int index,
    bool selected,
  ) {
    return InkWell(
      onTap: () => _onBottomMenuTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _accentColor.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: _accentColor.withValues(alpha: 0.5)) : null,
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
          color: selected ? _accentColor.withValues(alpha: 0.22) : Colors.transparent,
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

  Widget _buildContentView() {
    switch (_activeSection) {
      case 'Inicio':
        return _buildPlaceholder('Panel de Secretaría');
      case 'Agenda':
        return _buildPlaceholder('Agenda y Calendario');
      case 'Documentos':
        return _buildPlaceholder('Documentos');
      case 'Mensajes':
        return _buildPlaceholder('Mensajes');
      case 'Tareas':
        return _buildPlaceholder('Tareas Pendientes');
      default:
        return _buildPlaceholder(_activeSection);
    }
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Contenido a implementar',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 860;

            if (isCompact) {
              // Layout móvil
              return Column(
                children: [
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
                  _buildBottomBar(isCompact: isCompact),
                ],
              );
            } else {
              // Layout desktop: menú izquierdo + contenido
              return Row(
                children: [
                  _buildLeftSidebar(),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: _buildContentView(),
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
