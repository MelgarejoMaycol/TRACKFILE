import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/l10n/app_language.dart';
import 'package:trackfile/services/api_link.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/services/document_service.dart';
import 'package:trackfile/services/frontend_cache.dart';
import 'package:trackfile/widgets/documents/document_preview_modal.dart';
import 'package:trackfile/widgets/documents/edit_document_modal.dart';
import 'package:trackfile/widgets/documents/upload_document_modal.dart';
import 'package:trackfile/widgets/utils/shimmer_skeleton.dart';

class DocumentosScreen extends StatefulWidget {
  final String? role;
  final String? userId;
  final String? token;
  final bool canUpload;

  final String? initialVehicleId;
  final String? initialVehiclePlate;

  const DocumentosScreen({
    super.key,
    this.role,
    this.userId,
    this.token,
    this.canUpload = false,
    this.initialVehicleId,
    this.initialVehiclePlate,
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

  double _screenPadding(double width) {
    if (width < 360) return 12;
    if (width < 600) return 16;
    return 24;
  }

  double _responsiveText(
    double width, {
    required double small,
    required double medium,
    required double large,
  }) {
    if (width < 360) return small;
    if (width < 600) return medium;
    return large;
  }

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
  bool _openedFromUserPanel = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _persons = [];
    _vehicles = [];
    FrontendCache.revision.addListener(_reloadFromCacheUpdate);
    _loadExplorerData();
  }

  void _reloadFromCacheUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadExplorerData(showLoader: false);
    });
  }

  Future<void> _loadExplorerData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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
      final String selectedVehicleId = (widget.initialVehicleId ?? '').trim();
      final String selectedPersonId = (widget.userId ?? '').trim();

      final bool vieneDesdeVehiculo = selectedVehicleId.isNotEmpty;

      final bool isEmpresaPersonaSeleccionada =
          isEmpresa && selectedPersonId.isNotEmpty && !vieneDesdeVehiculo;

      final visibleUsers = isEmpresaPersonaSeleccionada
          ? users.where((user) {
              final id =
                  _valueAsString(user['id']) ??
                  _valueAsString(user['idUsuario']) ??
                  '';
              return id == selectedPersonId;
            }).toList()
          : isEmpresa
          ? users
          : users.where((user) {
              final id =
                  _valueAsString(user['id']) ??
                  _valueAsString(user['idUsuario']) ??
                  '';
              return id == widget.userId;
            }).toList();

      final visibleVehicles = isEmpresaPersonaSeleccionada
          ? vehicles.where((vehicle) {
              return _vehicleBelongsToUser(vehicle, selectedPersonId);
            }).toList()
          : isEmpresa
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

      if (selectedVehicleId.isNotEmpty) {
        final vehicleMatches = _vehicles
            .where((v) => v.id == selectedVehicleId)
            .toList();

        if (vehicleMatches.isNotEmpty) {
          _selectedVehicle = vehicleMatches.first;
          _view = _DocumentosFlowView.vehicleDetail;
        }
      }

      if (isEmpresaPersonaSeleccionada) {
        _persons = _persons.where((p) => p.id == selectedPersonId).toList();

        if (_persons.isNotEmpty) {
          _selectedPerson = _persons.first;
          _view = _DocumentosFlowView.personDetail;

          _openedFromUserPanel = true;
        }
      } else if (!isEmpresa) {
        final currentUserId = (widget.userId ?? '').trim();

        _persons = _persons.where((p) => p.id == currentUserId).toList();

        if (_persons.isNotEmpty) {
          _selectedPerson = _persons.first;
        }
      }
    } catch (_) {
      _errorMessage =
          'No se pudieron cargar los datos de documentos. Intenta nuevamente.';
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshExplorerDataKeepingCurrentView() async {
    final previousView = _view;
    final previousPersonId = _selectedPerson?.id;
    final previousVehicleId = _selectedVehicle?.id;
    final previousShowHistory = _showHistory;

    await _loadExplorerData(showLoader: false);

    if (!mounted) return;

    setState(() {
      _showHistory = previousShowHistory;

      if (previousView == _DocumentosFlowView.personDetail &&
          previousPersonId != null) {
        final matches = _persons.where((p) => p.id == previousPersonId);
        if (matches.isNotEmpty) {
          _selectedPerson = matches.first;
          _view = _DocumentosFlowView.personDetail;
        }
      }

      if (previousView == _DocumentosFlowView.vehicleDetail &&
          previousVehicleId != null) {
        final matches = _vehicles.where((v) => v.id == previousVehicleId);
        if (matches.isNotEmpty) {
          _selectedVehicle = matches.first;
          _view = _DocumentosFlowView.vehicleDetail;
        }
      }
    });
  }

  List<_DocumentEntry> _filterDocumentsByRole(
    List<_DocumentEntry> documents,
    List<Map<String, dynamic>> vehicles,
  ) {
    final currentUserId = (widget.userId ?? '').trim();

    if (currentUserId.isEmpty) {
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
      String propietarioNombre = '';
      String conductorNombre = '';

      final dynamic propietario = vehicle['propietario'];
      if (propietario is Map) {
        propietarioNombre = _fullNameFromMap(
          propietario['usuario'] ?? propietario,
        );
      }

      final dynamic conductor = vehicle['conductor'];
      if (conductor is Map) {
        conductorNombre = _fullNameFromMap(conductor['usuario'] ?? conductor);
      }
      byVehicle[id] = _VehicleSummary(
        id: id,
        propietario: propietarioNombre,
        conductor: conductorNombre,
        plate: plate,
        brand: brand,
        model: model,
        imageUrl: imageUrl,
        owners: [],
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
          propietario: '',
          conductor: '',
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

  bool _vehicleBelongsToUser(Map<String, dynamic> vehicle, String userId) {
    final conductor = vehicle['conductor'];
    if (conductor is Map) {
      final usuario = conductor['usuario'];
      if (usuario is Map) {
        final conductorUserId =
            _valueAsString(usuario['id']) ??
            _valueAsString(usuario['idUsuario']) ??
            '';
        if (conductorUserId == userId) return true;
      }
    }

    final propietario = vehicle['propietario'];
    if (propietario is Map) {
      final usuario = propietario['usuario'];
      if (usuario is Map) {
        final propietarioUserId =
            _valueAsString(usuario['id']) ??
            _valueAsString(usuario['idUsuario']) ??
            '';
        if (propietarioUserId == userId) return true;
      }
    }

    return false;
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
    UploadDocumentModal.show(
      context: context,
      userId: widget.userId ?? '',
      userRole: widget.role ?? 'Empresa',
      token: _authToken,
      onSuccess: _refreshExplorerDataKeepingCurrentView,
    );
  }

  @override
  void dispose() {
    FrontendCache.revision.removeListener(_reloadFromCacheUpdate);
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = _screenPadding(width);
        final isEmpresa = widget.role?.toLowerCase() == 'empresa';

        final content = ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(padding, padding, padding, 16),
            color: _surfaceColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        );

        if (!isEmpresa || !widget.canUpload) {
          return content;
        }

        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              bottom: 78,
              right: padding,
              child: FloatingActionButton(
                backgroundColor: _accentColor,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onPressed: _showUploadModal,
                child: const Icon(Icons.upload_file),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool showBack =
        _view != _DocumentosFlowView.home && !_openedFromUserPanel;
    final width = MediaQuery.of(context).size.width;

    final double titleSize = _responsiveText(
      width,
      small: 19,
      medium: 21,
      large: 24,
    );

    final double subtitleSize = _responsiveText(
      width,
      small: 12,
      medium: 13,
      large: 14,
    );

    final String subtitle;
    switch (_view) {
      case _DocumentosFlowView.home:
        subtitle = context.t('documents.homeSubtitle');
        break;
      case _DocumentosFlowView.people:
        subtitle = context.t('documents.peopleSubtitle');
        break;
      case _DocumentosFlowView.personDetail:
        subtitle =
            _selectedPerson?.fullName ??
            context.t('documents.personSubtitle');
        break;
      case _DocumentosFlowView.vehicles:
        subtitle = context.t('documents.vehiclesSubtitle');
        break;
      case _DocumentosFlowView.vehicleDetail:
        subtitle =
            _selectedVehicle?.title ?? context.t('documents.vehicleSubtitle');
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: _onBackPressed,
              icon: const Icon(Icons.arrow_back, size: 26, color: Colors.white),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _view == _DocumentosFlowView.people
                    ? context.t('documents.people')
                    : _view == _DocumentosFlowView.vehicles
                    ? context.t('documents.vehicles')
                    : context.t('documents.title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_view != _DocumentosFlowView.people &&
                  _view != _DocumentosFlowView.vehicles) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: width < 390 ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: subtitleSize,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!_isLoading)
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 8),
            onPressed: () {
              FrontendCache.invalidateAll();
              _loadExplorerData();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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

    return docs;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final int columns = width >= 520 ? 2 : 1;
        final double cardHeight = width < 380
            ? 175
            : width < 420
            ? 165
            : 155;

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
                const SizedBox(height: 18),
              ],

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: cardHeight,
                children: [
                  _buildHomeCard(
                    icon: Icons.people_alt_rounded,
                    title: context.t('documents.people'),
                    subtitle: _isEmpresa
                        ? 'Conductores y propietarios'
                        : 'Mis documentos personales',
                    accent: Colors.blue.shade700,
                    onTap: _openPeopleSection,
                  ),
                  _buildHomeCard(
                    icon: Icons.directions_car_rounded,
                    title: context.t('documents.vehicles'),
                    subtitle: context.t('documents.vehicleCards'),
                    accent: Colors.teal.shade700,
                    onTap: () =>
                        setState(() => _view = _DocumentosFlowView.vehicles),
                  ),
                ],
              ),

              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingDocumentsRow(List<_DocumentEntry> documents) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;

    final visibleDocuments = isMobile
        ? documents.take(2).toList()
        : documents.take(3).toList();

    final double cardWidth = isMobile ? (width - 72) / 2 : 220;

    final double avatarRadius = isMobile ? 28 : 38;

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: isMobile ? 10 : 14,
        runSpacing: isMobile ? 10 : 14,
        children: visibleDocuments.map((doc) {
          final color = _getExpiryColor(doc.daysRemaining);

          return InkWell(
            onTap: () async {
              var fileUrl = _normalizeFileUrl(doc.url);

              if (fileUrl.isEmpty) {
                final detalle = await DocumentService.getDocumentDetail(
                  documentoId: int.parse(doc.id),
                  token: _authToken,
                );

                final rawUrl =
                    detalle?['urlStorage'] ?? detalle?['url_storage'];

                if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
                  fileUrl = _normalizeFileUrl(rawUrl.toString());
                }
              }

              if (!context.mounted) return;

              if (!mounted) return;

              _showDocumentDetailModal(doc, fileUrl);
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: cardWidth.clamp(135, 220),
              padding: EdgeInsets.all(isMobile ? 10 : 14),
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
                    radius: avatarRadius,
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
                            fontSize: isMobile ? 17 : 22,
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
                            fontSize: isMobile ? 8 : 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 10),
                  Text(
                    doc.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.daysRemaining < 0
                        ? 'Documento vencido'
                        : 'Faltan ${doc.remainingLabel}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: isMobile ? 10 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${context.t('documents.expires')}: ${doc.formattedExpiry}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isMobile ? 9 : 10,
                    ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool small = constraints.maxWidth < 280;

        final double iconSize = small ? 20 : 24;
        final double titleSize = small ? 14 : 16;
        final double subtitleSize = small ? 10.5 : 12;
        final double exploreSize = small ? 10.5 : 12;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: EdgeInsets.all(small ? 10 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.all(small ? 8 : 10),
                  child: Icon(icon, size: iconSize, color: Colors.white),
                ),
                SizedBox(height: small ? 8 : 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: small ? 6 : 8),
                Flexible(
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: subtitleSize,
                      height: 1.15,
                    ),
                  ),
                ),
                SizedBox(height: small ? 6 : 8),
                Text(
                  'Explorar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: exploreSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeopleView() {
    final persons = _filteredPersons;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int columns = width >= 760 ? 2 : 1;
        final double cardHeight = width < 380 ? 128 : 118;

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
                      title: context.t('documents.noPeople'),
                      message: _searchQuery.isEmpty
                          ? 'Aún no existen conductores o propietarios en la empresa.'
                          : 'Ninguna persona coincide con la búsqueda.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 95),
                      itemCount: persons.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: cardHeight,
                      ),
                      itemBuilder: (context, index) {
                        final person = persons[index];
                        return _buildPersonCard(person);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      onChanged: (value) {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          setState(() => _searchQuery = value);
        });
      },
      decoration: InputDecoration(
        hintText: context.t('documents.searchPerson'),
        prefixIcon: const Icon(Icons.search),
        filled: true,
        isDense: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        hintStyle: const TextStyle(color: Colors.white54),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 360;

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
            padding: EdgeInsets.all(small ? 12 : 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: small ? 24 : 30,
                  backgroundColor: _accentColor.withValues(alpha: 0.25),
                  child: Text(
                    person.initials,
                    style: TextStyle(
                      fontSize: small ? 16 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
                SizedBox(width: small ? 10 : 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: small ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        person.documentNumber.isNotEmpty
                            ? 'CC: ${person.documentNumber}'
                            : 'Documento no disponible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: small ? 11 : 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rol: ${person.roles.join(' / ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: small ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: small ? 8 : 10,
                      vertical: small ? 6 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${person.documents.length} docs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: small ? 10 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonDetailView() {
    final person = _selectedPerson;
    if (person == null) {
      return _buildEmptyState(
        title: context.t('documents.personNotFound'),
        message: 'Selecciona una persona para ver sus documentos.',
      );
    }

    final visibleDocuments = person.documents
        .where(
          (doc) => _showHistory ? !doc.estadoDocumento : doc.estadoDocumento,
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final titleSize = width < 380 ? 16.0 : 18.0;
        final textSize = width < 380 ? 12.0 : 14.0;
        final maxExtent = width < 380 ? 145.0 : 175.0;
        final cardHeight = width < 380 ? 155.0 : 165.0;

        return SingleChildScrollView(
          key: const ValueKey('person-detail-view'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('documents.personDocuments'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                person.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: textSize,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                person.documentNumber.isNotEmpty
                    ? '${context.t('documents.documentNumber')}: ${person.documentNumber}'
                    : context.t('documents.documentUnavailable'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: textSize),
              ),

              const SizedBox(height: 4),

              Text(
                '${context.t('documents.role')}: ${person.roles.join(' / ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: textSize),
              ),

              if (person.vehiclePlates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${context.t('documents.linkedVehicles')}: ${person.vehiclePlates.join(' • ')}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: textSize),
                ),
              ],

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showHistory
                        ? Colors.orange
                        : _accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              if (visibleDocuments.isEmpty)
                SizedBox(
                  height: 320,
                  child: _buildEmptyState(
                    title: context.t('documents.noDocuments'),
                    message:
                        'Esta persona no tiene documentos asociados a la vista actual.',
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: visibleDocuments.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxExtent,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final document = visibleDocuments[index];
                    return _buildDocumentCard(document);
                  },
                ),

              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehiclesView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final int columns = width >= 700 ? 2 : 1;
        final double cardHeight = width < 420 ? 112 : 126;

        return Column(
          key: const ValueKey('vehicles-view'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _vehicles.isEmpty
                  ? _buildEmptyState(
                      title: context.t('documents.noVehicles'),
                      message:
                          'No se encontraron vehículos asociados a la empresa.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 95),
                      itemCount: _vehicles.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: cardHeight,
                      ),
                      itemBuilder: (context, index) {
                        final vehicle = _vehicles[index];
                        return _buildVehicleCard(vehicle);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleCard(_VehicleSummary vehicle) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool small = constraints.maxWidth < 360;

        final double iconBox = small ? 44 : 52;
        final double titleSize = small ? 13 : 15;
        final double subtitleSize = small ? 11 : 12.5;
        final double docsSize = small ? 10 : 11;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedVehicle = vehicle;
              _view = _DocumentosFlowView.vehicleDetail;
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
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: small ? 12 : 16,
              vertical: small ? 12 : 14,
            ),
            child: Row(
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: _successColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_car_filled,
                    size: small ? 22 : 26,
                    color: Colors.green.shade700,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.plate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        vehicle.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _successColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${vehicle.documents.length} docs',
                    style: TextStyle(
                      fontSize: docsSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleDetailView() {
    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      return _buildEmptyState(
        title: context.t('documents.vehicleNotFound'),
        message: 'Selecciona un vehículo para ver sus documentos.',
      );
    }

    final visibleDocuments = vehicle.documents
        .where(
          (doc) => _showHistory ? !doc.estadoDocumento : doc.estadoDocumento,
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final titleSize = width < 380 ? 15.0 : 18.0;
        final textSize = width < 380 ? 12.0 : 14.0;
        final maxExtent = width < 380 ? 145.0 : 175.0;
        final cardHeight = width < 380 ? 155.0 : 165.0;

        return SingleChildScrollView(
          key: const ValueKey('vehicle-detail-view'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('documents.ownerDriverDocuments'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${vehicle.title} • ${context.t('documents.plate')} ${vehicle.plate}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: textSize),
              ),
              const SizedBox(height: 10),
              Text(
                '${context.t('documents.owner')}: ${vehicle.propietario.isNotEmpty ? vehicle.propietario : context.t('home.unassigned')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: textSize),
              ),
              const SizedBox(height: 4),
              Text(
                '${context.t('documents.driver')}: ${vehicle.conductor.isNotEmpty ? vehicle.conductor : context.t('home.unassigned')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: textSize),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
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
                    _showHistory
                        ? context.t('documents.viewActive')
                        : context.t('documents.viewHistory'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showHistory
                        ? Colors.orange
                        : _accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (visibleDocuments.isEmpty)
                SizedBox(
                  height: 320,
                  child: _buildEmptyState(
                    title: context.t('documents.noVehicleDocuments'),
                    message: context.t('documents.vehicleEmptyMessage'),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: visibleDocuments.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxExtent,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final document = visibleDocuments[index];
                    return _buildDocumentCard(document);
                  },
                ),
              const SizedBox(height: 120),
            ],
          ),
        );
      },
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

  String _normalizeFileUrl(String value) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty) {
      return '';
    }

    // URL completa cloudinary
    if (cleanValue.startsWith('http://') || cleanValue.startsWith('https://')) {
      // 🔥 Cloudinary PDF preview fix
      if (cleanValue.contains('/upload/')) {
        return cleanValue.replaceFirst(
          '/upload/',
          '/upload/fl_attachment:false/',
        );
      }

      return cleanValue;
    }

    final baseUrl = getApiLink();

    if (cleanValue.startsWith('/')) {
      return '$baseUrl$cleanValue';
    }

    return '$baseUrl/$cleanValue';
  }

  Future<void> _showDocumentDetailModal(
    _DocumentEntry document,
    String fileUrl,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final bool isVehicleDocument = document.vehicleId.isNotEmpty;

        _VehicleSummary? linkedVehicle;

        if (document.vehicleId.isNotEmpty) {
          final matches = _vehicles.where(
            (vehicle) => vehicle.id == document.vehicleId,
          );
          if (matches.isNotEmpty) {
            linkedVehicle = matches.first;
          }
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF20276D),
                  Color(0xFF121842),
                  Color(0xFF0D1234),
                ],
              ),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDocumentModalHeroHeader(
                    title: document.name,
                    subtitle: document.estadoDocumento
                        ? 'Documento activo'
                        : 'Documento histórico / inactivo',
                    icon: _getDocumentIcon(document),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.category_rounded,
                            'Tipo',
                            document.name,
                          ),
                          _buildDetailRow(
                            Icons.info_rounded,
                            'Estado',
                            document.estadoDocumento
                                ? 'Activo'
                                : 'Histórico/Inactivo',
                          ),
                          _buildDetailRow(
                            Icons.event_available_rounded,
                            'Fecha de creación',
                            document.creationDate != null
                                ? '${document.creationDate!.day.toString().padLeft(2, '0')}/${document.creationDate!.month.toString().padLeft(2, '0')}/${document.creationDate!.year}'
                                : 'Sin fecha registrada',
                          ),
                          _buildDetailRow(
                            Icons.calendar_today_rounded,
                            'Fecha de vencimiento',
                            document.expiryDate != null
                                ? document.formattedExpiry
                                : 'Sin fecha registrada',
                          ),
                          _buildDetailRow(
                            Icons.warning_amber_rounded,
                            'Tiempo restante',
                            document.expiryDate != null
                                ? document.remainingLabel
                                : 'No aplica',
                          ),
                          _buildDetailRow(
                            Icons.person_rounded,
                            'Persona asociada',
                            document.ownerName.isNotEmpty
                                ? document.ownerName
                                : 'No disponible',
                          ),
                          if (document.documentNumber.isNotEmpty)
                            _buildDetailRow(
                              Icons.badge_rounded,
                              'Documento de identidad',
                              document.documentNumber,
                            ),
                          _buildDetailRow(
                            Icons.directions_car_rounded,
                            'Tipo de documento',
                            isVehicleDocument
                                ? 'Documento de vehículo'
                                : 'Documento personal',
                          ),
                          if (document.vehiclePlate.isNotEmpty)
                            _buildDetailRow(
                              Icons.confirmation_number_rounded,
                              'Placa del vehículo',
                              document.vehiclePlate,
                            ),
                          if (linkedVehicle != null) ...[
                            _buildDetailRow(
                              Icons.directions_car_filled_rounded,
                              'Vehículo',
                              '${linkedVehicle.title} • Placa ${linkedVehicle.plate}',
                            ),
                            _buildDetailRow(
                              Icons.home_rounded,
                              'Propietario',
                              linkedVehicle.propietario.isNotEmpty
                                  ? linkedVehicle.propietario
                                  : 'No asignado',
                            ),
                            _buildDetailRow(
                              Icons.person_pin_rounded,
                              'Conductor',
                              linkedVehicle.conductor.isNotEmpty
                                  ? linkedVehicle.conductor
                                  : 'No asignado',
                            ),
                          ],
                          if (document.observations.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Observaciones',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                document.observations,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      document.expiryDate == null ||
                                          document.idTipo == 0 ||
                                          document.isExpired
                                      ? null
                                      : () {
                                          Navigator.pop(context);

                                          EditDocumentModal.show(
                                            context: this.context,
                                            documentoId: int.parse(document.id),
                                            idTipo: document.idTipo,
                                            area: document.area,
                                            fechaVencimiento:
                                                document.expiryDate!,
                                            observaciones:
                                                document.observations,
                                            idVehiculo:
                                                document.vehicleId.isNotEmpty
                                                ? int.tryParse(
                                                    document.vehicleId,
                                                  )
                                                : null,
                                            idUsuario:
                                                document.vehicleId.isEmpty
                                                ? int.tryParse(document.ownerId)
                                                : null,
                                            onSuccess:
                                                _refreshExplorerDataKeepingCurrentView,
                                          );
                                        },
                                  icon: const Icon(Icons.edit_calendar_rounded),
                                  label: Text(
                                    document.isExpired
                                        ? context.t('documents.uploadNew')
                                        : context.t('documents.editDate'),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: fileUrl.trim().isEmpty
                                      ? null
                                      : () {
                                          Navigator.pop(context);

                                          DocumentPreviewModal.show(
                                            context: this.context,
                                            documentName: document.name,
                                            fileUrl: fileUrl,
                                            expiryDate: document.expiryDate,
                                            observations: document.observations,
                                            ownerName: document.ownerName,
                                          );
                                        },
                                  icon: const Icon(Icons.visibility_rounded),
                                  label: Text(context.t('documents.viewDocument')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildDocumentModalHeroHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4F4CE8)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
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
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'No disponible' : value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(_DocumentEntry document) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 155;

        return InkWell(
          onTap: () async {
            var fileUrl = _normalizeFileUrl(document.url);

            if (fileUrl.isEmpty) {
              final detalle = await DocumentService.getDocumentDetail(
                documentoId: int.parse(document.id),
                token: _authToken,
              );

              final rawUrl = detalle?['urlStorage'] ?? detalle?['url_storage'];

              if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
                fileUrl = _normalizeFileUrl(rawUrl.toString());
              }
            }

            if (!context.mounted) return;

            _showDocumentDetailModal(document, fileUrl);
          },
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
            padding: EdgeInsets.all(small ? 9 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.all(small ? 8 : 10),
                  child: Icon(
                    _getDocumentIcon(document),
                    size: small ? 19 : 22,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: small ? 8 : 12),
                Text(
                  document.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: small ? 11 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (document.expiryDate != null)
                  Text(
                    '${context.t('documents.expires')}: ${document.formattedExpiry}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: small ? 10 : 12,
                    ),
                  ),
                if (document.observations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      document.observations,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: small ? 10 : 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
  final DateTime? creationDate;
  final String observations;
  final String ownerId;
  final String vehicleId;
  final String ownerName;
  final String vehiclePlate;
  final String documentNumber;
  final bool estadoDocumento;
  final int idTipo;
  final String area;

  _DocumentEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.expiryDate,
    required this.creationDate,
    required this.observations,
    required this.ownerId,
    required this.vehicleId,
    required this.ownerName,
    required this.vehiclePlate,
    required this.documentNumber,
    required this.estadoDocumento,
    required this.idTipo,
    required this.area,
  });

  bool get isPdf {
    final cleanUrl = url.toLowerCase().split('?').first;
    return cleanUrl.endsWith('.pdf');
  }

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
    final DateTime? creationDate = _parseDate(
      raw['fechaCreacion'] ??
          raw['fecha_creacion'] ??
          raw['createdAt'] ??
          raw['fechaRegistro'],
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

    final int idTipo =
        int.tryParse(
          (raw['idTipo'] ??
                  raw['id_tipo'] ??
                  raw['tipoDocumentoId'] ??
                  raw['idTipoDocumento'] ??
                  raw['tipoDocumento']?['id'] ??
                  raw['tipoDocumento']?['idTipo'] ??
                  '0')
              .toString(),
        ) ??
        0;

    final String area = _valueAsString(raw['area']) ?? 'LEGAL';
    return _DocumentEntry(
      id: _valueAsString(raw['idDocumento'] ?? raw['id'] ?? '') ?? '',
      name: name,
      url: url,
      expiryDate: expiryDate,
      creationDate: creationDate,
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
      idTipo: idTipo,
      area: area,
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
    final value = _valueAsString(
      raw['urlStorage'] ??
          raw['url_storage'] ??
          raw['urlStorageDocumento'] ??
          raw['urlDocumento'] ??
          raw['url_documento'] ??
          raw['urlArchivo'] ??
          raw['url_archivo'] ??
          raw['ruta'] ??
          raw['rutaDocumento'] ??
          raw['ruta_documento'] ??
          raw['rutaArchivo'] ??
          raw['ruta_archivo'] ??
          raw['documentUrl'] ??
          raw['archivoUrl'] ??
          raw['fileUrl'],
    );

    if (value == null || value.isEmpty) return '';

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final baseUrl = getApiLink();

    if (value.startsWith('/')) {
      return '$baseUrl$value';
    }

    return '$baseUrl/$value';
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
  final String propietario;
  final String conductor;
  final String plate;
  final String brand;
  final String model;
  final String imageUrl;
  final List<String> owners;
  final List<_DocumentEntry> documents;

  _VehicleSummary({
    required this.id,
    required this.propietario,
    required this.conductor,
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
