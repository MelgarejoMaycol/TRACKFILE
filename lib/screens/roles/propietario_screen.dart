import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/services/notificaciones_service.dart';
import 'package:trackfile/services/notifications/notificaciones_realtime_service.dart';
import 'package:trackfile/utils/api_config.dart';
import 'package:trackfile/widgets/certificates/certificaciones.dart';
import 'package:trackfile/widgets/documents/documentos_screen.dart';
import 'package:trackfile/widgets/inicio.dart';
import 'package:trackfile/widgets/maintenance/mantenimientos.dart';
import 'package:trackfile/widgets/messages/mensajes.dart';
import 'package:trackfile/widgets/users/empresa.dart';
import 'package:trackfile/widgets/users/perfil.dart';
import 'package:trackfile/widgets/utils/logout_button.dart';
import 'package:trackfile/widgets/vehicles/vehiculos.dart';

class _MenuOption {
  final String label;
  final IconData icon;
  final String section;

  const _MenuOption(this.label, this.icon, this.section);
}

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
  static const String _ownerDashboardAsset =
      'assets/propietario_dashboard.json';
  String _baseUrl = ApiConfig.fallbackBaseUrl();
  // ignore: unused_field
  final int _selectedIndex = 0;
  String _userName = '';
  String _userCompany = '';
  bool _isLoading = true;
  int _inicioRefreshKey = 0;
  int _notificationsCount = 0;
  List<Map<String, dynamic>> _ownerVehicles = [];
  List<Map<String, dynamic>> _ownerDocuments = [];
  String? _userProfileImage;
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;
  String? _userDocument;
  String? _propietarioId; // ID del propietario obtenido del backend
  String? _selectedDocumentsVehicleId;
  String? _selectedDocumentsVehiclePlate;

  String? _selectedMaintenanceVehicleId;
  String? _selectedMaintenanceVehiclePlate;
  static const List<String> _monthLabels = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];

  // --- Menus compatible con ConductorScreen ---
  int? _selectedUpperIndex;
  int? _selectedLowerIndex = 0;
  String _activeSection = 'Inicio';
  int _contentRefreshKey = 0;

  static const List<_MenuOption> _upperMenuOptions = [
    _MenuOption('Mensajes', Icons.chat_bubble_rounded, 'Mensajes'),
    _MenuOption('Vehículo', Icons.directions_car_filled_rounded, 'Vehículo'),
    _MenuOption('Empresa', Icons.apartment_rounded, 'Empresa'),
    _MenuOption('Mantenimientos', Icons.build_rounded, 'Mantenimientos'),
  ];

  static const List<_MenuOption> _lowerMenuOptions = [
    _MenuOption('Inicio', Icons.dashboard_rounded, 'Inicio'),
    _MenuOption('Documentos', Icons.folder_special_rounded, 'Documentos'),
    _MenuOption('Certificaciones', Icons.verified_rounded, 'Certificaciones'),
    _MenuOption('Perfil', Icons.person_rounded, 'Perfil'),
  ];

  static const List<_MenuOption> _topMenuOptions = [
    _MenuOption('Mensajes', Icons.chat_rounded, 'Mensajes'),
    _MenuOption('Vehículos', Icons.directions_car_filled_rounded, 'Vehículos'),
    _MenuOption('Empresa', Icons.apartment_rounded, 'Empresa'),
    _MenuOption('Mantenimientos', Icons.build_rounded, 'Mantenimientos'),
  ];

  int? _selectedTopIndex;

  @override
  void initState() {
    super.initState();
    NotificacionesRealtimeService.start();
    _initBaseUrl();
    _loadInitialData();
  }

  Future<void> _initBaseUrl() async {
    final resolved = await ApiConfig.loadBaseUrl();
    if (!mounted) return;
    setState(() => _baseUrl = resolved);
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadOwnerProfile(),
      _loadDashboardData(),
      _loadNotificationsCount(),
    ]);

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
        _notificationsCount = count;
      });
    } catch (e) {
      debugPrint('Error cargando contador de notificaciones propietario: $e');
    }
  }

  Future<void> _loadOwnerProfile() async {
    try {
      // Intentar obtener datos del backend si hay userId
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        await _loadOwnerProfileFromBackend(widget.userId!);
      } else {
        // Usar datos del constructor (datos reales del login)
        if (!mounted) return;
        setState(() {
          _userName = widget.personName;
          _userCompany = widget.companyName;
          _userProfileImage = null;
          _userEmail = null;
          _userPhone = null;
          _userAddress = null;
          _userDocument = null;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de propietario: $e');
      // Usar datos del constructor como fallback (datos reales del login)
      if (!mounted) return;
      setState(() {
        _userName = widget.personName;
        _userCompany = widget.companyName;
        _userProfileImage = null;
        _userEmail = null;
        _userPhone = null;
        _userAddress = null;
        _userDocument = null;
      });
    }
  }

  Future<void> _loadOwnerProfileFromBackend(String userId) async {
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
        _propietarioId =
            perfilBackend['idPropietario']?.toString() ??
            perfilBackend['id']?.toString();
        _userProfileImage = null;
      });

      debugPrint(
        '✅ Perfil actualizado en panel superior: $_userName | $_userCompany',
      );
    } catch (e) {
      debugPrint('⚠️ Error actualizando panel superior propietario: $e');

      if (!mounted) return;

      setState(() {
        _userName = widget.personName;
        _userCompany = widget.companyName;
        _userProfileImage = null;
        _userEmail = null;
        _userPhone = null;
        _userAddress = null;
        _userDocument = null;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // Si tenemos userId, cargar del backend
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        await _loadDashboardDataFromBackend(widget.userId!);
      } else {
        // Fallback al JSON estático
        await _loadDashboardDataFromJson();
      }
    } catch (e) {
      debugPrint('Error cargando dashboard: $e');
      // Fallback al JSON como último recurso
      await _loadDashboardDataFromJson();
    }
  }

  Future<void> _loadDashboardDataFromBackend(String propietarioId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('No hay sesión activa');
      }

      // Cargar vehículos del propietario
      final vehiculosUri = ApiConfig.resolve(
        _baseUrl,
        '/api/propietarios/$propietarioId/vehiculos',
      );
      final vehiculosResponse = await http
          .get(
            vehiculosUri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      final List<Map<String, dynamic>> vehicles = [];
      if (vehiculosResponse.statusCode == 200) {
        final List<dynamic> data =
            json.decode(vehiculosResponse.body) as List<dynamic>;
        for (final veh in data.whereType<Map<String, dynamic>>()) {
          final String placa = veh['placa']?.toString() ?? '';
          final String marca = veh['marca']?.toString() ?? '';
          final String modelo = veh['modelo']?.toString() ?? '';
          final String estado =
              veh['estadoVehiculo']?.toString() ?? 'DESCONOCIDO';

          vehicles.add({
            'plate': placa,
            'model': '$marca $modelo',
            'driver': veh['nombreConductor']?.toString() ?? 'Sin asignar',
            'status': estado,
            'nextExpiry': null, // Se obtendría de documentos si es necesario
          });
        }
        debugPrint(
          '✅ ${vehicles.length} vehículos cargados del backend para propietario $propietarioId',
        );
      } else if (vehiculosResponse.statusCode == 404) {
        debugPrint(
          '⚠️ No encontrado endpoint de vehículos por propietario, intentando cargar general',
        );
        // Intentar desde endpoint general
        final generalUri = ApiConfig.resolve(_baseUrl, '/api/vehiculos');
        final generalResponse = await http
            .get(
              generalUri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (generalResponse.statusCode == 200) {
          final List<dynamic> data =
              json.decode(generalResponse.body) as List<dynamic>;
          for (final veh in data.whereType<Map<String, dynamic>>()) {
            final int idProp = veh['idPropietario'] ?? 0;
            if (idProp.toString() == propietarioId) {
              final String placa = veh['placa']?.toString() ?? '';
              final String marca = veh['marca']?.toString() ?? '';
              final String modelo = veh['modelo']?.toString() ?? '';
              final String estado =
                  veh['estadoVehiculo']?.toString() ?? 'DESCONOCIDO';

              vehicles.add({
                'plate': placa,
                'model': '$marca $modelo',
                'driver': veh['nombreConductor']?.toString() ?? 'Sin asignar',
                'status': estado,
                'nextExpiry': null,
              });
            }
          }
          debugPrint(
            '✅ ${vehicles.length} vehículos filtrados del endpoint general',
          );
        }
      }

      // Cargar documentos
      final documentosUri = ApiConfig.resolve(
        _baseUrl,
        '/api/documentos/tabla',
      );
      final documentosResponse = await http
          .get(
            documentosUri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      final List<Map<String, dynamic>> documents = [];
      if (documentosResponse.statusCode == 200) {
        final List<dynamic> data =
            json.decode(documentosResponse.body) as List<dynamic>;
        for (final doc in data.whereType<Map<String, dynamic>>()) {
          final idUsuario = doc['idUsuario'];
          if (idUsuario == null) {
            // Solo documentos de vehículos
            final DateTime? expiry = DateTime.tryParse(
              doc['fechaVencimiento']?.toString() ?? '',
            );
            final DateTime? payment = DateTime.tryParse(
              doc['fechaPago']?.toString() ?? '',
            );

            documents.add({
              'name': doc['nombre']?.toString() ?? 'Documento',
              'vehicle': doc['vehiculoPlaca']?.toString() ?? '',
              'expiryDate': expiry,
              'paymentDate': payment,
            });
          }
        }
        debugPrint('✅ ${documents.length} documentos de vehículos cargados');
      }

      // Crear alertas basadas en documentos próximos a vencer
      final List<Map<String, dynamic>> alerts = [];
      for (final doc in documents) {
        if (doc['expiryDate'] != null) {
          final DateTime expiry = doc['expiryDate'] as DateTime;
          final Duration difference = expiry.difference(DateTime.now());
          if (difference.inDays <= 30) {
            alerts.add({
              'title': '${doc['name']} próximo a vencer',
              'message':
                  'El documento ${doc['name']} vence el ${expiry.day}/${expiry.month}/${expiry.year}',
              'severity': difference.inDays <= 7 ? 'high' : 'medium',
              'tag': 'Documentos',
            });
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _ownerDocuments = documents;
        _ownerVehicles = vehicles;
        //_notificationsCount = notificationsCount;
      });
      debugPrint(
        '✅ Dashboard cargado del backend para propietario $propietarioId',
      );
    } catch (e) {
      debugPrint('❌ Error cargando dashboard del backend: $e');
      rethrow;
    }
  }

  Future<void> _loadDashboardDataFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString(
        _ownerDashboardAsset,
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      jsonData['summary'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(jsonData['summary'] as Map)
          : <String, dynamic>{
              'totalVehicles': jsonData['vehicles'] != null
                  ? (jsonData['vehicles'] as List).length
                  : 0,
              'totalDocuments': jsonData['documents'] != null
                  ? (jsonData['documents'] as List).length
                  : 0,
              'documentsExpiring': 0,
              'alertsHigh': 0,
            };

      final List<Map<String, dynamic>> documents =
          (jsonData['documents'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((doc) {
                final DateTime? expiry = DateTime.tryParse(
                  doc['expiryDate']?.toString() ?? '',
                );
                final DateTime? payment = DateTime.tryParse(
                  doc['paymentDate']?.toString() ?? '',
                );
                return {
                  'name': doc['name']?.toString() ?? 'Documento',
                  'vehicle': doc['vehicle']?.toString() ?? '',
                  'expiryDate': expiry,
                  'paymentDate': payment,
                };
              })
              .toList();

      final List<Map<String, dynamic>> vehicles =
          (jsonData['vehicles'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((vehicle) {
                final DateTime? nextExpiry = DateTime.tryParse(
                  vehicle['nextExpiry']?.toString() ?? '',
                );
                return {
                  'plate': vehicle['plate']?.toString() ?? '',
                  'model': vehicle['model']?.toString() ?? '',
                  'driver': vehicle['driver']?.toString() ?? '',
                  'status': vehicle['status']?.toString() ?? '',
                  'nextExpiry': nextExpiry,
                };
              })
              .toList();

      // Extraer información de conductores de los vehículos
      final List<Map<String, dynamic>> drivers = <Map<String, dynamic>>[];
      final Set<String> uniqueDrivers = {};
      for (final vehicle in vehicles) {
        final String driverName = vehicle['driver']?.toString() ?? '';
        if (driverName.isNotEmpty &&
            driverName != 'Disponible' &&
            !uniqueDrivers.contains(driverName)) {
          uniqueDrivers.add(driverName);
          drivers.add({
            'name': driverName,
            'assignedVehicle': vehicle['plate']?.toString() ?? 'Sin vehículo',
            'status': 'Activo',
          });
        }
      }

      // Crear alertas basadas en estados de documentos
      final List<Map<String, dynamic>> alerts = <Map<String, dynamic>>[];
      for (final doc in documents) {
        if (doc['expiryDate'] != null) {
          final DateTime expiry = doc['expiryDate'] as DateTime;
          final Duration difference = expiry.difference(DateTime.now());
          if (difference.inDays <= 30) {
            alerts.add({
              'title': '${doc['name']} próximo a vencer',
              'message':
                  'El documento ${doc['name']} vence el ${expiry.day}/${expiry.month}/${expiry.year}',
              'severity': difference.inDays <= 7 ? 'high' : 'medium',
              'tag': 'Documentos',
            });
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _ownerDocuments = documents;
        _ownerVehicles = vehicles;
        //_notificationsCount = notificationsCount;
      });
    } catch (e) {
      debugPrint('Error cargando dashboard de propietario: $e');
      if (!mounted) return;
      setState(() {
        _ownerDocuments = [];
        _ownerVehicles = [];
        _notificationsCount = 0;
      });
    }
  }

  void _onUpperMenuTap(int idx) {
    setState(() {
      _contentRefreshKey++;
      _selectedUpperIndex = idx;
      _selectedLowerIndex = null;
      _activeSection = _upperMenuOptions[idx].label;
    });
  }

  void _onLowerMenuTap(int idx) {
    setState(() {
      _contentRefreshKey++;
      _selectedLowerIndex = idx;
      _selectedUpperIndex = null;
      _activeSection = _lowerMenuOptions[idx].label;
    });
  }

  void _onBottomTap(String label) {
    setState(() {
      _contentRefreshKey++;
      _activeSection = label;
      final int upperIdx = _upperMenuOptions.indexWhere(
        (o) => o.label == label,
      );
      _selectedUpperIndex = upperIdx != -1 ? upperIdx : null;
      final int lowerIdx = _lowerMenuOptions.indexWhere(
        (o) => o.label == label,
      );
      _selectedLowerIndex = lowerIdx != -1 ? lowerIdx : null;
    });
  }

  void _navigateToDocuments() {
    final int docsIndex = _lowerMenuOptions.indexWhere(
      (option) => option.label == 'Documentos',
    );
    if (docsIndex != -1) {
      _onLowerMenuTap(docsIndex);
    }
  }

  void _navigateToProfile() {
    final int profileIndex = _lowerMenuOptions.indexWhere(
      (option) => option.label == 'Perfil',
    );
    if (profileIndex != -1) {
      _onLowerMenuTap(profileIndex);
    }
  }

  void _navigateToMessages() {
    final int messagesIndex = _upperMenuOptions.indexWhere(
      (option) => option.label == 'Mensajes',
    );
    if (messagesIndex != -1) {
      _onUpperMenuTap(messagesIndex);
      _loadNotificationsCount();
    }
  }

  void _onTopMenuTap(int index) {
    setState(() {
      _contentRefreshKey++;
      _selectedTopIndex = index;
      _activeSection = _topMenuOptions[index].section;
    });
  }

  void _activateSection(String section) {
    setState(() {
      _contentRefreshKey++;
      _activeSection = section;
      final int topIdx = _topMenuOptions.indexWhere(
        (option) => option.section == section,
      );
      _selectedTopIndex = topIdx != -1 ? topIdx : null;
      final int lowerIdx = _lowerMenuOptions.indexWhere(
        (option) => option.section == section,
      );
      _selectedLowerIndex = lowerIdx != -1 ? lowerIdx : null;
    });
  }

  Widget _buildDesktopTopBar() {
    final double avatarSize = 52;

    Widget avatarContent;
    if (_userProfileImage != null && _userProfileImage!.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.asset(
          _userProfileImage!,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: _accentColor,
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
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
          _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

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
                          hintText:
                              'Buscar vehículos, documentos o propiedades',
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
              children: _lowerMenuOptions.asMap().entries.map((entry) {
                final int index = entry.key;
                final _MenuOption option = entry.value;
                final bool selected = _selectedLowerIndex == index;
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
      onTap: () => _onLowerMenuTap(index),
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
              label,
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
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 20 : 28,
        horizontal: isCompact ? 16 : 20,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isCompact ? 30 : 36,
            backgroundColor: Colors.white24,
            backgroundImage: avatarImage,
            child: avatarImage == null
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
                  displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  displayCompany,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isCompact ? 13 : 14,
                  ),
                ),
              ],
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
                  'Bienvenido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
              onSelected: (_) => _onUpperMenuTap(index),
              selectedColor: _accentColor,
              backgroundColor: _accentColor.withValues(alpha: 0.12),
              showCheckmark: false,
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
          role: 'Propietario',
          jsonPath: _ownerDashboardAsset,
          userProfilePath: _ownerProfileAsset,
          userId: widget.userId ?? '1',
          onNavigateToDocuments: _navigateToDocuments,
          onNavigateToProfile: _navigateToProfile,
          onNavigateToMessages: _navigateToMessages,
        );
      case 'Documentos':
        return DocumentosScreen(
          role: 'Propietario',
          userId: widget.userId,
          canUpload: false,
          initialVehicleId: _selectedDocumentsVehicleId,
          initialVehiclePlate: _selectedDocumentsVehiclePlate,
        );
      case 'Certificaciones':
        return CertificacionesWidget(
          role: 'Propietario',
          userId: widget.userId ?? '1',
        );
      case 'Perfil':
        return PerfilWidget(
          role: 'Propietario',
          userId: widget.userId ?? '1',
          userName: _userName,
          userCompany: _userCompany,
          userEmail: _userEmail,
          userPhone: _userPhone,
          userAddress: _userAddress,
          userDocument: _userDocument,
          onPerfilActualizado: () async {
            await _loadOwnerProfile();
            await _loadDashboardData();
            if (!mounted) return;
            setState(() {
              _inicioRefreshKey++;
            });
          },
          onEmpresaActualizada: () async {
            await _loadOwnerProfile();
            await _loadDashboardData();
            if (!mounted) return;
            setState(() {
              _inicioRefreshKey++;
            });
          },
        );
      case 'Mensajes':
        return MensajesWidget(
          role: 'Propietario',
          userId: widget.userId,
          onNotificationsChanged: _loadNotificationsCount,
        );
      case 'Vehículo':
        debugPrint(
          '📍 PropietarioScreen.Vehículo - userId: ${widget.userId}, propietarioId: $_propietarioId',
        );

        return VehiculosWidget(
          role: 'Propietario',
          ownerId: widget.userId,
          jsonPath: 'assets/vehicles_data.json',

          onVerDocumentosVehiculo:
              ({required int vehiculoId, required String placa}) {
                setState(() {
                  _selectedDocumentsVehicleId = vehiculoId.toString();
                  _selectedDocumentsVehiclePlate = placa;

                  _activeSection = 'Documentos';

                  final docsIndex = _lowerMenuOptions.indexWhere(
                    (option) => option.label == 'Documentos',
                  );

                  _selectedLowerIndex = docsIndex;
                  _selectedUpperIndex = null;
                });
              },

          onVerMantenimientosVehiculo:
              ({required int vehiculoId, required String placa}) {
                setState(() {
                  _selectedMaintenanceVehicleId = vehiculoId.toString();
                  _selectedMaintenanceVehiclePlate = placa;

                  _activeSection = 'Mantenimientos';

                  final mantIndex = _upperMenuOptions.indexWhere(
                    (option) => option.label == 'Mantenimientos',
                  );

                  _selectedUpperIndex = mantIndex;
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
          role: 'Propietario',
          userId: widget.userId ?? '1',
          vehiculoId: _selectedMaintenanceVehicleId,
          vehiculoPlaca: _selectedMaintenanceVehiclePlate,
        );
      case 'Calendario':
        return _buildCalendarContent();
      case 'Solicitudes':
        return _buildPlaceholderContent(
          title: 'Solicitudes',
          message: 'No hay solicitudes registradas en el JSON de propietario.',
        );
      case 'Vehículos':
        return VehiculosWidget(
          role: 'Propietario',
          ownerId: widget.userId,
          jsonPath: 'assets/vehicles_data.json',
          onVerDocumentosVehiculo:
              ({required int vehiculoId, required String placa}) {
                setState(() {
                  _selectedDocumentsVehicleId = vehiculoId.toString();
                  _selectedDocumentsVehiclePlate = placa;
                  _activeSection = 'Documentos';
                  _selectedLowerIndex = 1;
                  _selectedUpperIndex = null;
                  _selectedTopIndex = null;
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
                  _selectedTopIndex = 3;
                });
              },
        );
      default:
        return InicioWidget(
          role: 'Propietario',
          jsonPath: _ownerDashboardAsset,
          userProfilePath: _ownerProfileAsset,
          userId: widget.userId ?? '1',
        );
    }
  }

  /// Construye el contenido de documentos
  // ignore: unused_element
  Widget _buildDocumentsContent() {
    if (_ownerDocuments.isEmpty) {
      return _buildPlaceholderContent(
        title: 'Documentos',
        message: 'No se encontraron documentos en el JSON de propietario.',
      );
    }

    final List<Map<String, dynamic>> sortedDocuments =
        List<Map<String, dynamic>>.from(_ownerDocuments)..sort((a, b) {
          final DateTime aDate =
              DateTime.tryParse(a['expiryDate']?.toString() ?? '') ??
              DateTime(2100);
          final DateTime bDate =
              DateTime.tryParse(b['expiryDate']?.toString() ?? '') ??
              DateTime(2100);
          return aDate.compareTo(bDate);
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Documentos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
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

    final List<Map<String, dynamic>> upcomingDocs =
        List<Map<String, dynamic>>.from(_ownerDocuments)..sort((a, b) {
          final DateTime aDate =
              DateTime.tryParse(a['expiryDate']?.toString() ?? '') ??
              DateTime(2100);
          final DateTime bDate =
              DateTime.tryParse(b['expiryDate']?.toString() ?? '') ??
              DateTime(2100);
          return aDate.compareTo(bDate);
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendario de vencimientos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...upcomingDocs.map(_buildCalendarItem),
        ],
      ),
    );
  }

  /// Construye la sección del perfil
  // ignore: unused_element
  Widget _buildProfileSection() {
    final String displayName = _userName.isNotEmpty
        ? _userName
        : (widget.personName.isNotEmpty ? widget.personName : 'Propietario');
    final String displayCompany = _userCompany.isNotEmpty
        ? _userCompany
        : (widget.companyName.isNotEmpty ? widget.companyName : 'Sin compañía');
    final String email = (_userEmail != null && _userEmail!.trim().isNotEmpty)
        ? _userEmail!
        : 'No registrado';
    final String phone = (_userPhone != null && _userPhone!.trim().isNotEmpty)
        ? _userPhone!
        : 'No registrado';

    int documentsUpToDate = 0;
    int documentsExpiringSoon = 0;
    final DateTime now = DateTime.now();
    for (final Map<String, dynamic> doc in _ownerDocuments) {
      final String? expiryRaw = doc['expiryDate']?.toString();
      if (expiryRaw == null || expiryRaw.isEmpty) {
        continue;
      }
      final DateTime? expiry = DateTime.tryParse(expiryRaw);
      if (expiry == null) {
        continue;
      }
      if (!expiry.isBefore(now)) {
        documentsUpToDate++;
        final int days = expiry.difference(now).inDays;
        if (days <= 30) {
          documentsExpiringSoon++;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perfil del propietario',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayCompany,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 18),
                _buildProfileDetailRow(
                  Icons.mail_outline_rounded,
                  'Correo',
                  email,
                ),
                _buildProfileDetailRow(Icons.phone_outlined, 'Teléfono', phone),
                _buildProfileDetailRow(
                  Icons.directions_bus_rounded,
                  'Vehículos registrados',
                  _ownerVehicles.isEmpty
                      ? 'Sin vehículos'
                      : '${_ownerVehicles.length}',
                ),
                _buildProfileDetailRow(
                  Icons.folder_special_outlined,
                  'Documentos cargados',
                  _ownerDocuments.isEmpty
                      ? 'Sin documentos'
                      : '${_ownerDocuments.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildProfileChip(
                Icons.verified_user_outlined,
                'Vigentes: $documentsUpToDate',
              ),
              _buildProfileChip(
                Icons.timer_outlined,
                'Próximos a vencer: $documentsExpiringSoon',
              ),
            ],
          ),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const LogoutButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent({
    required String title,
    required String message,
  }) {
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

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final String name = document['name']?.toString() ?? 'Documento';
    final String vehicle = document['vehicle']?.toString() ?? 'Sin asignar';
    final String paymentDate = _formatDate(document['paymentDate']?.toString());
    final String? expiryDateRaw = document['expiryDate']?.toString();
    final String expiryDate = _formatDate(expiryDateRaw);
    final DateTime? expiry = expiryDateRaw != null
        ? DateTime.tryParse(expiryDateRaw)
        : null;

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
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Vehículo: $vehicle',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.payments, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text(
                'Fecha de pago: $paymentDate',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_busy, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text(
                'Fecha de vencimiento: $expiryDate',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
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
    final DateTime? expiry = expiryDateRaw != null
        ? DateTime.tryParse(expiryDateRaw)
        : null;
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
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vehículo: $vehicle',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vencimiento: $formattedExpiry',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  _buildRemainingText(expiry),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge(DateTime? date) {
    final String day = date != null
        ? date.day.toString().padLeft(2, '0')
        : '--';
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
          Text(
            day,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            month,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
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
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(radius),
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey('$_activeSection-$_contentRefreshKey'),
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
    );
  }
}
