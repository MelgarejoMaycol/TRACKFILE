import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'document_modal.dart';

class DocumentosWidget extends StatefulWidget {
  final String? role;
  final String? jsonPath;

  const DocumentosWidget({
    super.key,
    this.role,
    this.jsonPath,
  });

  @override
  State<DocumentosWidget> createState() => _DocumentosWidgetState();
}

class _DocumentInfo {
  final String name;
  final DateTime expiryDate;
  final DateTime? paymentDate;
  final bool important;
  final String category; // tipo de documento (SOAT, Licencia, etc.)
  final String ownerId; // id del conductor/propietario/empresa
  final String ownerType; // 'empresa' | 'conductor' | 'propietario' | 'vehiculo'
  final String ownerName; // nombre para agrupar
  final String vehicleId; // id del vehículo si aplica
  final String vehiclePlate; // placa del vehículo si aplica

  const _DocumentInfo({
    required this.name,
    required this.expiryDate,
    this.paymentDate,
    this.important = false,
    this.category = 'General',
    this.ownerId = '',
    this.ownerType = 'empresa',
    this.ownerName = '',
    this.vehicleId = '',
    this.vehiclePlate = '',
  });

  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;

  bool get isNearExpiry => daysRemaining <= 30 && daysRemaining >= 0;
  bool get isExpired => daysRemaining < 0;
}

enum _EmpresaFilter { all, important, nearExpiry, expired, paid }

