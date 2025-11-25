import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'document_modal.dart';

class InicioWidget extends StatefulWidget {
  final String? role;
  // Optional: pass document expiry dates from parent (from DB)
  final Map<String, DateTime>? documents;
  final String? jsonPath; // Ruta al archivo JSON
  final String? userProfilePath; // Ruta al JSON del perfil
  final String? userId; // ID del usuario a cargar

  const InicioWidget({
    Key? key,
    this.role,
    this.documents,
    this.jsonPath,
    this.userProfilePath,
    this.userId,
  }) : super(key: key);

  @override
  State<InicioWidget> createState() => _InicioWidgetState();
}

class _InicioWidgetState extends State<InicioWidget> {
  late String _role;
  // documents[name] = expiryDate
  late Map<String, DateTime> _documents;
  Map<String, DateTime>? _paymentDates; // Fechas de pago
  bool _isLoading = true;
  List<Map<String, dynamic>> _fleetVehicles = [];
  Map<String, String> _documentVehicle = {};
  
  // User profile data
  String _userName = 'Usuario';
  String _userCompany = 'Empresa';
  String? _userProfileImage;

  @override
  void initState() {
    super.initState();
    _role = widget.role ?? '';
    _loadDocuments();
    _loadUserProfile();
  }

  Future<void> _loadDocuments() async {
    try {
      if (widget.jsonPath != null) {
        // Cargar desde archivo JSON
        await _loadFromJson(widget.jsonPath!);
      } else if (widget.documents != null) {
        // Usar documentos proporcionados
        _documents = widget.documents!;
        _paymentDates = null;
        _documentVehicle = {};
      } else {
        // Usar datos de ejemplo
        _documents = _exampleDocuments();
        _paymentDates = null;
        _documentVehicle = {};
      }
    } catch (e) {
      debugPrint('Error cargando documentos: $e');
      _documents = _exampleDocuments();
      _paymentDates = null;
      _documentVehicle = {};
    }

    if (_fleetVehicles.isEmpty) {
      _fleetVehicles = _mockFleetVehicles();
    }

    setState(() {
      _isLoading = false;
    });

    // You would replace `_exampleDocuments` with a real fetch from your API
    if (_role.isEmpty) {
      // Delay showing the picker until after build
      WidgetsBinding.instance.addPostFrameCallback((_) => _askForRole());
    }
  }

