import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:frontendproyecto/widgets/inicio.dart';
import 'package:frontendproyecto/widgets/documentos.dart';
import 'package:frontendproyecto/widgets/logout_button.dart';

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
    _MenuOption('Pagos', Icons.payments_rounded, 'Pagos'),
    _MenuOption('Vehículos', Icons.directions_bus_filled_rounded, 'Vehículos'),
    _MenuOption('Mantenimientos', Icons.build_rounded, 'Mantenimientos'),
  ];

  int _selectedBottomIndex = 0;
  int? _selectedTopIndex;
  String _activeSection = 'Inicio';
  bool _isLoading = true;

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _fleetVehicles = [];
  List<Map<String, dynamic>> _operations = [];
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
      _companyName = rawCompany['nombreEmpresa']?.toString() ??
          rawCompany['nombre']?.toString() ??
          _companyName;
      _representative =
          rawCompany['representanteLegal']?.toString() ?? _representative;
      _nit = rawCompany['nit']?.toString() ?? _nit;
      _companyLogo = rawCompany['logo']?.toString();
      _companyId =
          rawCompany['id_empresa']?.toString() ?? rawCompany['id']?.toString();
        _companyEmail = rawCompany['contacto_email']?.toString() ??
          rawCompany['email']?.toString() ??
          _companyEmail;
        _companyPhone = rawCompany['contacto_telefono']?.toString() ??
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
      final String combined =
          [nombre, apellido].where((part) => part.isNotEmpty).join(' ').trim();
      if (combined.isNotEmpty) {
        _representative = combined;
      }
    }
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
        final DateTime? expiry =
            DateTime.tryParse(entry['expiryDate']?.toString() ?? '');
        final DateTime? payment =
            DateTime.tryParse(entry['paymentDate']?.toString() ?? '');
        return {
          'name': entry['name']?.toString() ?? 'Documento',
          'category': entry['category']?.toString() ?? '',
          'responsible': entry['responsible']?.toString() ?? '',
          'status': entry['status']?.toString() ?? '',
          'paymentDate': payment,
          'expiryDate': expiry,
        };
      }).toList();

      final List<Map<String, dynamic>> vehicles =
          (data['vehicles'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((entry) {
        final DateTime? nextExpiry =
            DateTime.tryParse(entry['nextExpiry']?.toString() ?? '');
        final DateTime? lastService =
            DateTime.tryParse(entry['lastService']?.toString() ?? '');
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
      }).toList();

      final List<Map<String, dynamic>> drivers =
          (data['drivers'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((entry) {
        final DateTime? lastCheck =
            DateTime.tryParse(entry['lastCheckIn']?.toString() ?? '');
        return {
          'name': entry['name']?.toString() ?? 'Conductor',
          'assignedVehicle':
              entry['assignedVehicle']?.toString() ?? 'Sin vehículo',
          'status': entry['status']?.toString() ?? 'Sin estado',
          'lastCheckIn': lastCheck,
          'phone': entry['phone']?.toString() ?? '',
        };
      }).toList();

      final List<Map<String, dynamic>> operations =
          (data['operations'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((entry) {
        final DateTime? date =
            DateTime.tryParse(entry['date']?.toString() ?? '');
        return {
          'title': entry['title']?.toString() ?? 'Operación',
          'description': entry['description']?.toString() ?? '',
          'status': entry['status']?.toString() ?? '',
          'owner': entry['owner']?.toString() ?? '',
          'date': date,
        };
      }).toList();

      final List<Map<String, dynamic>> alerts =
          (data['alerts'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((entry) => {
                    'title': entry['title']?.toString() ?? 'Alerta',
                    'message': entry['message']?.toString() ?? '',
                    'severity': entry['severity']?.toString() ?? 'medium',
                    'tag': entry['tag']?.toString() ?? 'General',
                  })
              .toList();

      final int badgeFromAlerts = alerts
          .where((alert) {
            final String severity =
                alert['severity']?.toString().toLowerCase() ?? '';
            return severity == 'high' || severity == 'alta';
          })
          .length;
      final int badgeFromSummary =
          (summary['alertsHigh'] as num?)?.toInt() ?? 0;
      final int notifications =
          badgeFromAlerts > badgeFromSummary ? badgeFromAlerts : badgeFromSummary;

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _documents = documents;
        _fleetVehicles = vehicles;
        _drivers = drivers;
        _operations = operations;
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
        _drivers = [];
        _operations = [];
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
    });
  }

  void _onTopMenuTap(int index) {
    setState(() {
      _selectedTopIndex = index;
      _selectedBottomIndex = -1;
      _activeSection = _topMenuOptions[index].section;
    });
  }

  void _activateSection(String section) {
    if (_bottomMenuOptions.any((option) => option.section == section)) {
      final int index = _bottomMenuOptions.indexWhere((option) => option.section == section);
      _onBottomMenuTap(index);
      return;
    }

    if (_topMenuOptions.any((option) => option.section == section)) {
      final int index = _topMenuOptions.indexWhere((option) => option.section == section);
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
          onNavigateToPayments: () => _activateSection('Pagos'),
          onNavigateToMessages: () => _activateSection('Mensajes'),
          onNavigateToProfile: () => _activateSection('Perfil'),
        );
      case 'Conductores':
        return _buildDriversContent();
      case 'Propietarios':
        return _buildOwnersContent();
      case 'Documentos':
        return _buildDocumentsContent();
      case 'Perfil':
        return _buildProfileContent();
      case 'Mensajes':
        return _buildMessagesContent();
      case 'Pagos':
        return _buildPaymentsContent();
      case 'Vehículos':
        return _buildFleetContent();
      case 'Mantenimientos':
        return _buildMaintenanceContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDriversContent() {
    if (_drivers.isEmpty) {
      return _buildEmptyState(
        'Conductores',
        'No se encontraron conductores registrados en el panel corporativo.',
      );
    }

    final List<Map<String, dynamic>> ordered =
        List<Map<String, dynamic>>.from(_drivers)
          ..sort((a, b) {
            final DateTime? aDate = a['lastCheckIn'] as DateTime?;
            final DateTime? bDate = b['lastCheckIn'] as DateTime?;
            return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
          });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conductores',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ordered.map(_buildDriverCard),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final String name = driver['name']?.toString() ?? 'Conductor';
    final String vehicle = driver['assignedVehicle']?.toString() ?? 'Sin vehículo';
    final String status = driver['status']?.toString() ?? 'Sin estado';
    final DateTime? lastCheck = driver['lastCheckIn'] as DateTime?;
    final String phone = driver['phone']?.toString() ?? '';
    final Color statusColor = _driverStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.directions_bus_filled_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Asignación: $vehicle',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Último check-in: ${_formatDateTimeLabel(lastCheck)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnersContent() {
    final int fleetTotal =
        (_summary['fleetSize'] as num?)?.toInt() ?? _fleetVehicles.length;
    final int routesToday =
        (_summary['routesToday'] as num?)?.toInt() ?? 0;
    final int activeDrivers =
        (_summary['activeDrivers'] as num?)?.toInt() ?? _drivers.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Propietarios aliados',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Integración pendiente',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Próximamente',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Integra la información de los propietarios de flota para habilitar contratos, documentación y seguimiento de compromisos.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildQuickBadge(Icons.directions_bus_filled_rounded, 'Flota activa: $fleetTotal'),
                    _buildQuickBadge(Icons.route_rounded, 'Rutas hoy: $routesToday'),
                    _buildQuickBadge(Icons.badge_rounded, 'Conductores: $activeDrivers'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsContent() {
    // Use the shared DocumentosWidget which provides search, filters and highlights.
    return DocumentosWidget(
      role: 'Empresa',
      jsonPath: _dashboardAsset,
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final String name = document['name']?.toString() ?? 'Documento';
    final String category = document['category']?.toString() ?? '';
    final String responsible = document['responsible']?.toString() ?? '';
    final String status = document['status']?.toString() ?? '';
    final DateTime? paymentDate = document['paymentDate'] as DateTime?;
    final DateTime? expiryDate = document['expiryDate'] as DateTime?;
    final Color statusColor = _documentStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.isNotEmpty ? status : 'Sin estado',
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (category.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.category_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text('Categoría: $category', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (responsible.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.manage_accounts_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Responsable: $responsible',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pago: ${_formatDateLabel(paymentDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Vencimiento: ${_formatDateLabel(expiryDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatRemaining(expiryDate),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final String description =
        _companyDescription != null && _companyDescription!.trim().isNotEmpty
            ? _companyDescription!
            : 'Describe tu operación y servicios para que el equipo los consulte rápidamente.';
    final String vision =
        _companyVision != null && _companyVision!.trim().isNotEmpty
            ? _companyVision!
            : 'Agrega la visión corporativa para inspirar a tus aliados.';
    final String mission =
        _companyMission != null && _companyMission!.trim().isNotEmpty
            ? _companyMission!
            : 'Define la misión para alinear al equipo y a los propietarios.';

    final List<Map<String, dynamic>> details = [
      {
        'icon': Icons.person_rounded,
        'label': 'Representante',
        'value': _representative.isNotEmpty ? _representative : 'Sin asignar',
      },
      {
        'icon': Icons.business_center_rounded,
        'label': 'NIT',
        'value': _nit,
      },
      {
        'icon': Icons.mail_outline_rounded,
        'label': 'Correo de contacto',
        'value': _companyEmail ?? 'No registrado',
      },
      {
        'icon': Icons.phone_rounded,
        'label': 'Teléfono',
        'value': _companyPhone ?? 'No registrado',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perfil corporativo',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
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
                  _companyName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                ...details.map(
                  (detail) => _buildProfileDetail(
                    detail['icon'] as IconData,
                    detail['label']?.toString() ?? '',
                    detail['value']?.toString() ?? '',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descripción',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Visión',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  vision,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Misión',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  mission,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
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

  Widget _buildPaymentsContent() {
    if (_documents.isEmpty) {
      return _buildEmptyState(
        'Pagos y facturación',
        'Sin registros de pagos asociados en el panel corporativo.',
      );
    }

    final DateTime now = DateTime.now();
    final List<Map<String, dynamic>> ordered =
        List<Map<String, dynamic>>.from(_documents)
          ..sort((a, b) {
            final DateTime aDate = a['paymentDate'] as DateTime? ?? DateTime(2100);
            final DateTime bDate = b['paymentDate'] as DateTime? ?? DateTime(2100);
            return aDate.compareTo(bDate);
          });
    final int dueSoon = ordered.where((doc) {
      final DateTime? payment = doc['paymentDate'] as DateTime?;
      if (payment == null) return false;
      final int delta = payment.difference(now).inDays;
      return delta >= 0 && delta <= 15;
    }).length;
    final int overdue = ordered
        .where((doc) => (doc['paymentDate'] as DateTime?)?.isBefore(now) ?? false)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pagos y facturación',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildQuickBadge(Icons.warning_amber_rounded, '$overdue pagos vencidos'),
              _buildQuickBadge(Icons.schedule_rounded, '$dueSoon pagos próximos'),
              _buildQuickBadge(Icons.receipt_long_rounded, '${ordered.length} obligaciones activas'),
            ],
          ),
          const SizedBox(height: 18),
          ...ordered.map(_buildPaymentCard),
        ],
      ),
    );
  }

  Widget _buildFleetContent() {
    if (_fleetVehicles.isEmpty) {
      return _buildEmptyState(
        'Flota',
        'No hay vehículos registrados en el archivo de empresa.',
      );
    }

    final List<Map<String, dynamic>> ordered =
        List<Map<String, dynamic>>.from(_fleetVehicles)
          ..sort((a, b) {
            final DateTime aDate = a['nextExpiry'] as DateTime? ?? DateTime(2100);
            final DateTime bDate = b['nextExpiry'] as DateTime? ?? DateTime(2100);
            return aDate.compareTo(bDate);
          });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Flota corporativa',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ordered.map(_buildVehicleTile),
        ],
      ),
    );
  }

  Widget _buildVehicleTile(Map<String, dynamic> vehicle) {
    final String plate = vehicle['plate']?.toString() ?? 'Sin placa';
    final String model = vehicle['model']?.toString() ?? 'Modelo no disponible';
    final String driver = vehicle['driver']?.toString() ?? 'Sin asignar';
    final String status = vehicle['status']?.toString() ?? 'Sin estado';
    final DateTime? nextExpiry = vehicle['nextExpiry'] as DateTime?;
    final DateTime? lastService = vehicle['lastService'] as DateTime?;
    final double? utilization = vehicle['utilization'] as double?;
    final Color statusColor = _vehicleStatusColor(status);
    final double normalizedUtilization = utilization == null
        ? 0.0
        : utilization < 0.0
            ? 0.0
            : (utilization > 1.0 ? 1.0 : utilization);
    final int utilizationPercent = (normalizedUtilization * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
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
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            model,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Operador: $driver', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Próximo vencimiento: ${_formatDateLabel(nextExpiry)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.handyman_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Último servicio: ${_formatDateLabel(lastService)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Utilización: $utilizationPercent%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: normalizedUtilization,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationTile(Map<String, dynamic> operation) {
    final String title = operation['title']?.toString() ?? 'Operación';
    final String description = operation['description']?.toString() ?? '';
    final String status = operation['status']?.toString() ?? 'Sin estado';
    final String owner = operation['owner']?.toString() ?? 'Sin responsable';
    final DateTime? date = operation['date'] as DateTime?;
    final Color statusColor = _operationStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available_rounded, color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateLabel(date),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_tree_rounded, color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(owner, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceContent() {
    final List<Map<String, dynamic>> inMaintenance = _fleetVehicles
        .where((vehicle) {
          final String status = vehicle['status']?.toString().toLowerCase() ?? '';
          return status.contains('mantenimiento');
        })
        .toList();
    final List<Map<String, dynamic>> pendingDocuments = _fleetVehicles
        .where((vehicle) {
          final String status = vehicle['status']?.toString().toLowerCase() ?? '';
          return status.contains('documentos');
        })
        .toList();
    final List<Map<String, dynamic>> maintenanceAgenda = _operations
        .where((operation) {
          final String owner = operation['owner']?.toString().toLowerCase() ?? '';
          final String title = operation['title']?.toString().toLowerCase() ?? '';
          return owner.contains('manten') || title.contains('manten');
        })
        .toList();

    if (inMaintenance.isEmpty && pendingDocuments.isEmpty && maintenanceAgenda.isEmpty) {
      return _buildEmptyState(
        'Mantenimientos',
        'No hay mantenimientos programados en el panel.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gestión de mantenimientos',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (inMaintenance.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'En servicio',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...inMaintenance.map(_buildVehicleTile),
          ],
          if (pendingDocuments.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Documentos por actualizar',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...pendingDocuments.map(_buildVehicleTile),
          ],
          if (maintenanceAgenda.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Agenda relacionada',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...maintenanceAgenda.map(_buildOperationTile),
          ],
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

  Widget _buildHeader({required bool isCompact}) {
    final double avatarSize = isCompact ? 62 : 72;
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

    final String representativeLabel =
        _representative.isNotEmpty ? _representative : 'Sin asignar';

    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 20 : 28,
        horizontal: isCompact ? 16 : 24,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: Colors.white24,
            child: avatarContent,
          ),
          SizedBox(width: isCompact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companyName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Representante: $representativeLabel',
                  style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'NIT: $_nit',
                  style: TextStyle(color: Colors.white54, fontSize: isCompact ? 11 : 12),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: isCompact ? 24 : 28,
              ),
              if (_notifications > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '$_notifications',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _buildQuickBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSearchAndWelcome({required bool isCompact}) {
    final DateTime now = DateTime.now();
    final int fleetTotal =
        (_summary['fleetSize'] as num?)?.toInt() ?? _fleetVehicles.length;
    final int expiredComputed = _documents
        .where((doc) => (doc['expiryDate'] as DateTime?)?.isBefore(now) ?? false)
        .length;
    final int docsExpired = expiredComputed > 0
        ? expiredComputed
        : (_summary['documentsExpired'] as num?)?.toInt() ??
            (_summary['documentsPending'] as num?)?.toInt() ??
            0;

    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: isCompact ? 0.92 : 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel corporativo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.14),
                  hintText: 'Buscar por documento, propietario o placa',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildQuickBadge(Icons.directions_bus_rounded, '$fleetTotal vehículos'),
                  _buildQuickBadge(Icons.insert_drive_file_rounded, '$docsExpired documentos vencidos'),
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

    final List<Widget> chips = _topMenuOptions.asMap().entries.map((entry) {
      final int index = entry.key;
      final _MenuOption option = entry.value;
      final bool selected = _selectedTopIndex == index;
      return ChoiceChip(
        avatar: Icon(
          option.icon,
          size: 16,
          color: selected ? Colors.white : Colors.white70,
        ),
        label: Text(option.label),
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
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    }).toList();

    return Container(
      color: _primaryColor,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 14),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: isCompact ? 0.94 : 0.82,
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: chips,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar({required bool isCompact}) {
    return Container(
      height: isCompact ? 62 : 70,
      color: _primaryColor,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 24),
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
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? _accentColor.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, size: isCompact ? 22 : 24, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              option.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 10 : 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
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
          if (message.isNotEmpty) ...[
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

  Widget _buildPaymentCard(Map<String, dynamic> document) {
    final String name = document['name']?.toString() ?? 'Documento';
    final String responsible = document['responsible']?.toString() ?? 'Sin responsable';
    final String category = document['category']?.toString() ?? '';
    final DateTime? paymentDate = document['paymentDate'] as DateTime?;
    final DateTime? expiryDate = document['expiryDate'] as DateTime?;
    final DateTime now = DateTime.now();
    final bool overdue = paymentDate != null && paymentDate.isBefore(now);
    final Color accent = overdue ? const Color(0xFFE66B6B) : _accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  overdue ? 'Pago vencido' : 'Pago programado',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.category_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.isNotEmpty ? category : 'Sin categoría',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.manage_accounts_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Responsable: $responsible',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pago: ${_formatDateLabel(paymentDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Vence: ${_formatDateLabel(expiryDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _driverStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en ruta':
        return const Color(0xFF16C79A);
      case 'disponible':
        return const Color(0xFF4F4CE8);
      case 'relevo':
      case 'en relevo':
        return const Color(0xFFEFB549);
      default:
        return Colors.white70;
    }
  }

  Color _documentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'alerta':
      case 'vencido':
        return const Color(0xFFE66B6B);
      case 'revisión':
      case 'seguimiento':
        return const Color(0xFFEFB549);
      case 'vigente':
        return const Color(0xFF16C79A);
      default:
        return Colors.white70;
    }
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

  Color _operationStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en progreso':
      case 'en ejecución':
        return const Color(0xFF16C79A);
      case 'programado':
        return const Color(0xFF4F4CE8);
      case 'pendiente':
        return const Color(0xFFEFB549);
      case 'retrasado':
      case 'alerta':
        return const Color(0xFFE66B6B);
      default:
        return Colors.white70;
    }
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

  String _formatDateLabel(DateTime? date) {
    if (date == null) {
      return 'Sin fecha';
    }
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatDateTimeLabel(DateTime? date) {
    if (date == null) {
      return 'Sin registro';
    }
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  String _formatRemaining(DateTime? date) {
    if (date == null) {
      return 'Sin fecha estimada';
    }
    final int days = date.difference(DateTime.now()).inDays;
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
      return Scaffold(
        backgroundColor: _primaryColor,
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

            return Column(
              children: [
                _buildHeader(isCompact: isCompact),
                _buildSearchAndWelcome(isCompact: isCompact),
                _buildTopMenuBar(isCompact: isCompact),
                Expanded(
                  child: Container(
                    width: double.infinity,
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
          },
        ),
      ),
    );
  }
}