class _DocumentosWidgetState extends State<DocumentosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _chipBorderColor = Color(0xFF6B68F1);
  static const Color _cardColor = Color(0xFF1B1F6B);

  bool _isLoading = true;
  late String _role;
  List<_DocumentInfo> _documents = const [];
  // Quick search UI state
  final List<String> _quickDocTypes = ['Personal', 'Tecnicomecánico', 'Licencia', 'Póliza', 'SOAT'];
  String _selectedQuickType = 'Personal';
  final TextEditingController _empresaSearchController = TextEditingController();
  List<_DocumentInfo> _quickResults = [];
  bool _showQuickResults = false;

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? 'Conductor').toLowerCase();
    _loadDocuments();
  }

  @override
  void dispose() {
    _empresaSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    List<_DocumentInfo> parsed = [];
    if (widget.jsonPath != null) {
      try {
        final String jsonString = await rootBundle.loadString(widget.jsonPath!);
        final dynamic decoded = json.decode(jsonString);

        // company-level documents
        final List<dynamic>? docs = decoded is Map<String, dynamic> ? decoded['documents'] as List<dynamic>? : null;
        if (docs != null) {
          parsed.addAll(docs.map((dynamic item) {
            if (item is Map<String, dynamic>) {
              final String name = (item['name'] ?? 'Documento').toString();
              final String category = (item['category'] ?? 'General').toString();
              final DateTime? expiry = DateTime.tryParse((item['expiryDate'] ?? '').toString());
              final DateTime? payment = DateTime.tryParse((item['paymentDate'] ?? '').toString());
              final bool important = item['important'] == true;
              return expiry != null
                  ? _DocumentInfo(
                      name: name,
                      expiryDate: expiry,
                      paymentDate: payment,
                      important: important,
                      category: category,
                      ownerId: (item['ownerId'] ?? '').toString(),
                      ownerType: 'empresa',
                      ownerName: (decoded['companyName'] ?? '').toString(),
                    )
                  : null;
            }
            return null;
          }).whereType<_DocumentInfo>());
        }

        // driver-level documents
        final List<dynamic>? drivers = decoded is Map<String, dynamic> ? decoded['drivers'] as List<dynamic>? : null;
        if (drivers != null) {
          for (final dynamic d in drivers) {
            if (d is Map<String, dynamic>) {
              final String driverId = (d['id'] ?? d['userId'] ?? '').toString();
              final String driverName = (d['name'] ?? '').toString();
              final List<dynamic>? ddocs = d['documents'] as List<dynamic>? ?? d['docs'] as List<dynamic>?;
              if (ddocs != null) {
                parsed.addAll(ddocs.map((dynamic item) {
                  if (item is Map<String, dynamic>) {
                    final String name = (item['name'] ?? 'Documento').toString();
                    final String category = (item['category'] ?? 'General').toString();
                    final DateTime? expiry = DateTime.tryParse((item['expiryDate'] ?? '').toString());
                    final DateTime? payment = DateTime.tryParse((item['paymentDate'] ?? '').toString());
                    final bool important = item['important'] == true;
                    return expiry != null
                        ? _DocumentInfo(
                            name: name,
                            expiryDate: expiry,
                            paymentDate: payment,
                            important: important,
                            category: category,
                            ownerId: driverId,
                            ownerType: 'conductor',
                            ownerName: driverName,
                          )
                        : null;
                  }
                  return null;
                }).whereType<_DocumentInfo>());
              }
            }
          }
        }

        // owner-level documents
        final List<dynamic>? owners = decoded is Map<String, dynamic> ? decoded['owners'] as List<dynamic>? : null;
        if (owners != null) {
          for (final dynamic o in owners) {
            if (o is Map<String, dynamic>) {
              final String ownerId = (o['id'] ?? '').toString();
              final String ownerName = (o['name'] ?? '').toString();
              final List<dynamic>? odocs = o['documents'] as List<dynamic>? ?? o['docs'] as List<dynamic>?;
              if (odocs != null) {
                parsed.addAll(odocs.map((dynamic item) {
                  if (item is Map<String, dynamic>) {
                    final String name = (item['name'] ?? 'Documento').toString();
                    final String category = (item['category'] ?? 'General').toString();
                    final DateTime? expiry = DateTime.tryParse((item['expiryDate'] ?? '').toString());
                    final DateTime? payment = DateTime.tryParse((item['paymentDate'] ?? '').toString());
                    final bool important = item['important'] == true;
                    return expiry != null
                        ? _DocumentInfo(
                            name: name,
                            expiryDate: expiry,
                            paymentDate: payment,
                            important: important,
                            category: category,
                            ownerId: ownerId,
                            ownerType: 'propietario',
                            ownerName: ownerName,
                          )
                        : null;
                  }
                  return null;
                }).whereType<_DocumentInfo>());
              }
            }
          }
        }

      } catch (e) {
        debugPrint('Error cargando documentos: $e');
      }
    }

    if (parsed.isEmpty) {
      parsed = _exampleDocuments();
    }

    parsed.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    if (mounted) {
      setState(() {
        _documents = parsed;
        _isLoading = false;
      });
    }
  }

  List<_DocumentInfo> _exampleDocuments() {
    final DateTime now = DateTime.now();
    final Random rnd = Random(42);

    final List<String> firstNames = ['Carlos', 'María', 'Juan', 'Ana', 'Luis', 'Sofía', 'Andrés', 'Lucía', 'Diego', 'Camila', 'Pedro', 'Valentina', 'Ricardo', 'Paula', 'Héctor', 'Marta', 'Enzo', 'Daniela', 'Javier', 'Laura'];
    final List<String> lastNames = ['García', 'Pérez', 'Rodríguez', 'González', 'Martínez', 'López', 'Sánchez', 'Ramírez', 'Torres', 'Flores'];
    final List<String> plates = List.generate(40, (i) => 'ABC-${1000 + i}');
    final List<String> docTypes = ['SOAT', 'Tecnicomecánico', 'Póliza', 'Tarjeta de Operación'];

    final List<_DocumentInfo> generated = [];

    // Create many people with vehicle documents
    for (int i = 0; i < 40; i++) {
      final String ownerName = '${firstNames[rnd.nextInt(firstNames.length)]} ${lastNames[rnd.nextInt(lastNames.length)]}';
      final String ownerId = 'p${i + 1}';
      final String plate = plates[i % plates.length];
      final int docsForOwner = 2 + rnd.nextInt(3); // 2..4 documents

      for (int j = 0; j < docsForOwner; j++) {
        final String type = docTypes[rnd.nextInt(docTypes.length)];
        final int offsetDays = -120 + rnd.nextInt(480); // from -120 to +359 days
        final DateTime expiry = now.add(Duration(days: offsetDays));
        final DateTime payment = now.subtract(Duration(days: rnd.nextInt(180)));
        final bool important = rnd.nextDouble() < 0.08; // some are important

        generated.add(_DocumentInfo(
          name: type,
          expiryDate: expiry,
          paymentDate: rnd.nextBool() ? payment : null,
          important: important,
          category: type,
          ownerId: ownerId,
          ownerType: 'conductor',
          ownerName: ownerName,
          vehicleId: 'v${i + 1}',
          vehiclePlate: plate,
        ));
      }
    }

    // Add a few company-level fleet documents
    for (int k = 0; k < 8; k++) {
      final int offset = 30 + k * 30;
      generated.add(_DocumentInfo(
        name: 'Póliza Flota #${k + 1}',
        expiryDate: now.add(Duration(days: offset)),
        paymentDate: now.subtract(Duration(days: 30)),
        important: k % 3 == 0,
        category: 'Póliza',
        ownerId: 'empresa',
        ownerType: 'empresa',
        ownerName: 'Mi Empresa',
      ));
    }

    generated.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return generated;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_role) {
      case 'empresa':
        return _empresaDocumentos();
      case 'propietario':
        return _propietarioDocumentos();
      case 'secretaria':
        return _secretariaDocumentos();
      case 'admin':
        return _adminDocumentos();
      case 'conductor':
        return _conductorDocumentos();
    }
    return _conductorDocumentos();
  }

  Widget _conductorDocumentos() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 560;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos del conductor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              _buildDocumentStrip(isCompact: isCompact),
              const SizedBox(height: 28),
              _buildDocumentList(isCompact: isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentStrip({required bool isCompact, List<_DocumentInfo>? docs}) {
    final List<_DocumentInfo> items = docs ?? _documents;
    final double cardWidth = isCompact ? 180 : 200;
    return SizedBox(
      height: isCompact ? 150 : 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final _DocumentInfo doc = items[index];
          final int days = doc.daysRemaining;
          final bool isNearExpiry = doc.isNearExpiry || doc.isExpired;
          final bool highlight = doc.important || isNearExpiry;
          return GestureDetector(
            onTap: () => _openModal(doc),
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    highlight ? const Color(0xFFFF6B6B) : _accentColor,
                    highlight ? const Color(0xFFFF8E53) : _accentColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          doc.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doc.important)
                        const Icon(Icons.push_pin, color: Colors.white, size: 18)
                      else
                        const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Always show expiry date and owner (for empresa we limit documents to vehicle-related types)
                  Text(
                    doc.isExpired ? 'Vencido' : '${doc.daysRemaining.clamp(0, 999)} días restantes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Vence: ${_formatDate(doc.expiryDate)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (doc.ownerName.isNotEmpty)
                    Text(
                      doc.ownerName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  // Show category small
                  Text(
                    doc.category,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                  if (doc.paymentDate != null)
                    Text(
                      'Pagado: ${_formatDate(doc.paymentDate!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentList({required bool isCompact, List<_DocumentInfo>? docs}) {
    final List<_DocumentInfo> items = docs ?? _documents;
    return Column(
      children: items.map((doc) {
        final bool isExpired = doc.isExpired;
        final bool isNearExpiry = doc.isNearExpiry;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _cardColor.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (doc.important)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                    ),
                    child: const Text('Importante', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildChip(
                    label: isExpired ? 'Documento vencido' : 'Vence el ${_formatDate(doc.expiryDate)}',
                    highlight: isNearExpiry || isExpired,
                  ),
                  _buildChip(
                    label: '${doc.daysRemaining.clamp(0, 999)} días restantes',
                    highlight: isNearExpiry,
                  ),
                  if (doc.paymentDate != null)
                    _buildChip(
                      label: 'Pagado el ${_formatDate(doc.paymentDate!)}',
                      highlight: false,
                    ),
                  _buildChip(label: doc.category, highlight: false),
                  if (doc.ownerName.isNotEmpty) _buildChip(label: doc.ownerName, highlight: false),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.visibility_rounded, color: Colors.white70),
              onPressed: () => _openModal(doc),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChip({required String label, required bool highlight}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? _accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? _chipBorderColor : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  // --- Empresa documents panel (search, filters, highlighting) ---

  _EmpresaFilter _selectedEmpresaFilter = _EmpresaFilter.all;
  String _empresaSearch = '';
  bool _empresaSortAscending = true;

  // Additional filters
  String _selectedDocType = 'Todos';
  String _selectedPerson = 'Todos';

  // Date range filter for empresa view
  DateTimeRange? _selectedDateRange;

  // Vehicle-related document keywords (used to restrict docs for company view)
  static const List<String> _vehicleDocKeywords = [
    'soat',
    'tecnicomecanico',
    'tecnicomecánico',
    'poliza',
    'póliza',
    'seguro',
    'tarjeta de operación',
    'tarjeta de operacion',
    'revision',
    'revisión',
  ];

  bool _isVehicleDocument(_DocumentInfo d) {
    final String text = '${d.category} ${d.name}'.toLowerCase();
    return _vehicleDocKeywords.any((k) => text.contains(k));
  }

  List<String> get _availableDocTypes {
    final Set<String> types = {'Todos'};
    for (final d in _documents) {
      if (_role == 'empresa') {
        // Include categories for documents belonging to drivers or propietarios so empresa can filter by them
        if (d.ownerType == 'conductor' || d.ownerType == 'propietario') types.add(d.category);
      } else {
        types.add(d.category);
      }
    }
    final List<String> result = types.toList();
    result.sort((a,b) {
      if (a=='Todos') return -1;
      if (b=='Todos') return 1;
      return a.compareTo(b);
    });
    return result;
  }

  List<String> get _availablePeople {
    final Set<String> people = {'Todos'};
    for (final d in _documents) {
      final name = (d.ownerName.isNotEmpty) ? '${d.ownerName} (${d.ownerType})' : d.ownerType;
      people.add(name);
    }
    return people.toList();
  }

  List<String> get _availableVehicles {
    final Set<String> vehicles = {'Todos'};
    for (final d in _documents) {
      if (d.vehiclePlate.isNotEmpty) vehicles.add(d.vehiclePlate);
    }
    return vehicles.toList();
  }

  String _selectedVehicle = 'Todos';

  bool _groupByPerson = false; // toggle to group documents by owner

  // --- Helpers for filter presets and reset ---
  void _resetEmpresaFilters() {
    setState(() {
      _empresaSearch = '';
      _selectedDocType = 'Todos';
      _selectedPerson = 'Todos';
      _selectedDateRange = null;
      _selectedEmpresaFilter = _EmpresaFilter.all;
      _empresaSortAscending = true;
      _groupByPerson = false;
    });
  }

  DateTimeRange _presetDateRange(int days) {
    final DateTime start = DateTime.now();
    final DateTime end = start.add(Duration(days: days));
    return DateTimeRange(start: start, end: end);
  }

  Widget _empresaDocumentos() { 
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 560;
        final List<_DocumentInfo> filtered = _filteredEmpresaDocuments();
        final List<_DocumentInfo> topHighlights = filtered.where((d) => d.important || d.isNearExpiry || d.isExpired).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos de la empresa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Filtra, busca y prioriza los documentos de vehículos (SOAT, Tecnicomecánico, Pólizas, etc.) de tu empresa.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
              ),
              const SizedBox(height: 16),

              // Controls: main search + quick-search selector and magnifier
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, propietario o placa',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (v) => setState(() => _empresaSearch = v.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => setState(() => _empresaSortAscending = !_empresaSortAscending),
                          icon: Icon(_empresaSortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 12),

              // Quick-search row: type selector + small query + magnifier
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedQuickType,
                      dropdownColor: _cardColor,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(color: Colors.white),
                      items: _quickDocTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setState(() { if (v != null) _selectedQuickType = v; }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 12),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: _performQuickSearch,
                      icon: const Icon(Icons.search, color: Colors.white70),
                    ),
                  ),
                  if (_showQuickResults) ...[
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(10)),
                      child: IconButton(
                        onPressed: () => setState(() => _showQuickResults = false),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
                ],
              ),

              // Highlights strip (upcoming expiries)
              if (topHighlights.isNotEmpty) ...[
                _buildDocumentStrip(isCompact: isCompact, docs: topHighlights),
                const SizedBox(height: 20),
              ],

              // Document list (grouped or flat)
              if (_showQuickResults) ...[
                _buildGroupedList(isCompact: isCompact, docs: _quickResults),
              ] else if (_groupByPerson) ...[
                _buildGroupedList(isCompact: isCompact, docs: filtered),
              ] else ...[
                _buildDocumentList(isCompact: isCompact, docs: filtered),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<_DocumentInfo> _filteredEmpresaDocuments() {
    final String q = _empresaSearch.trim().toLowerCase();
    List<_DocumentInfo> list = List<_DocumentInfo>.from(_documents);

    // For empresa view, show all documents that belong to drivers or propietarios so the company can review them
    if (_role == 'empresa') {
      list = list.where((d) => d.ownerType == 'conductor' || d.ownerType == 'propietario').toList();
    }

    // filter by selected date range (expiry date)
    if (_selectedDateRange != null) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end;
      list = list.where((d) => !d.expiryDate.isBefore(start) && !d.expiryDate.isAfter(end)).toList();
    }

    // apply quick filters
    if (_selectedEmpresaFilter == _EmpresaFilter.important) {
      list = list.where((d) => d.important).toList();
    } else if (_selectedEmpresaFilter == _EmpresaFilter.nearExpiry) {
      list = list.where((d) => d.isNearExpiry && !d.isExpired).toList();
    } else if (_selectedEmpresaFilter == _EmpresaFilter.expired) {
      list = list.where((d) => d.isExpired).toList();
    } else if (_selectedEmpresaFilter == _EmpresaFilter.paid) {
      list = list.where((d) => d.paymentDate != null).toList();
    }

    // filter by document type
    if (_selectedDocType.isNotEmpty && _selectedDocType != 'Todos') {
      list = list.where((d) => d.category == _selectedDocType).toList();
    }

    // filter by person
    if (_selectedPerson.isNotEmpty && _selectedPerson != 'Todos') {
      list = list.where((d) {
        final String name = (d.ownerName.isNotEmpty) ? '${d.ownerName} (${d.ownerType})' : d.ownerType;
        return name == _selectedPerson;
      }).toList();
    }

    // search
    if (q.isNotEmpty) {
      list = list.where((d) => d.name.toLowerCase().contains(q) || d.ownerName.toLowerCase().contains(q)).toList();
    }

    list.sort((a, b) => _empresaSortAscending ? a.expiryDate.compareTo(b.expiryDate) : b.expiryDate.compareTo(a.expiryDate));
    return list;
  }

  void _performQuickSearch() {
    // Quick search by selected type only (no typing). Show documents grouped by person.
    final String selected = _selectedQuickType.trim();
    List<_DocumentInfo> candidates = _documents.where((d) => d.ownerType == 'conductor' || d.ownerType == 'propietario').toList();

    final List<_DocumentInfo> results = candidates.where((d) {
      if (selected == 'Personal') return true; // all personal documents
      return d.category.toLowerCase().contains(selected.toLowerCase());
    }).toList();

    results.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    setState(() {
      _quickResults = results;
      _showQuickResults = true;
      _groupByPerson = true;
    });
  }

  Widget _propietarioDocumentos() {
    return _buildComingSoon('propietario');
  }

  Widget _secretariaDocumentos() {
    return _buildComingSoon('secretaria');
  }

  Widget _adminDocumentos() {
    return _buildComingSoon('administrador');
  }

  Widget _buildComingSoon(String roleLabel) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          'Panel de documentos para $roleLabel en desarrollo',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(List<_DocumentInfo> docs) {
    final int total = docs.length;
    final int expiring = docs.where((d) => d.isNearExpiry && !d.isExpired).length;
    final int expired = docs.where((d) => d.isExpired).length;
    final int important = docs.where((d) => d.important).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSummaryCard('Total', total.toString(), Colors.white24),
        _buildSummaryCard('Por vencer', expiring.toString(), const Color(0xFFFF8E53)),
        _buildSummaryCard('Vencidos', expired.toString(), const Color(0xFFFF6B6B)),
        _buildSummaryCard('Importantes', important.toString(), _accentColor),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList({required bool isCompact, required List<_DocumentInfo> docs}) {
    final Map<String, List<_DocumentInfo>> grouped = {};
    for (final d in docs) {
      final String key = d.ownerName.isNotEmpty ? '${d.ownerName} (${d.ownerType})' : 'Empresa';
      grouped.putIfAbsent(key, () => []).add(d);
    }

    final entries = grouped.entries.toList();
    return Column(
      children: entries.map((entry) {
        final String person = entry.key;
        final List<_DocumentInfo> items = entry.value;
        return ExpansionTile(
          title: Text(person, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildDocumentList(isCompact: isCompact, docs: items),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  void _openModal(_DocumentInfo doc) {
    DocumentModal.show(
      context: context,
      documentName: doc.name,
      paymentDate: doc.paymentDate,
      expiryDate: doc.expiryDate,
    );
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