  Future<void> _loadFromJson(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final Map<String, DateTime> docs = {};
      final Map<String, DateTime> payments = {};
      final Map<String, String> docVehicles = {};

      final documentsList = jsonData['documents'];
      if (documentsList is List) {
        for (final rawDoc in documentsList) {
          if (rawDoc is Map<String, dynamic>) {
            final String? name = rawDoc['name']?.toString();
            final String? expiryStr = rawDoc['expiryDate']?.toString();
            if (name == null || expiryStr == null) continue;

            final DateTime? expiryDate = DateTime.tryParse(expiryStr);
            if (expiryDate == null) continue;
            docs[name] = expiryDate;

            final String? paymentStr = rawDoc['paymentDate']?.toString();
            final DateTime? paymentDate = paymentStr != null && paymentStr.isNotEmpty ? DateTime.tryParse(paymentStr) : null;
            if (paymentDate != null) {
              payments[name] = paymentDate;
            }

            final String? vehicle = rawDoc['vehicle']?.toString();
            if (vehicle != null && vehicle.isNotEmpty) {
              docVehicles[name] = vehicle;
            }
          }
        }
      }

      final vehiclesList = jsonData['vehicles'];
      if (vehiclesList is List) {
        final List<Map<String, dynamic>> parsedVehicles = [];
        for (final rawVehicle in vehiclesList) {
          if (rawVehicle is Map<String, dynamic>) {
            final String? nextExpiryStr = rawVehicle['nextExpiry']?.toString();
            final DateTime? nextExpiry = nextExpiryStr != null && nextExpiryStr.isNotEmpty ? DateTime.tryParse(nextExpiryStr) : null;
            parsedVehicles.add({
              'plate': rawVehicle['plate'] ?? '',
              'model': rawVehicle['model'] ?? '',
              'driver': rawVehicle['driver'] ?? '',
              'status': rawVehicle['status'] ?? '',
              'nextExpiry': nextExpiry,
            });
          }
        }
        if (parsedVehicles.isNotEmpty) {
          _fleetVehicles = parsedVehicles;
        }
      }

      if (docs.isNotEmpty) {
        _documents = docs;
      } else {
        _documents = _exampleDocuments();
      }

      _paymentDates = payments.isEmpty ? null : payments;
      _documentVehicle = docVehicles;
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      rethrow;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      if (widget.userProfilePath != null) {
        final String jsonString = await rootBundle.loadString(widget.userProfilePath!);
        final Map<String, dynamic> jsonData = json.decode(jsonString);
        
        // Buscar el usuario por ID
        Map<String, dynamic>? userData;
        List<dynamic>? records;
        if (jsonData['users'] != null) {
          records = jsonData['users'];
        } else if (jsonData['owners'] != null) {
          records = jsonData['owners'];
        }

        if (records != null) {
          if (widget.userId != null) {
            userData = records.firstWhere(
              (item) => item['id'].toString() == widget.userId,
              orElse: () => records!.isNotEmpty ? records[0] : null,
            );
          } else {
            userData = records.isNotEmpty ? records[0] : null;
          }
        } else {
          // Formato antiguo sin array de usuarios
          userData = jsonData;
        }

        if (userData != null) {
          setState(() {
            _userName = userData!['name'] ?? 'Usuario';
            _userCompany = userData['company'] ?? 'Empresa';
            _userProfileImage = userData['profileImage'];
            
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando perfil de usuario: $e');
    }
  }

  Map<String, DateTime> _exampleDocuments() {
    final now = DateTime.now();
    return {
      'SOAT': now.add(const Duration(days: 12)),
      'Tecno': now.add(const Duration(days: 45)),
      'Matricula': now.add(const Duration(days: 80)),
      'Seguro': now.add(const Duration(days: 200)),
    };
  }

  List<Map<String, dynamic>> _mockFleetVehicles() {
    final now = DateTime.now();
    return [
      {
        'plate': 'ABC-123',
        'model': 'Chevrolet NHR 2023',
        'driver': 'Donal Glover',
        'status': 'Al día',
        'nextExpiry': now.add(const Duration(days: 25)),
        'lastService': now.subtract(const Duration(days: 40)),
        'mileage': 54000,
      },
      {
        'plate': 'JKL-456',
        'model': 'Hino Dutro 2021',
        'driver': 'María González',
        'status': 'Documentos pendientes',
        'nextExpiry': now.add(const Duration(days: 10)),
        'lastService': now.subtract(const Duration(days: 70)),
        'mileage': 68500,
      },
      {
        'plate': 'MNO-789',
        'model': 'Foton BJ 2020',
        'driver': 'Disponible',
        'status': 'En mantenimiento',
        'nextExpiry': now.add(const Duration(days: 60)),
        'lastService': now.subtract(const Duration(days: 12)),
        'mileage': 41200,
      },
    ];
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Return list of entries sorted by soonest expiry
  List<MapEntry<String, DateTime>> _upcomingDocs({int limit = 3}) {
    final entries = _documents.entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries.take(limit).toList();
  }

  Future<void> _askForRole() async {
    final choice = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Selecciona rol'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('Conductor'), onTap: () => Navigator.of(ctx).pop('Conductor')),
              ListTile(title: const Text('Empresa'), onTap: () => Navigator.of(ctx).pop('Empresa')),
              ListTile(title: const Text('Propietario'), onTap: () => Navigator.of(ctx).pop('Propietario')),
              ListTile(title: const Text('Secretaria'), onTap: () => Navigator.of(ctx).pop('Secretaria')),
              ListTile(title: const Text('Admin'), onTap: () => Navigator.of(ctx).pop('Admin')),
            ],
          ),
        );
      },
    );

