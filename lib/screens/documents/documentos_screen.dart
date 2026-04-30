import 'package:flutter/material.dart';
import 'package:frontendproyecto/services/api_service.dart';
import 'package:frontendproyecto/services/document_service.dart';
import 'package:frontendproyecto/widgets/document_preview_modal.dart';
import 'package:frontendproyecto/widgets/shimmer_skeleton.dart';
import 'package:frontendproyecto/widgets/upload_document_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentosScreen extends StatefulWidget {
  final String? role;
  final String? userId;
  final String? token;
  final bool canUpload;

  const DocumentosScreen({
    super.key,
    this.role,
    this.userId,
    this.token,
    this.canUpload = false,
  });

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

enum _DocumentosFlowView { home, people, personDetail, vehicles, vehicleDetail }

class _DocumentosScreenState extends State<DocumentosScreen> {
  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  bool _isLoading = true;
  String? _errorMessage;
  _DocumentosFlowView _view = _DocumentosFlowView.home;
  String _activePersonTab = 'Conductores';
  String _searchQuery = '';
  late List<_PersonSummary> _persons;
  late List<_VehicleSummary> _vehicles;
  _PersonSummary? _selectedPerson;
  _VehicleSummary? _selectedVehicle;
  String? _authToken;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _persons = [];
    _vehicles = [];
    _loadExplorerData();
  }

  Future<void> _loadExplorerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? token = widget.token;

      if (token == null || token.isEmpty) {
        token = await DocumentService.getToken();
      }

      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth_token');
      }

      _authToken = token;

      final results = await Future.wait([
        ApiService.getUsuarios(),
        ApiService.getVehiculos(),
        DocumentService.getCompanyDocuments(token: token),
      ]);

      final List<Map<String, dynamic>> users = results[0];
      final List<Map<String, dynamic>> vehicles = results[1];
      final List<Map<String, dynamic>> documents = results[2];

      final List<_DocumentEntry> documentEntries = documents
          .map((document) => _DocumentEntry.fromMap(document))
          .toList();

      final filteredEntries = _filterDocumentsByRole(documentEntries, vehicles);

      final role = widget.role?.toLowerCase() ?? '';
      final isEmpresa = role == 'empresa';

      final visibleUsers = isEmpresa
          ? users
          : users.where((user) {
              final id =
                  _valueAsString(user['id']) ??
                  _valueAsString(user['idUsuario']) ??
                  '';
              return id == widget.userId;
            }).toList();

      final visibleVehicles = isEmpresa
          ? vehicles
          : vehicles.where((vehicle) {
              final vehicleId =
                  _valueAsString(vehicle['id']) ??
                  _valueAsString(vehicle['vehiculoId']) ??
                  _valueAsString(vehicle['id_vehiculo']) ??
                  '';

              return filteredEntries.any((doc) => doc.vehicleId == vehicleId);
            }).toList();

      _persons = _buildPersonSummaries(
        visibleUsers,
        visibleVehicles,
        filteredEntries,
      );

      _vehicles = _buildVehicleSummaries(visibleVehicles, filteredEntries);

      if (!isEmpresa) {
        final currentUserId = (widget.userId ?? '').trim();

        _persons = _persons.where((p) => p.id == currentUserId).toList();

        if (_persons.isNotEmpty) {
          _selectedPerson = _persons.first;
        }
      }
    } catch (error) {
      debugPrint('❌ Error cargando datos de documentos: $error');
      _errorMessage =
          'No se pudieron cargar los datos de documentos. Intenta nuevamente.';
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  List<_DocumentEntry> _filterDocumentsByRole(
    List<_DocumentEntry> documents,
    List<Map<String, dynamic>> vehicles,
  ) {
    final role = widget.role?.toLowerCase() ?? '';
    final currentUserId = (widget.userId ?? '').trim();

    debugPrint('ROL DOCUMENTOS: $role');
    debugPrint('USER ID DOCUMENTOS: $currentUserId');

    if (role == 'empresa' || currentUserId.isEmpty) {
      return documents;
    }

    final assignedVehicleIds = <String>{};

    for (final vehicle in vehicles) {
      final vehicleId =
          _valueAsString(vehicle['id']) ??
          _valueAsString(vehicle['vehiculoId']) ??
          _valueAsString(vehicle['id_vehiculo']) ??
          '';

      final conductor = vehicle['conductor'];
      if (conductor is Map) {
        final usuario = conductor['usuario'];
        final conductorUserId = usuario is Map
            ? _valueAsString(usuario['id']) ??
                  _valueAsString(usuario['idUsuario']) ??
                  ''
            : '';
        if (conductorUserId == currentUserId && vehicleId.isNotEmpty) {
          assignedVehicleIds.add(vehicleId);
        }
      }

      final propietario = vehicle['propietario'];
      if (propietario is Map) {
        final usuario = propietario['usuario'];
        final propietarioUserId = usuario is Map
            ? _valueAsString(usuario['id']) ??
                  _valueAsString(usuario['idUsuario']) ??
                  ''
            : '';
        if (propietarioUserId == currentUserId && vehicleId.isNotEmpty) {
          assignedVehicleIds.add(vehicleId);
        }
      }
    }

    return documents.where((doc) {
      final isOwnPersonalDocument =
          doc.ownerId == currentUserId && doc.vehicleId.isEmpty;

      final isAssignedVehicleDocument =
          doc.vehicleId.isNotEmpty &&
          assignedVehicleIds.contains(doc.vehicleId);

      return isOwnPersonalDocument || isAssignedVehicleDocument;
    }).toList();
  }

  List<_PersonSummary> _buildPersonSummaries(
    List<Map<String, dynamic>> users,
    List<Map<String, dynamic>> vehicles,
    List<_DocumentEntry> documents,
  ) {
    final Map<String, _PersonSummary> persons = {};

    for (final user in users) {
      final String id =
          _valueAsString(user['id']) ?? _valueAsString(user['idUsuario']) ?? '';
      if (id.isEmpty) continue;
      final String firstName = _valueAsString(user['nombre']) ?? '';
      final String lastName = _valueAsString(user['apellido']) ?? '';
      final String fullName = '$firstName $lastName'.trim();
      final String documentNumber =
          _valueAsString(user['numeroDocumento']) ??
          _valueAsString(user['numero_documento']) ??
          _valueAsString(user['documento']) ??
          '';
      final Set<String> roles = <String>{};
      final String userRoleRaw =
          _valueAsString(user['rol']) ??
          _valueAsString(user['tipoUsuario']) ??
          '';
      if (userRoleRaw.toLowerCase().contains('conductor')) {
        roles.add('Conductores');
      }
      if (userRoleRaw.toLowerCase().contains('propietario')) {
        roles.add('Propietarios');
      }

      persons[id] = _PersonSummary(
        id: id,
        fullName: fullName.isEmpty ? 'Sin nombre' : fullName,
        documentNumber: documentNumber,
        roles: roles,
        vehiclePlates: [],
        documents: [],
      );
    }

    for (final vehicle in vehicles) {
      final String plate = _valueAsString(vehicle['placa']) ?? 'Sin placa';
      final String model = _valueAsString(vehicle['modelo']) ?? '';
      final String brand = _valueAsString(vehicle['marca']) ?? '';
      final String label = [
        brand,
        model,
      ].where((part) => part.isNotEmpty).join(' ').trim();
      final String vehicleLabel = label.isEmpty ? plate : '$label • $plate';

      final dynamic conductor = vehicle['conductor'];
      if (conductor is Map) {
        final dynamic usuario = conductor['usuario'];
        if (usuario is Map) {
          final String id =
              _valueAsString(usuario['id']) ??
              _valueAsString(usuario['idUsuario']) ??
              '';
          if (id.isNotEmpty) {
            final person =
                persons[id] ??
                _PersonSummary(
                  id: id,
                  fullName: _fullNameFromMap(usuario),
                  documentNumber: _documentFromMap(usuario),
                  roles: {'Conductores'},
                  vehiclePlates: [],
                  documents: [],
                );
            person.roles.add('Conductores');
            person.vehiclePlates.add(vehicleLabel);
            persons[id] = person;
          }
        }
      }

      final dynamic propietario = vehicle['propietario'];
      if (propietario is Map) {
        final dynamic usuario = propietario['usuario'];
        if (usuario is Map) {
          final String id =
              _valueAsString(usuario['id']) ??
              _valueAsString(usuario['idUsuario']) ??
              '';
          if (id.isNotEmpty) {
            final person =
                persons[id] ??
                _PersonSummary(
                  id: id,
                  fullName: _fullNameFromMap(usuario),
                  documentNumber: _documentFromMap(usuario),
                  roles: {'Propietarios'},
                  vehiclePlates: [],
                  documents: [],
                );
            person.roles.add('Propietarios');
            person.vehiclePlates.add(vehicleLabel);
            persons[id] = person;
          }
        }
      }
    }

    for (final document in documents) {
      final String ownerId = document.ownerId;
      if (ownerId.isEmpty) continue;
      final person =
          persons[ownerId] ??
          _PersonSummary(
            id: ownerId,
            fullName: document.ownerName.isEmpty
                ? 'Persona desconocida'
                : document.ownerName,
            documentNumber: document.documentNumber,
            roles: {},
            vehiclePlates: [],
            documents: [],
          );
      person.documents.add(document);
      persons[ownerId] = person;
    }

    final List<_PersonSummary> summaries = persons.values
        .where((person) => person.roles.isNotEmpty)
        .toList();

    summaries.sort((a, b) => a.fullName.compareTo(b.fullName));
    return summaries;
  }

  List<_VehicleSummary> _buildVehicleSummaries(
    List<Map<String, dynamic>> vehicles,
    List<_DocumentEntry> documents,
  ) {
    final Map<String, _VehicleSummary> byVehicle = {};
    for (final vehicle in vehicles) {
      final String id =
          _valueAsString(vehicle['id']) ??
          _valueAsString(vehicle['vehiculoId']) ??
          _valueAsString(vehicle['id_vehiculo']) ??
          '';
      if (id.isEmpty) continue;
      final String plate = _valueAsString(vehicle['placa']) ?? 'Sin placa';
      final String brand = _valueAsString(vehicle['marca']) ?? '';
      final String model = _valueAsString(vehicle['modelo']) ?? '';
      final String imageUrl = _valueAsString(vehicle['imagen']) ?? '';
      final List<String> owners = [];
      final dynamic propietario = vehicle['propietario'];
      if (propietario is Map) {
        final ownerName = _fullNameFromMap(
          propietario['usuario'] ?? propietario,
        );
        if (ownerName.isNotEmpty) owners.add(ownerName);
      }
      final dynamic conductor = vehicle['conductor'];
      if (conductor is Map) {
        final conductorName = _fullNameFromMap(
          conductor['usuario'] ?? conductor,
        );
        if (conductorName.isNotEmpty) owners.add(conductorName);
      }
      byVehicle[id] = _VehicleSummary(
        id: id,
        plate: plate,
        brand: brand,
        model: model,
        imageUrl: imageUrl,
        owners: owners,
        documents: [],
      );
    }

    for (final document in documents) {
      final String vehicleId = document.vehicleId;
      if (vehicleId.isEmpty) continue;
      final vehicle = byVehicle[vehicleId];
      if (vehicle != null) {
        vehicle.documents.add(document);
      } else {
        byVehicle[vehicleId] = _VehicleSummary(
          id: vehicleId,
          plate: document.vehiclePlate.isEmpty
              ? 'Vehículo'
              : document.vehiclePlate,
          brand: '',
          model: '',
          imageUrl: '',
          owners: [],
          documents: [document],
        );
      }
    }

    final List<_VehicleSummary> summaries = byVehicle.values.toList();
    summaries.sort((a, b) => a.plate.compareTo(b.plate));
    return summaries;
  }

  static String? _valueAsString(dynamic value) {
    if (value == null) return null;
    return value.toString().trim();
  }

  static String _fullNameFromMap(dynamic map) {
    if (map is! Map) return '';
    final String firstName = _valueAsString(map['nombre']) ?? '';
    final String lastName = _valueAsString(map['apellido']) ?? '';
    return '$firstName $lastName'.trim();
  }

  static String _documentFromMap(dynamic map) {
    if (map is! Map) return '';
    return _valueAsString(map['numeroDocumento']) ??
        _valueAsString(map['numero_documento']) ??
        _valueAsString(map['documento']) ??
        '';
  }

  List<_PersonSummary> get _filteredPersons {
    final List<_PersonSummary> effective = _persons.where((person) {
      final bool matchesTab = person.roles.contains(_activePersonTab);
      if (!matchesTab) return false;
      if (_searchQuery.isEmpty) return true;
      final String needle = _searchQuery.toLowerCase();
      return person.fullName.toLowerCase().contains(needle) ||
          person.documentNumber.toLowerCase().contains(needle);
    }).toList();
    return effective;
  }

  void _showUploadModal() {
    if (widget.userId == null || widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el usuario para subir documentos'),
        ),
      );
      return;
    }

    UploadDocumentModal.show(
      context: context,
      userId: widget.userId!,
      userRole: widget.role ?? 'Empresa',
      token: _authToken,
      onSuccess: _loadExplorerData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      color: _surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );

    final isEmpresa = widget.role?.toLowerCase() == 'empresa';

    if (!isEmpresa || !widget.canUpload) {
      return content;
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            backgroundColor: _accentColor,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: _showUploadModal,
            icon: const Icon(Icons.upload_file),
            label: const Text('Subir documento'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool showBack = _view != _DocumentosFlowView.home;
    final String subtitle;
    switch (_view) {
      case _DocumentosFlowView.home:
        subtitle =
            'Explora documentos por tipo y accede rápido a la persona o el vehículo.';
        break;
      case _DocumentosFlowView.people:
        subtitle = 'Buscar conductores y propietarios por nombre o documento.';
        break;
      case _DocumentosFlowView.personDetail:
        subtitle =
            _selectedPerson?.fullName ??
            'Detalles de la persona y sus documentos.';
        break;
      case _DocumentosFlowView.vehicles:
        subtitle =
            'Selecciona un vehículo y revisa sus documentos en un diseño moderno.';
        break;
      case _DocumentosFlowView.vehicleDetail:
        subtitle =
            _selectedVehicle?.title ?? 'Ficha del vehículo y sus documentos.';
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack)
          IconButton(
            onPressed: _onBackPressed,
            icon: Icon(Icons.arrow_back, size: 28, color: Colors.white),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        if (!_isLoading)
          IconButton(
            onPressed: _loadExplorerData,
            icon: Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar datos',
          ),
      ],
    );
  }

  void _onBackPressed() {
    setState(() {
      final isEmpresa = widget.role?.toLowerCase() == 'empresa';

      if (!isEmpresa) {
        _view = _DocumentosFlowView.home;
        _selectedPerson = null;
        _selectedVehicle = null;
        _searchQuery = '';
        _showHistory = false;
        return;
      }

      if (_view == _DocumentosFlowView.personDetail) {
        _view = _DocumentosFlowView.people;
      } else if (_view == _DocumentosFlowView.vehicleDetail) {
        _view = _DocumentosFlowView.vehicles;
      } else {
        _view = _DocumentosFlowView.home;
      }

      _selectedPerson = null;
      _selectedVehicle = null;
      _searchQuery = '';
      _showHistory = false;
    });
  }

  Widget _buildContent() {
    if (_isLoading) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildLoadingSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red[700], fontSize: 16),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _buildCurrentView(),
    );
  }

  bool get _isEmpresa {
    return widget.role?.toLowerCase() == 'empresa';
  }

  Widget _buildCurrentView() {
    switch (_view) {
      case _DocumentosFlowView.home:
        return _buildHomeView();
      case _DocumentosFlowView.people:
        return _buildPeopleView();
      case _DocumentosFlowView.personDetail:
        return _buildPersonDetailView();
      case _DocumentosFlowView.vehicles:
        return _buildVehiclesView();
      case _DocumentosFlowView.vehicleDetail:
        return _buildVehicleDetailView();
    }
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // 🔹 Header falso
          const ShimmerSkeleton(width: 180, height: 22),
          const SizedBox(height: 6),
          const ShimmerSkeleton(width: 260, height: 14),

          const SizedBox(height: 20),

          // 🔹 Próximos a vencer (simulado)
          Row(
            children: List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: const [
                    ShimmerSkeleton(width: 70, height: 70, borderRadius: 35),
                    SizedBox(height: 8),
                    ShimmerSkeleton(width: 80, height: 12),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 🔹 Cards principales
          Column(
            children: List.generate(
              2,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: const ShimmerVehicleCard(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 🔹 Grid documentos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              mainAxisExtent: 140,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, __) => const ShimmerDocumentCard(),
          ),
        ],
      ),
    );
  }

  List<_DocumentEntry> get _upcomingDocuments {
    final allDocuments = [
      ..._persons.expand((p) => p.documents),
      ..._vehicles.expand((v) => v.documents),
    ];

    final uniqueDocs = <String, _DocumentEntry>{};

    for (final doc in allDocuments) {
      if (!doc.estadoDocumento) continue;
      if (doc.expiryDate == null) continue;

      uniqueDocs[doc.id] = doc;
    }

    final docs = uniqueDocs.values.toList();

    docs.sort((a, b) {
      if (a.daysRemaining < 0 && b.daysRemaining >= 0) return -1;
      if (a.daysRemaining >= 0 && b.daysRemaining < 0) return 1;
      return a.daysRemaining.compareTo(b.daysRemaining);
    });

    return docs.take(3).toList();
  }

  void _openPeopleSection() {
    if (_isEmpresa) {
      setState(() => _view = _DocumentosFlowView.people);
      return;
    }

    final currentUserId = (widget.userId ?? '').trim();

    final person = _persons.where((p) => p.id == currentUserId).isNotEmpty
        ? _persons.firstWhere((p) => p.id == currentUserId)
        : (_persons.isNotEmpty ? _persons.first : null);

    if (person != null) {
      setState(() {
        _selectedPerson = person;
        _view = _DocumentosFlowView.personDetail;
      });
    }
  }

  Widget _buildHomeView() {
    final upcomingDocs = _upcomingDocuments;

    return SingleChildScrollView(
      key: const ValueKey('home-view'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upcomingDocs.isNotEmpty) ...[
            const Center(
              child: Text(
                'Próximos a vencer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildUpcomingDocumentsRow(upcomingDocs),
            const SizedBox(height: 22),
          ],

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 2 : 1,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 2.6,
            children: [
              _buildHomeCard(
                icon: Icons.people_alt_rounded,
                title: 'Personas',
                subtitle: _isEmpresa
                    ? 'Conductores y propietarios'
                    : 'Mis documentos personales',
                accent: Colors.blue.shade700,
                onTap: _openPeopleSection,
              ),
              _buildHomeCard(
                icon: Icons.directions_car_rounded,
                title: 'Vehículos',
                subtitle: 'Tarjetas por placa, modelo y marca',
                accent: Colors.teal.shade700,
                onTap: () =>
                    setState(() => _view = _DocumentosFlowView.vehicles),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingDocumentsRow(List<_DocumentEntry> documents) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: documents.map((doc) {
          final color = _getExpiryColor(doc.daysRemaining);

          return InkWell(
            onTap: () => DocumentPreviewModal.show(
              context: context,
              documentName: doc.name,
              fileUrl: doc.url,
              expiryDate: doc.expiryDate,
              observations: doc.observations,
            ),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardColor.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: color.withValues(alpha: 0.16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          doc.daysRemaining < 0
                              ? '!'
                              : doc.remainingLabel.split(' ').first,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          doc.daysRemaining < 0
                              ? 'vencido'
                              : doc.daysRemaining < 30
                              ? 'días'
                              : doc.remainingLabel.contains('año')
                              ? 'año(s)'
                              : 'mes(es)',
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    doc.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.daysRemaining < 0
                        ? 'Documento vencido'
                        : 'Faltan ${doc.remainingLabel}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Vence: ${doc.formattedExpiry}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getExpiryColor(int daysRemaining) {
    if (daysRemaining < 0) return Colors.redAccent;
    if (daysRemaining <= 7) return Colors.redAccent;
    if (daysRemaining <= 15) return Colors.orangeAccent;
    if (daysRemaining <= 30) return _warningColor;
    return _successColor;
  }

  Widget _buildHomeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, _cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Explorar',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleView() {
    final persons = _filteredPersons;
    return Column(
      key: const ValueKey('people-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 14),
        _buildSegmentTabs(),
        const SizedBox(height: 18),
        Expanded(
          child: persons.isEmpty
              ? _buildEmptyState(
                  title: 'No se encontraron personas',
                  message: _searchQuery.isEmpty
                      ? 'Aún no existen conductores o propietarios en la empresa.'
                      : 'Ninguna persona coincide con la búsqueda.',
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: persons.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 800
                        ? 2
                        : 1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3.1,
                  ),
                  itemBuilder: (context, index) {
                    final person = persons[index];
                    return _buildPersonCard(person);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o número de documento',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        hintStyle: const TextStyle(color: Colors.white54),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSegmentTabs() {
    return Row(
      children: [
        _buildTabButton('Conductores'),
        const SizedBox(width: 12),
        _buildTabButton('Propietarios'),
      ],
    );
  }

  Widget _buildTabButton(String title) {
    final bool selected = title == _activePersonTab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activePersonTab = title),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? _accentColor
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _accentColor : Colors.white24),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonCard(_PersonSummary person) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPerson = person;
          _view = _DocumentosFlowView.personDetail;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _accentColor.withValues(alpha: 0.25),
              child: Text(
                person.initials,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    person.documentNumber.isNotEmpty
                        ? 'CC: ${person.documentNumber}'
                        : 'Documento no disponible',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person.subtitle,
                    style: TextStyle(color: Colors.white54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${person.documents.length} docs',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonDetailView() {
    final person = _selectedPerson;
    if (person == null) {
      return _buildEmptyState(
        title: 'Persona no encontrada',
        message: 'Selecciona una persona para ver sus documentos.',
      );
    }

    final visibleDocuments = person.documents
        .where(
          (doc) => _showHistory ? !doc.estadoDocumento : doc.estadoDocumento,
        )
        .toList();

    return Column(
      key: const ValueKey('person-detail-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.fullName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                person.documentNumber.isNotEmpty
                    ? 'Documento: ${person.documentNumber}'
                    : 'Documento no disponible',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Rol: ${person.roles.join(' / ')}',
                style: const TextStyle(color: Colors.white70),
              ),
              if (person.vehiclePlates.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Vehículos vinculados: ${person.vehiclePlates.join(' • ')}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _showHistory = !_showHistory;
            });
          },
          icon: Icon(
            _showHistory ? Icons.visibility : Icons.history,
            color: Colors.white,
          ),
          label: Text(
            _showHistory ? 'Ver documentos activos' : 'Ver historial',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showHistory ? Colors.orange : _accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: visibleDocuments.isEmpty
              ? _buildEmptyState(
                  title: 'Sin documentos',
                  message:
                      'Esta persona no tiene documentos asociados a la vista actual.',
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: visibleDocuments.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final document = visibleDocuments[index];
                    return _buildDocumentCard(document);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVehiclesView() {
    return Column(
      key: const ValueKey('vehicles-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _vehicles.isEmpty
              ? _buildEmptyState(
                  title: 'No hay vehículos',
                  message:
                      'No se encontraron vehículos asociados a la empresa.',
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _vehicles.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 900
                        ? 2
                        : 1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3.2,
                  ),
                  itemBuilder: (context, index) {
                    final vehicle = _vehicles[index];
                    return _buildVehicleCard(vehicle);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(_VehicleSummary vehicle) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedVehicle = vehicle;
          _view = _DocumentosFlowView.vehicleDetail;
        });
      },
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _successColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.directions_car_filled,
                size: 34,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.plate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicle.title,
                    style: TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  if (vehicle.owners.isNotEmpty)
                    Text(
                      'Propietario: ${vehicle.owners.join(', ')}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _successColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${vehicle.documents.length} docs',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDetailView() {
    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      return _buildEmptyState(
        title: 'Vehículo no encontrado',
        message: 'Selecciona un vehículo para ver sus documentos.',
      );
    }

    final visibleDocuments = vehicle.documents
        .where(
          (doc) => _showHistory ? !doc.estadoDocumento : doc.estadoDocumento,
        )
        .toList();

    return Column(
      key: const ValueKey('vehicle-detail-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Placa: ${vehicle.plate}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              if (vehicle.owners.isNotEmpty)
                Text(
                  'Propietario(s): ${vehicle.owners.join(' • ')}',
                  style: const TextStyle(color: Colors.white70),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _showHistory = !_showHistory;
            });
          },
          icon: Icon(
            _showHistory ? Icons.visibility : Icons.history,
            color: Colors.white,
          ),
          label: Text(
            _showHistory ? 'Ver documentos activos' : 'Ver historial',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showHistory ? Colors.orange : _accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: visibleDocuments.isEmpty
              ? _buildEmptyState(
                  title: 'Sin documentos de vehículo',
                  message: 'Este vehículo no tiene documentos disponibles.',
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: visibleDocuments.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final document = visibleDocuments[index];
                    return _buildDocumentCard(document);
                  },
                ),
        ),
      ],
    );
  }

  IconData _getDocumentIcon(_DocumentEntry document) {
    final name = document.name.toUpperCase();

    if (name.contains('CEDULA')) return Icons.badge_rounded;
    if (name.contains('LICENCIA')) return Icons.credit_card_rounded;
    if (name.contains('SOAT')) return Icons.verified_user_rounded;
    if (name.contains('TECNOMECANICA')) return Icons.car_repair_rounded;
    if (name.contains('SEGURO')) return Icons.security_rounded;
    if (name.contains('RUT')) return Icons.assignment_ind_rounded;
    if (name.contains('TARJETA')) return Icons.article_rounded;
    if (name.contains('CONTRACTUAL')) return Icons.policy_rounded;
    if (name.contains('EXTRACONTRACTUAL')) return Icons.policy_outlined;

    return document.isPdf
        ? Icons.picture_as_pdf_rounded
        : Icons.insert_drive_file_rounded;
  }

  Widget _buildDocumentCard(_DocumentEntry document) {
    return InkWell(
      onTap: () => DocumentPreviewModal.show(
        context: context,
        documentName: document.name,
        fileUrl: document.url,
        expiryDate: document.expiryDate,
        observations: document.observations,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(
                _getDocumentIcon(document),
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              document.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            if (document.expiryDate != null)
              Text(
                'Vence: ${document.formattedExpiry}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (document.observations.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                document.observations,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 62,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentEntry {
  final String id;
  final String name;
  final String url;
  final DateTime? expiryDate;
  final String observations;
  final String ownerId;
  final String vehicleId;
  final String ownerName;
  final String vehiclePlate;
  final String documentNumber;
  final bool estadoDocumento;

  _DocumentEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.expiryDate,
    required this.observations,
    required this.ownerId,
    required this.vehicleId,
    required this.ownerName,
    required this.vehiclePlate,
    required this.documentNumber,
    required this.estadoDocumento,
  });

  bool get isPdf => url.toLowerCase().endsWith('.pdf');
  bool get isImage =>
      url.toLowerCase().endsWith('.jpg') ||
      url.toLowerCase().endsWith('.jpeg') ||
      url.toLowerCase().endsWith('.png') ||
      url.toLowerCase().endsWith('.webp');

  int get daysRemaining {
    if (expiryDate == null) return 9999;

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final expiry = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
    );

    return expiry.difference(today).inDays;
  }

  String get remainingLabel {
    final days = daysRemaining;

    if (days < 0) return 'Vencido';
    if (days < 30) return '$days días';

    final months = days ~/ 30;
    final years = months ~/ 12;
    final remainingMonths = months % 12;

    if (years > 0 && remainingMonths > 0) {
      return '$years año${years == 1 ? '' : 's'} $remainingMonths mes${remainingMonths == 1 ? '' : 'es'}';
    }

    if (years > 0) {
      return '$years año${years == 1 ? '' : 's'}';
    }

    return '$months mes${months == 1 ? '' : 'es'}';
  }

  bool get isExpired => daysRemaining < 0;
  bool get isNearExpiry => daysRemaining <= 30;

  String get formattedExpiry {
    if (expiryDate == null) return 'Sin fecha';
    return '${expiryDate!.day.toString().padLeft(2, '0')}/${expiryDate!.month.toString().padLeft(2, '0')}/${expiryDate!.year}';
  }

  factory _DocumentEntry.fromMap(Map<String, dynamic> raw) {
    final String name = _extractName(raw);
    final String url = _extractUrl(raw);
    final DateTime? expiryDate = _parseDate(
      raw['fechaVencimiento'] ?? raw['expiryDate'] ?? raw['fecha_vencimiento'],
    );
    final String ownerId =
        _valueAsString(
          raw['idUsuario'] ?? raw['id_usuario'] ?? raw['usuarioId'],
        ) ??
        '';
    final String vehicleId =
        _valueAsString(
          raw['idVehiculo'] ?? raw['id_vehiculo'] ?? raw['vehiculoId'],
        ) ??
        '';
    final String ownerName = _extractOwnerName(raw);
    final String vehiclePlate =
        _valueAsString(
          raw['placa'] ?? raw['vehiclePlate'] ?? raw['placaVehiculo'],
        ) ??
        '';
    final String documentNumber =
        _valueAsString(
          raw['numeroDocumento'] ?? raw['numero_documento'] ?? raw['documento'],
        ) ??
        '';
    final String observations =
        _valueAsString(
          raw['observaciones'] ?? raw['observacion'] ?? raw['observations'],
        ) ??
        '';
    return _DocumentEntry(
      id: _valueAsString(raw['idDocumento'] ?? raw['id'] ?? '') ?? '',
      name: name,
      url: url,
      expiryDate: expiryDate,
      observations: observations,
      ownerId: ownerId,
      vehicleId: vehicleId,
      ownerName: ownerName,
      vehiclePlate: vehiclePlate,
      documentNumber: documentNumber,
      estadoDocumento:
          raw['estadoDocumento'] == true ||
          raw['estado_documento'] == true ||
          raw['estadoDocumento']?.toString().toLowerCase() == 'true' ||
          raw['estado_documento']?.toString().toLowerCase() == 'true',
    );
  }

  static String _extractName(Map<String, dynamic> raw) {
    return _valueAsString(
          raw['nombreTipoDocumento'] ??
              raw['nombreTipo'] ??
              raw['tipoDocumento'] ??
              raw['name'] ??
              raw['nombre'] ??
              raw['documentName'],
        ) ??
        'Documento';
  }

  static String _extractOwnerName(Map<String, dynamic> raw) {
    if (raw['nombreUsuario'] != null || raw['apellidoUsuario'] != null) {
      final firstName = _valueAsString(raw['nombreUsuario']) ?? '';
      final lastName = _valueAsString(raw['apellidoUsuario']) ?? '';
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) return fullName;
    }
    return _valueAsString(raw['ownerName'] ?? raw['responsableName'] ?? '') ??
        '';
  }

  static String _extractUrl(Map<String, dynamic> raw) {
    return _valueAsString(
          raw['urlStorage'] ??
              raw['url_storage'] ??
              raw['urlStorageDocumento'] ??
              raw['urlDocumento'] ??
              raw['url'] ??
              raw['ruta'] ??
              raw['rutaDocumento'] ??
              raw['documentUrl'] ??
              raw['archivo'] ??
              raw['fileUrl'],
        ) ??
        '';
  }

  static String? _valueAsString(dynamic value) {
    if (value == null) return null;
    return value.toString().trim();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }
}

class _PersonSummary {
  final String id;
  final String fullName;
  final String documentNumber;
  final Set<String> roles;
  final List<String> vehiclePlates;
  final List<_DocumentEntry> documents;

  _PersonSummary({
    required this.id,
    required this.fullName,
    required this.documentNumber,
    required this.roles,
    required this.vehiclePlates,
    required this.documents,
  });

  String get initials {
    final words = fullName.split(' ');
    final letters = words
        .take(2)
        .map((word) => word.isNotEmpty ? word[0] : '')
        .join();
    return letters.toUpperCase();
  }

  String get subtitle {
    if (vehiclePlates.isNotEmpty) {
      final label = vehiclePlates.length == 1
          ? 'Propietario de'
          : 'Propietario de varios';
      return '$label ${vehiclePlates.take(2).join(' • ')}';
    }
    return roles.isNotEmpty ? roles.first : 'Persona';
  }
}

class _VehicleSummary {
  final String id;
  final String plate;
  final String brand;
  final String model;
  final String imageUrl;
  final List<String> owners;
  final List<_DocumentEntry> documents;

  _VehicleSummary({
    required this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.imageUrl,
    required this.owners,
    required this.documents,
  });

  String get title {
    final text = [
      brand,
      model,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    return text.isEmpty ? 'Vehículo' : text;
  }
}
