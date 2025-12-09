import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:frontendproyecto/widgets/inicio.dart';

class PropietarioScreen extends StatefulWidget {
  static const route = '/propietario';

  final String profileImagePath;
  final String companyName;
  final String personName;
  final int notificationsCount;
  final String? userId;

  const PropietarioScreen({
    super.key,
    this.profileImagePath = '',
    this.companyName = '',
    this.personName = '',
    this.notificationsCount = 0,
    this.userId,
  });

  @override
  State<PropietarioScreen> createState() => _PropietarioScreenState();
}

class _PropietarioScreenState extends State<PropietarioScreen> {
  static const Color _primaryColor = Color(0xFF3330BE);
  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);

  static const String _ownerProfileAsset = 'assets/propietario_profile.json';
  static const String _ownerDashboardAsset = 'assets/propietario_dashboard.json';
  int _selectedIndex = 0;
  String _userName = '';
  String _userCompany = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _ownerVehicles = [];
  List<Map<String, dynamic>> _ownerDocuments = [];
  String? _userProfileImage;
  static const List<String> _monthLabels = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];

  final List<String> _leftMenuItems = const [
    'Inicio',
    'Vehículos',
    'Documentos',
    'Solicitudes',
    'Calendario',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadOwnerProfile(),
      _loadDashboardData(),
    ]);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadOwnerProfile() async {
    try {
      final String jsonString = await rootBundle.loadString(_ownerProfileAsset);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final List<dynamic>? ownersRaw = jsonData['owners'] as List<dynamic>?;
      final List<Map<String, dynamic>>? owners = ownersRaw
          ?.map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();

      Map<String, dynamic>? userData;
      String? resolvedProfileImage;
      if (owners != null && owners.isNotEmpty) {
        String? targetId = widget.userId;
        targetId ??= owners.first['id']?.toString();

        userData = owners.firstWhere(
          (owner) => owner['id']?.toString() == targetId,
          orElse: () => owners.first,
        );
            } else if (jsonData.isNotEmpty) {
        userData = jsonData;
      }

      final String? profilePath = userData?['profileImage']?.toString();
      if (profilePath != null && profilePath.isNotEmpty) {
        try {
          await rootBundle.load(profilePath);
          resolvedProfileImage = profilePath;
        } catch (_) {
          resolvedProfileImage = null;
        }
      }

      if (!mounted) return;

      if (userData != null) {
        setState(() {
          _userName = userData?['name']?.toString() ?? _userName;
          _userCompany = userData?['company']?.toString() ?? _userCompany;
          _userProfileImage = resolvedProfileImage;
        });
      } else {
        setState(() {
          if (_userName.isEmpty && widget.personName.isNotEmpty) {
            _userName = widget.personName;
          }
          if (_userCompany.isEmpty && widget.companyName.isNotEmpty) {
            _userCompany = widget.companyName;
          }
          _userProfileImage = null;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de propietario: $e');
      if (!mounted) return;
      setState(() {
        if (_userName.isEmpty && widget.personName.isNotEmpty) {
          _userName = widget.personName;
        }
        if (_userCompany.isEmpty && widget.companyName.isNotEmpty) {
          _userCompany = widget.companyName;
        }
        _userProfileImage = null;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final String jsonString = await rootBundle.loadString(_ownerDashboardAsset);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final List<Map<String, dynamic>> documents =
          (jsonData['documents'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().map((doc) => Map<String, dynamic>.from(doc)).toList();
      final List<Map<String, dynamic>> vehicles =
          (jsonData['vehicles'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().map((vehicle) => Map<String, dynamic>.from(vehicle)).toList();

      if (!mounted) return;
      setState(() {
        _ownerDocuments = documents;
        _ownerVehicles = vehicles;
      });
    } catch (e) {
      debugPrint('Error cargando dashboard de propietario: $e');
      if (!mounted) return;
      setState(() {
        _ownerDocuments = [];
        _ownerVehicles = [];
      });
    }
  }

  void _onLeftMenuTap(int idx) {
    setState(() => _selectedIndex = idx);
  }

  void _onBottomTap(int idx) {
    setState(() => _selectedIndex = idx);
  }

  Widget _buildLeftSidebar() {
    const double gap = 40.0;
    final int lastIndex = _leftMenuItems.length - 1;
    return Container(
      width: 72,
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 220),
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
          _buildBottomIcon(Icons.inventory, 1, 'Activos', isCompact: isCompact),
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
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 6 : 8),
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
            Text(label, style: TextStyle(fontSize: isCompact ? 10 : 11, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    ImageProvider? avatarImage;
    if (_userProfileImage != null && _userProfileImage!.isNotEmpty) {
      avatarImage = AssetImage(_userProfileImage!);
    } else if (widget.profileImagePath.isNotEmpty) {
      avatarImage = NetworkImage(widget.profileImagePath);
    }

    final String displayName = _userName.isNotEmpty
        ? _userName
        : (widget.personName.isNotEmpty ? widget.personName : 'Propietario');
    final String displayCompany = _userCompany.isNotEmpty
        ? _userCompany
        : (widget.companyName.isNotEmpty ? widget.companyName : 'Sin compañía');

    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 20 : 28, horizontal: isCompact ? 16 : 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: isCompact ? 30 : 36,
            backgroundColor: Colors.white24,
            backgroundImage: avatarImage,
            child: avatarImage == null ? Icon(Icons.person, size: isCompact ? 32 : 36, color: Colors.white) : null,
          ),
          SizedBox(width: isCompact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(displayCompany, style: TextStyle(color: Colors.white70, fontSize: isCompact ? 13 : 14)),
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
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${widget.notificationsCount}', style: TextStyle(color: Colors.white, fontSize: isCompact ? 9 : 10)),
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
              labelStyle: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(color: selected ? _chipBorderColor : Colors.white24),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemCount: _leftMenuItems.length,
        ),
      ),
    );
  }

  Widget _buildContentForIndex() {
    switch (_selectedIndex) {
      case 0:
        return InicioWidget(
          role: 'Propietario',
          jsonPath: _ownerDashboardAsset,
          userProfilePath: _ownerProfileAsset,
          userId: widget.userId ?? '1',
        );
      case 1:
        return _buildVehiclesContent();
      case 2:
        return _buildDocumentsContent();
      case 3:
        return _buildPlaceholderContent(
          title: 'Solicitudes',
          message: 'No hay solicitudes registradas en el JSON de propietario.',
        );
      case 4:
        return _buildCalendarContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVehiclesContent() {
    if (_ownerVehicles.isEmpty) {
      return _buildPlaceholderContent(
        title: 'Vehículos',
        message: 'No se encontraron vehículos en el JSON de propietario.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vehículos', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._ownerVehicles.map(_buildVehicleCardFromDashboard),
        ],
      ),
    );
  }

  Widget _buildDocumentsContent() {
    if (_ownerDocuments.isEmpty) {
      return _buildPlaceholderContent(
        title: 'Documentos',
        message: 'No se encontraron documentos en el JSON de propietario.',
      );
    }

    final List<Map<String, dynamic>> sortedDocuments = List<Map<String, dynamic>>.from(_ownerDocuments)
      ..sort((a, b) {
        final DateTime aDate = DateTime.tryParse(a['expiryDate']?.toString() ?? '') ?? DateTime(2100);
        final DateTime bDate = DateTime.tryParse(b['expiryDate']?.toString() ?? '') ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Documentos', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...sortedDocuments.map(_buildDocumentCard),
        ],
      ),
    );
  }

  Widget _buildCalendarContent() {
    if (_ownerDocuments.isEmpty) {
      return _buildPlaceholderContent(
        title: 'Calendario de vencimientos',
        message: 'No hay documentos cargados para el calendario.',
      );
    }

    final List<Map<String, dynamic>> upcomingDocs = List<Map<String, dynamic>>.from(_ownerDocuments)
      ..sort((a, b) {
        final DateTime aDate = DateTime.tryParse(a['expiryDate']?.toString() ?? '') ?? DateTime(2100);
        final DateTime bDate = DateTime.tryParse(b['expiryDate']?.toString() ?? '') ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calendario de vencimientos', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...upcomingDocs.map(_buildCalendarItem),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent({required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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

  Widget _buildVehicleCardFromDashboard(Map<String, dynamic> vehicle) {
    final String plate = vehicle['plate']?.toString() ?? 'Sin placa';
    final String model = vehicle['model']?.toString() ?? 'Modelo no disponible';
    final String driver = vehicle['driver']?.toString() ?? 'Sin asignar';
    final String status = vehicle['status']?.toString() ?? 'Sin estado';
    final String? nextExpiryRaw = vehicle['nextExpiry']?.toString();
    final String nextExpiry = _formatDate(nextExpiryRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plate,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: _vehicleStatusColor(status).withValues(alpha: 0.25),
                side: BorderSide(color: _vehicleStatusColor(status).withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(model, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('Conductor: $driver', style: const TextStyle(color: Colors.white70, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text('Próximo vencimiento: $nextExpiry', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final String name = document['name']?.toString() ?? 'Documento';
    final String vehicle = document['vehicle']?.toString() ?? 'Sin asignar';
    final String paymentDate = _formatDate(document['paymentDate']?.toString());
    final String? expiryDateRaw = document['expiryDate']?.toString();
    final String expiryDate = _formatDate(expiryDateRaw);
    final DateTime? expiry = expiryDateRaw != null ? DateTime.tryParse(expiryDateRaw) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('Vehículo: $vehicle', style: const TextStyle(color: Colors.white70, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.payments, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text('Fecha de pago: $paymentDate', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_busy, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text('Fecha de vencimiento: $expiryDate', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _buildRemainingText(expiry),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarItem(Map<String, dynamic> document) {
    final String name = document['name']?.toString() ?? 'Documento';
    final String vehicle = document['vehicle']?.toString() ?? 'Sin asignar';
    final String? expiryDateRaw = document['expiryDate']?.toString();
    final DateTime? expiry = expiryDateRaw != null ? DateTime.tryParse(expiryDateRaw) : null;
    final String formattedExpiry = _formatDate(expiryDateRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          _buildDateBadge(expiry),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Vehículo: $vehicle', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Vencimiento: $formattedExpiry', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(_buildRemainingText(expiry), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge(DateTime? date) {
    final String day = date != null ? date.day.toString().padLeft(2, '0') : '--';
    final String month = date != null ? _monthLabels[date.month - 1] : '---';

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF4442D0),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(month, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Color _vehicleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'al día':
        return const Color(0xFF16C79A);
      case 'documentos pendientes':
        return const Color(0xFFEFB549);
      case 'en mantenimiento':
        return const Color(0xFFE66B6B);
      default:
        return Colors.white54;
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return 'Sin fecha';
    }
    final DateTime? parsed = DateTime.tryParse(isoString);
    if (parsed == null) {
      return isoString;
    }
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    final String year = parsed.year.toString();
    return '$day/$month/$year';
  }

  String _buildRemainingText(DateTime? expiry) {
    if (expiry == null) {
      return 'Fecha de vencimiento no disponible';
    }
    final int days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) {
      return 'Vencido hace ${days.abs()} días';
    }
    if (days == 0) {
      return 'Vence hoy';
    }
    return 'Faltan $days días';
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
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(24)),
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
