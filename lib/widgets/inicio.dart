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
  
  // User profile data
  String _userName = 'Usuario';
  String _userCompany = 'Empresa';
  String? _userProfileImage;
  List<Map<String, String>> _userStats = [];
  String _userEmail = '';
  String _userPhone = '';

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
      } else {
        // Usar datos de ejemplo
        _documents = _exampleDocuments();
        _paymentDates = null;
      }
    } catch (e) {
      print('Error cargando documentos: $e');
      _documents = _exampleDocuments();
      _paymentDates = null;
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
      final List<dynamic> documentsList = jsonData['documents'];

      _documents = {};
      _paymentDates = {};

      for (var doc in documentsList) {
        final String name = doc['name'];
        final DateTime expiryDate = DateTime.parse(doc['expiryDate']);
        final DateTime paymentDate = DateTime.parse(doc['paymentDate']);

        _documents[name] = expiryDate;
        _paymentDates![name] = paymentDate;
      }
    } catch (e) {
      print('Error parsing JSON: $e');
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
        if (jsonData['users'] != null) {
          final List<dynamic> users = jsonData['users'];
          if (widget.userId != null) {
            // Buscar usuario por ID
            userData = users.firstWhere(
              (user) => user['id'].toString() == widget.userId,
              orElse: () => users.isNotEmpty ? users[0] : null,
            );
          } else {
            // Si no hay ID, tomar el primero
            userData = users.isNotEmpty ? users[0] : null;
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
            _userEmail = userData['email'] ?? '';
            _userPhone = userData['phone'] ?? '';
            
            if (userData['stats'] != null) {
              _userStats = (userData['stats'] as List)
                  .map((stat) => {
                        'value': stat['value'].toString(),
                        'label': stat['label'].toString(),
                      })
                  .toList();
            }
          });
        }
      }
    } catch (e) {
      print('Error cargando perfil de usuario: $e');
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
                child: Icon(Icons.person, size: 35, color: Colors.white70),
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
          // Estadísticas
          Row(
            children: _userStats.isEmpty
                ? [
                    Expanded(child: _buildStatCard('16', 'Años en la\nempresa')),
                    Container(width: 1, height: 60, color: Colors.white30),
                    Expanded(child: _buildStatCard('10', 'Años\nmanejando')),
                    Container(width: 1, height: 60, color: Colors.white30),
                    Expanded(child: _buildStatCard('16', 'Años en la\nempresa')),
                  ]
                : _buildStatsFromData(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatsFromData() {
    List<Widget> widgets = [];
    for (int i = 0; i < _userStats.length; i++) {
      if (i > 0) {
        widgets.add(Container(width: 1, height: 60, color: Colors.white30));
      }
      widgets.add(
        Expanded(
          child: _buildStatCard(
            _userStats[i]['value']!,
            _userStats[i]['label']!,
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildStatCard(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bienvenido, Propietario', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Información de rendimiento de tus activos.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        _infoCard(Icons.account_balance_wallet, 'Ingresos', '\u0002 24K'),
      ]),
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
}

// A small reusable countdown + circular progress widget for documents.
class DocumentCountdown extends StatefulWidget {
  final DateTime expiry;
  final DateTime? paymentDate; // Fecha de pago
  final Duration totalDuration; // the total period to compute progress from
  final String title;
  final String subtitle;
  final double size;

  const DocumentCountdown({
    Key? key,
    required this.expiry,
    this.paymentDate,
    required this.totalDuration,
    this.title = '',
    this.subtitle = '',
    this.size = 120,
  }) : super(key: key);

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