    if (choice != null && mounted) {
      setState(() => _role = choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_role.isEmpty) {
      // Waiting for selection
      return const Center(child: SizedBox.shrink());
    }

    // Render role-specific content
    switch (_role.toLowerCase()) {
      case 'conductor':
        return _conductorInicio();
      case 'empresa':
        return _empresaInicio();
      case 'propietario':
        return _propietarioInicio();
      case 'secretaria':
        return _secretariaInicio();
      case 'admin':
      default:
        return _adminInicio();
    }
  }

  Widget _conductorInicio() {
    // Example data: replace with DB values when integrating

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top image area: larger vehicle image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            // Imagen más grande (doble tamaño)
            height: 200,
            color: Colors.transparent,
            child: Image.asset(
              'assets/vehicles.webp',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal list of upcoming document countdowns
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _upcomingDocs(limit: 3).map((e) {
                final name = e.key;
                final expiry = e.value;
                final paymentDate = _paymentDates?[name];
                final daysRemaining = expiry.difference(DateTime.now()).inDays;
                final totalDays = daysRemaining <= 90 ? 90 : daysRemaining;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SizedBox(
                    width: 120,
                    child: GestureDetector(
                      onTap: () => DocumentModal.show(
                        context: context,
                        documentName: name,
                        paymentDate: paymentDate,
                        expiryDate: expiry,
                      ),
                      child: DocumentCountdown(
                        expiry: expiry,
                        paymentDate: paymentDate,
                        totalDuration: Duration(days: totalDays),
                        title: name,
                        subtitle: '${daysRemaining.clamp(0, 999)} días',
                        size: 90,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: _buildUserProfile(),
        ),
      ]),
    );
  }

  Widget _buildUserProfile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header con foto, nombre y botones
          Row(
            children: [
              // Foto de perfil
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                backgroundImage: _userProfileImage != null && _userProfileImage!.isNotEmpty
                    ? AssetImage(_userProfileImage!)
                    : null,
                child: _userProfileImage == null || _userProfileImage!.isEmpty
                    ? const Icon(Icons.person, size: 35, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 12),
              // Nombre y empresa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userCompany,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Botones de acción
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF16C79A),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(Icons.person, color: Colors.white),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF16C79A),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(Icons.email, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Línea divisoria
          Container(
            height: 1,
            color: Colors.white30,
          ),
          const SizedBox(height: 12),
          // Accesos rápidos relevantes para el conductor
          const SizedBox(height: 12),
          Builder(
            builder: (_) {
              final bool showPaymentCard = _role.toLowerCase() != 'propietario';
              final children = <Widget>[
                Expanded(child: _buildQuickAccessCard(Icons.folder_open, 'Ver\ndocumentos', _showDocumentsOverview)),
              ];
              if (showPaymentCard) {
                children
                  ..add(const SizedBox(width: 12))
                  ..add(Expanded(child: _buildQuickAccessCard(Icons.payments, 'Pagos\npendientes', _showPaymentSchedule)));
              }
              return Row(children: children);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentsOverview() {
    final entries = _documents.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final sheetChildren = <Widget>[
      Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Documentos del conductor',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
    ];

    if (entries.isEmpty) {
      sheetChildren.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No hay documentos registrados.', style: TextStyle(color: Colors.white70)),
      ));
    } else {
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final expiry = entry.value;
        final payment = _paymentDates?[entry.key];
        final days = expiry.difference(DateTime.now()).inDays;
        final details = <String>['Vence: ${_formatDate(expiry)}'];
        if (payment != null) details.add('Pago: ${_formatDate(payment)}');

        if (i > 0) {
          sheetChildren.add(const Divider(color: Colors.white24, height: 24));
        }

        sheetChildren.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.description, color: Colors.white),
            ),
            title: Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${details.join(' • ')}\n${days.clamp(0, 999)} días restantes',
              style: const TextStyle(color: Colors.white70, height: 1.2),
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.of(context).pop();
              DocumentModal.show(
                context: context,
                documentName: entry.key,
                paymentDate: payment,
                expiryDate: expiry,
              );
            },
          ),
        );
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1445),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sheetChildren,
            ),
          ),
        );
      },
    );
  }

  void _showPaymentSchedule() {
    final entries = (_paymentDates ?? {}).entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final sheetChildren = <Widget>[
      Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Próximos pagos',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
    ];

    if (entries.isEmpty) {
      sheetChildren.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No hay pagos programados.', style: TextStyle(color: Colors.white70)),
      ));
    } else {
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final relatedExpiry = _documents[entry.key];

        if (i > 0) {
          sheetChildren.add(const Divider(color: Colors.white24, height: 24));
        }

        sheetChildren.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.payments, color: Colors.white),
            ),
            title: Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Pago: ${_formatDate(entry.value)}${relatedExpiry != null ? '\nVence: ${_formatDate(relatedExpiry)}' : ''}',
              style: const TextStyle(color: Colors.white70, height: 1.2),
            ),
            isThreeLine: relatedExpiry != null,
            onTap: () {
              Navigator.of(context).pop();
              if (relatedExpiry != null) {
                DocumentModal.show(
                  context: context,
                  documentName: entry.key,
                  paymentDate: entry.value,
                  expiryDate: relatedExpiry,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No hay fecha de vencimiento para ${entry.key}'),
                    backgroundColor: const Color(0xFF16C79A),
                  ),
                );
              }
            },
          ),
        );
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1445),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sheetChildren,
            ),
          ),
        );
      },
    );
  }

  Widget _empresaInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Panel Empresa', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Control y métricas de la flota.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        _infoCard(Icons.people, 'Conductores', '34'),
        const SizedBox(height: 12),
        _infoCard(Icons.insert_drive_file, 'Documentos por revisar', '5'),
      ]),
    );
  }

  Widget _propietarioInicio() {
    final totalVehicles = _fleetVehicles.length;
    final docsExpiringSoon = _documents.entries
        .where((entry) => entry.value.isBefore(DateTime.now().add(const Duration(days: 30))))
        .length;
    final vehiclesToShow = _fleetVehicles.take(3).toList();
    final upcomingDocs = _buildVehicleDocumentCountdowns(limit: 4);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.transparent,
                    child: Image.asset(
                      'assets/vehicles.webp',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Panel Propietario', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Resumen de tu flota y próximos vencimientos.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildSummaryChip(Icons.directions_bus, '$totalVehicles vehículos', 'Activos registrados'),
                        _buildSummaryChip(Icons.warning_amber_rounded, '$docsExpiringSoon vencimientos', 'Próximos 30 días'),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                if (upcomingDocs.isNotEmpty) ...[
                  const Text('Documentos próximos a vencer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: upcomingDocs,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _showDocumentsOverview,
                        icon: const Icon(Icons.folder_copy, color: Color(0xFF16C79A)),
                        label: const Text('Ver todos los documentos', style: TextStyle(color: Color(0xFF16C79A))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Vehículos asignados', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ListView.separated(
                      itemCount: vehiclesToShow.length,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final vehicle = vehiclesToShow[index];
                        return _buildVehicleCard(vehicle);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.directions_car, color: Colors.white),
                      label: const Text('Ver todos los vehículos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ver todos los vehículos aún no está disponible.')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secretariaInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Panel Secretaría', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Tareas administrativas y solicitudes.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        _infoCard(Icons.request_page, 'Solicitudes nuevas', '8'),
      ]),
    );
  }

  Widget _adminInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Panel Admin', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Vista global del sistema.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        _infoCard(Icons.settings, 'Configuraciones', ''),
      ]),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.white24, child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white))),
          if (value.isNotEmpty) Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF16C79A), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVehicleDocumentCountdowns({int limit = 3}) {
    final entries = _documents.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return entries.take(limit).map((entry) {
      final paymentDate = _paymentDates?[entry.key];
      final vehicleName = _documentVehicle[entry.key] ?? 'Vehículo sin asignar';
      final expiry = entry.value;
      final daysRemaining = expiry.difference(DateTime.now()).inDays;
      final totalDays = daysRemaining <= 90 ? 90 : daysRemaining;
      return Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: SizedBox(
          width: 110,
          child: GestureDetector(
            onTap: () => DocumentModal.show(
              context: context,
              documentName: entry.key,
              paymentDate: paymentDate,
              expiryDate: expiry,
            ),
            child: DocumentCountdown(
              expiry: expiry,
              paymentDate: paymentDate,
              totalDuration: Duration(days: totalDays),
              title: entry.key,
              subtitle: '$vehicleName\n${daysRemaining.clamp(0, 999)} días',
              size: 92,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final DateTime? nextExpiry = vehicle['nextExpiry'] as DateTime?;

    Color statusColor;
    switch ((vehicle['status'] as String).toLowerCase()) {
      case 'al día':
        statusColor = const Color(0xFF16C79A);
        break;
      case 'documentos pendientes':
        statusColor = const Color(0xFFEFB549);
        break;
      case 'en mantenimiento':
        statusColor = const Color(0xFFE66B6B);
        break;
      default:
        statusColor = Colors.white54;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white12,
            child: Text(
              (vehicle['plate'] as String).split('-').first,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(vehicle['plate'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        vehicle['status'] as String,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildVehicleInfoRow('Modelo', vehicle['model'] as String),
                _buildVehicleInfoRow('Conductor', vehicle['driver'] as String),
                if (nextExpiry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildVehicleInfoRow('Próximo vencimiento', _formatDate(nextExpiry)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
            onPressed: () {
              if (nextExpiry != null) {
                DocumentModal.show(
                  context: context,
                  documentName: 'Ficha vehículo ${vehicle['plate']}',
                  expiryDate: nextExpiry,
                  paymentDate: null,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No hay documento asociado para ${vehicle['plate']}'),
                    backgroundColor: const Color(0xFF16C79A),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

}

// A small reusable countdown + circular progress widget for documentos.

class DocumentCountdown extends StatefulWidget {
  final DateTime expiry;
  final DateTime? paymentDate; // Fecha de pago
  final Duration totalDuration; // the total period to compute progress from
  final String title;
  final String subtitle;
  final double size;

  const DocumentCountdown({
    super.key,
    required this.expiry,
    this.paymentDate,
    required this.totalDuration,
    this.title = '',
    this.subtitle = '',
    this.size = 120,
  });

  @override
  State<DocumentCountdown> createState() => _DocumentCountdownState();
}

class _DocumentCountdownState extends State<DocumentCountdown> {
  late Duration _remaining;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _updateRemaining() {
    final now = DateTime.now();
    _remaining = widget.expiry.difference(now);
    if (_remaining.isNegative) _remaining = Duration.zero;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _updateRemaining();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalDuration.inSeconds > 0 ? widget.totalDuration.inSeconds : 1;
    final remain = _remaining.inSeconds.clamp(0, total);
    final percent = total > 0 ? (remain / total) : 0.0;

    // Render a circular ring with numeric remaining time
    final double size = widget.size;
    final double stroke = (size / 8).clamp(8.0, 20.0);
    return Column(
      children: [
        SizedBox(
          height: size + 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: stroke,
                  color: const Color(0xFF16C79A),
                  backgroundColor: Colors.white24,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatRemaining(_remaining), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: (size / 6).clamp(12.0, 18.0))),
                  const SizedBox(height: 4),
                  Text(_humanUnit(_remaining), style: TextStyle(color: Colors.white70, fontSize: (size / 10).clamp(10.0, 12.0))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  String _formatRemaining(Duration d) {
    if (d == Duration.zero) return '0';
    if (d.inDays >= 1) return '${d.inDays}';
    if (d.inHours >= 1) return '${d.inHours}';
    if (d.inMinutes >= 1) return '${d.inMinutes}';
    return '${d.inSeconds}';
  }

  String _humanUnit(Duration d) {
    if (d == Duration.zero) return 'expirado';
    if (d.inDays >= 1) return '/ días';
    if (d.inHours >= 1) return '/ horas';
    if (d.inMinutes >= 1) return '/ minutos';
    return '/ segundos';
  }
}
