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
  final VoidCallback? onNavigateToDocuments;
  final VoidCallback? onNavigateToPayments;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToMessages;

  const InicioWidget({
    super.key,
    this.role,
    this.documents,
    this.jsonPath,
    this.userProfilePath,
    this.userId,
    this.onNavigateToDocuments,
    this.onNavigateToPayments,
    this.onNavigateToProfile,
    this.onNavigateToMessages,
  });

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
          String? profileImageCandidate;
          final dynamic rawImage = userData['profileImage'];
          if (rawImage is String && rawImage.isNotEmpty) {
            final bool assetExists = await _assetExists(rawImage);
            if (assetExists) {
              profileImageCandidate = rawImage;
            } else {
              debugPrint('Imagen de perfil no encontrada: $rawImage. Se usará el ícono por defecto.');
            }
          }

          if (mounted) {
            setState(() {
              _userName = userData!['name'] ?? 'Usuario';
              _userCompany = userData['company'] ?? 'Empresa';
              _userProfileImage = profileImageCandidate;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando perfil de usuario: $e');
    }
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      return false;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_role.isEmpty) {
      return _buildRoleSelectionLanding();
    }

    final Widget roleContent = _buildRoleContent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: roleContent),
      ],
    );
  }

  Widget _buildRoleContent() {
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
        return _adminInicio();
    }
    return _adminInicio();
  }

  Widget _buildRoleSelectionLanding() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.dashboard_customize, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Selecciona un rol para explorar su panel.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16
          ),
        ],
      ),
    );
  }

  Widget _conductorInicio() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 480;
        final double imageHeight = isCompact ? 160 : 200;
        final double countdownSize = isCompact ? 80 : 90;
        final double countdownWidth = isCompact ? 108 : 120;
        final EdgeInsets outerPadding = EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 20,
          vertical: 20,
        );
        final List<MapEntry<String, DateTime>> upcoming = _upcomingDocs(limit: 3);

        return SingleChildScrollView(
          padding: outerPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: imageHeight,
                      color: Colors.transparent,
                      child: Image.asset(
                        'assets/vehicles.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 12 : 16),
                  if (upcoming.isNotEmpty)
                    Align(
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < upcoming.length; i++)
                              Padding(
                                padding: EdgeInsets.only(right: i == upcoming.length - 1 ? 0 : 12),
                                child: SizedBox(
                                  width: countdownWidth,
                                  child: GestureDetector(
                                    onTap: () {
                                      final entry = upcoming[i];
                                      final paymentDate = _paymentDates?[entry.key];
                                      DocumentModal.show(
                                        context: context,
                                        documentName: entry.key,
                                        paymentDate: paymentDate,
                                        expiryDate: entry.value,
                                      );
                                    },
                                    child: DocumentCountdown(
                                      expiry: upcoming[i].value,
                                      paymentDate: _paymentDates?[upcoming[i].key],
                                      totalDuration: Duration(
                                        days: upcoming[i].value.difference(DateTime.now()).inDays <= 90
                                            ? 90
                                            : upcoming[i].value.difference(DateTime.now()).inDays,
                                      ),
                                      title: upcoming[i].key,
                                      subtitle:
                                          '${upcoming[i].value.difference(DateTime.now()).inDays.clamp(0, 999)} días',
                                      size: countdownSize,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: isCompact ? 18 : 24),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _buildUserProfile(isCompact: isCompact),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserProfile({required bool isCompact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stackActions = constraints.maxWidth < 360;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24, width: 1.4),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 18,
            vertical: isCompact ? 14 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _handleViewProfile,
                    child: CircleAvatar(
                      radius: isCompact ? 28 : 30,
                      backgroundColor: Colors.white24,
                      backgroundImage: _userProfileImage != null && _userProfileImage!.isNotEmpty
                          ? AssetImage(_userProfileImage!)
                          : null,
                      child: _userProfileImage == null || _userProfileImage!.isEmpty
                          ? const Icon(Icons.person, size: 34, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 17 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userCompany,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isCompact ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!stackActions) ...[
                    const SizedBox(width: 12),
                    _buildProfileActions(centered: false),
                  ],
                ],
              ),
              if (stackActions) ...[
                const SizedBox(height: 12),
                _buildProfileActions(centered: true),
              ],
              const SizedBox(height: 14),
              const Divider(color: Colors.white24, thickness: 0.8, height: 1),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, boxConstraints) {
                  final bool stackQuickActions = boxConstraints.maxWidth < 420;
                  final bool showPaymentCard = _role.toLowerCase() != 'propietario';
                  final quickCards = <Widget>[
                    _buildQuickAccessCard(Icons.folder_open, 'Ver\ndocumentos', _handleViewDocuments),
                    if (showPaymentCard)
                      _buildQuickAccessCard(Icons.payments, 'Pagos\npendientes', _handleViewPayments),
                  ];

                  if (stackQuickActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < quickCards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          quickCards[i],
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: quickCards[0]),
                      if (quickCards.length > 1) ...[
                        const SizedBox(width: 12),
                        Expanded(child: quickCards[1]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessCard(IconData icon, String label, VoidCallback onTap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 180;
        final double iconSize = isCompact ? 22 : 24;
        final double fontSize = isCompact ? 12 : 13;
        final double verticalPadding = isCompact ? 16 : 18;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize + 16,
                  height: iconSize + 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(icon, color: Colors.white, size: iconSize),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label.replaceAll('\n', ' '),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileActions({required bool centered}) {
    final buttons = <Widget>[
      _buildProfileActionButton(Icons.chat_bubble_outline, _handleViewMessages),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.end,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
      ],
    );
  }

  Widget _buildProfileActionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF16C79A),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _handleViewDocuments() {
    if (widget.onNavigateToDocuments != null) {
      widget.onNavigateToDocuments!();
    } else {
      _showDocumentsOverview();
    }
  }

  void _handleViewPayments() {
    if (widget.onNavigateToPayments != null) {
      widget.onNavigateToPayments!();
    } else {
      _showPaymentSchedule();
    }
  }

  void _handleViewProfile() {
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      _showNavigationFallback('el perfil');
    }
  }

  void _handleViewMessages() {
    if (widget.onNavigateToMessages != null) {
      widget.onNavigateToMessages!();
    } else {
      _showNavigationFallback('los mensajes');
    }
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

  void _showNavigationFallback(String destination) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configura la navegación hacia $destination para continuar.'),
        backgroundColor: const Color(0xFF16C79A),
      ),
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

    final List<MapEntry<String, DateTime>> upcomingDocEntries = _documents.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final List<MapEntry<String, DateTime>> limitedUpcoming = upcomingDocEntries.take(3).toList();

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
                if (limitedUpcoming.isNotEmpty) ...[
                  const Text('Documentos próximos a vencer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _buildOwnerDocumentCountdowns(limitedUpcoming),
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

  Widget _buildOwnerDocumentCountdowns(List<MapEntry<String, DateTime>> docs) {
    const double spacing = 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        if (maxWidth.isInfinite || maxWidth <= 0) {
          maxWidth = MediaQuery.of(context).size.width;
        }

        int columns = docs.isEmpty ? 1 : docs.length;
        if (columns > 3) {
          columns = 3;
        }

        while (columns > 1) {
          final double candidateWidth = (maxWidth - spacing * (columns - 1)) / columns;
          if (candidateWidth >= 80) {
            break;
          }
          columns -= 1;
        }

        final double totalSpacing = spacing * (columns - 1);
        final double itemWidth = (maxWidth - totalSpacing) / columns;
        final double countdownSize = itemWidth.clamp(78.0, 110.0);

        return Align(
          alignment: Alignment.center,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.center,
            children: docs.map((entry) {
              final DateTime expiry = entry.value;
              final int daysRemaining = expiry.difference(DateTime.now()).inDays;
              final int totalDays = daysRemaining <= 90 ? 90 : daysRemaining;
              final DateTime? paymentDate = _paymentDates?[entry.key];
              final String vehicleName = _documentVehicle[entry.key] ?? 'Vehículo sin asignar';

              return SizedBox(
                width: itemWidth,
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
                    size: countdownSize,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
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
