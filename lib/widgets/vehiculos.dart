import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'document_modal.dart';

/// Visualiza los registros de la tabla vehiculos con filtros basados en estado y busqueda.
class VehiculosWidget extends StatefulWidget {
  final String role;
  final String? ownerId;
  final String? jsonPath;
  final bool showOwnerColumn;

  const VehiculosWidget({
    super.key,
    required this.role,
    this.ownerId,
    this.jsonPath,
    this.showOwnerColumn = false,
  });

  @override
  State<VehiculosWidget> createState() => _VehiculosWidgetState();
}

class _Vehicle {
  final int idVehiculo;
  final int idPropietario;
  final String placa;
  final String? vin;
  final String marca;
  final String modelo;
  final int? anio;
  final String? color;
  final int kilometrajeActual;
  final String estadoVehiculo;
  final DateTime? fechaCreacion;

  const _Vehicle({
    required this.idVehiculo,
    required this.idPropietario,
    required this.placa,
    required this.vin,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.color,
    required this.kilometrajeActual,
    required this.estadoVehiculo,
    required this.fechaCreacion,
  });

  String get statusKey => estadoVehiculo.toUpperCase();
}

class _VehiculosWidgetState extends State<VehiculosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);

  bool _isLoading = true;
  List<_Vehicle> _vehicles = const [];
  // Documents associated with vehicles (loaded for propietario role)
  List<Map<String, dynamic>> _vehicleDocuments = [];
  // Tracks expanded vehicle plates in the vehicles panel
  final Set<String> _expandedPlates = {};
  String? _statusFilter;
  String _searchTerm = '';
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    // For propietario/conductor/empresa roles, try to load vehicle documents from a typical owner dashboard asset
    if (widget.role.toLowerCase() == 'propietario' || widget.role.toLowerCase() == 'conductor' || widget.role.toLowerCase() == 'empresa') {
      _loadVehicleDocs();
    }
  }

  Future<void> _loadVehicles() async {
    final String assetPath = (widget.jsonPath != null && widget.jsonPath!.isNotEmpty)
        ? widget.jsonPath!
        : 'assets/vehicles_data.json';

    List<_Vehicle> parsed = [];
    try {
      final String raw = await rootBundle.loadString(assetPath);
      parsed = _parseVehicles(raw);
    } catch (e) {
      debugPrint('Error cargando vehiculos: $e');
    }

    if (parsed.isEmpty) {
      parsed = _fallbackVehicles();
    }

    parsed.sort((a, b) => a.placa.compareTo(b.placa));

    if (!mounted) {
      return;
    }

    setState(() {
      _vehicles = parsed;
      _isLoading = false;
    });
  }

  List<_Vehicle> _parseVehicles(String raw) {
    try {
      final dynamic decoded = json.decode(raw);
      final List<dynamic>? entries = decoded is Map<String, dynamic>
          ? decoded['vehiculos'] as List<dynamic>?
          : (decoded as List<dynamic>?);
      if (entries == null) {
        return const [];
      }

      return entries.map((dynamic item) {
        if (item is! Map<String, dynamic>) {
          return null;
        }
        final Map<String, dynamic> map = item;
        final int? id = int.tryParse(map['id_vehiculo']?.toString() ?? '');
        final int? owner = int.tryParse(map['id_propietario']?.toString() ?? '');
        if (id == null || owner == null) {
          return null;
        }
        final int kilometraje = int.tryParse(map['kilometraje_actual']?.toString() ?? '') ?? 0;
        final int? anio = int.tryParse(map['anio']?.toString() ?? '');
        final DateTime? fecha = DateTime.tryParse(map['fecha_creacion']?.toString() ?? '');
        return _Vehicle(
          idVehiculo: id,
          idPropietario: owner,
          placa: map['placa']?.toString() ?? 'SIN PLACA',
          vin: map['vin']?.toString(),
          marca: map['marca']?.toString() ?? 'Marca desconocida',
          modelo: map['modelo']?.toString() ?? 'Modelo desconocido',
          anio: anio,
          color: map['color']?.toString(),
          kilometrajeActual: kilometraje,
          estadoVehiculo: map['estado_vehiculo']?.toString() ?? 'ACTIVO',
          fechaCreacion: fecha,
        );
      }).whereType<_Vehicle>().toList();
    } catch (e) {
      debugPrint('Error parseando vehiculos: $e');
      return const [];
    }
  }

  Future<void> _loadVehicleDocs() async {
    // Try common owner dashboard asset first, then fallback to a generic documents list
    final List<String> candidates = [
      'assets/propietario_dashboard.json',
      'assets/documents_data.json',
      'assets/propietario_documents.json',
    ];

    for (final path in candidates) {
      try {
        final String raw = await rootBundle.loadString(path);
        final dynamic decoded = json.decode(raw);
        final List<dynamic>? docs = decoded is Map<String, dynamic> ? decoded['documents'] as List<dynamic>? : null;
        if (docs != null) {
          _vehicleDocuments = docs.whereType<Map<String, dynamic>>().map((m) => Map<String, dynamic>.from(m)).toList();
          debugPrint('VehiculosWidget: loaded ${_vehicleDocuments.length} vehicle documents from $path');
          return;
        }
      } catch (_) {
        // ignore and try next
      }
    }

    debugPrint('VehiculosWidget: no vehicle documents asset found (tried candidates)');
  }

  List<_Vehicle> _fallbackVehicles() {
    final DateTime now = DateTime.now();
    return [
      _Vehicle(
        idVehiculo: 1,
        idPropietario: 12,
        placa: 'ABC000',
        vin: 'FAKEVIN0001',
        marca: 'Marca demo',
        modelo: 'Modelo demo',
        anio: 2022,
        color: 'Blanco',
        kilometrajeActual: 25000,
        estadoVehiculo: 'ACTIVO',
        fechaCreacion: now.subtract(const Duration(days: 180)),
      ),
      _Vehicle(
        idVehiculo: 2,
        idPropietario: 12,
        placa: 'DEF111',
        vin: 'FAKEVIN0002',
        marca: 'Marca demo',
        modelo: 'Bus',
        anio: 2020,
        color: 'Rojo',
        kilometrajeActual: 90000,
        estadoVehiculo: 'MANTENIMIENTO',
        fechaCreacion: now.subtract(const Duration(days: 420)),
      ),
    ];
  }

  List<_Vehicle> get _filteredVehicles {
    Iterable<_Vehicle> filtered = _vehicles;

    if (widget.ownerId != null && widget.ownerId!.isNotEmpty) {
      final int? owner = int.tryParse(widget.ownerId!);
      if (owner != null) {
        final List<_Vehicle> ownerMatches = filtered.where((vehicle) => vehicle.idPropietario == owner).toList();
        if (ownerMatches.isNotEmpty) {
          filtered = ownerMatches;
        }
      }
    }

    if (_statusFilter != null) {
      final String normalized = _statusFilter!;
      filtered = filtered.where((vehicle) => vehicle.statusKey == normalized);
    }

    if (_searchTerm.isNotEmpty) {
      final String lower = _searchTerm.toLowerCase();
      filtered = filtered.where((vehicle) {
        return vehicle.placa.toLowerCase().contains(lower) ||
            (vehicle.marca.toLowerCase().contains(lower)) ||
            (vehicle.modelo.toLowerCase().contains(lower));
      });
    }

    final List<_Vehicle> result = filtered.toList();
    result.sort((a, b) => a.placa.compareTo(b.placa));
    return result;
  }

  void _setStatusFilter(String status) {
    final String normalized = status.toUpperCase();
    setState(() {
      _statusFilter = _statusFilter == normalized ? null : normalized;
    });
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _searchTerm = '';
    });
  }

  Map<String, int> get _statusCounts {
    final Map<String, int> counts = <String, int>{};
    for (final _Vehicle vehicle in _vehicles) {
      counts.update(vehicle.statusKey, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Color _statusColor(String status) {
    final String normalized = status.toUpperCase();
    if (normalized == 'ACTIVO') {
      return _successColor;
    }
    if (normalized == 'MANTENIMIENTO' || normalized == 'MANTENIMIENTO PROGRAMADO') {
      return _warningColor;
    }
    if (normalized == 'INACTIVO' || normalized == 'FUERA DE SERVICIO') {
      return _dangerColor;
    }
    return _accentColor;
  }

  DateTime? _parseDocDate(String? raw) {
    if (raw == null) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  void _openVehicleDocument(Map<String, dynamic> doc, String plate) {
    final String name = doc['name']?.toString() ?? 'Documento';
    final DateTime? expiry = _parseDocDate(doc['expiryDate']?.toString());
    final DateTime? payment = _parseDocDate(doc['paymentDate']?.toString());

    if (expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay fecha de vencimiento disponible para este documento.'),
          backgroundColor: Color(0xFFE66B6B),
        ),
      );
      return;
    }

    DocumentModal.show(
      context: context,
      documentName: '$name • $plate',
      paymentDate: payment,
      expiryDate: expiry,
    );
  }

  int _docsCountForPlate(String plate) {
    if (_vehicleDocuments.isEmpty) {
      return 0;
    }
    String normalize(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final String target = normalize(plate);
    return _vehicleDocuments.where((d) {
      final String v1 = (d['vehicle']?.toString() ?? '').trim();
      final String v2 = (d['vehiclePlate']?.toString() ?? '').trim();
      return normalize(v1) == target || normalize(v2) == target;
    }).length;
  }

  Widget _buildVehicleDocumentsList(String plate, bool isCompact) {
    // Normalize plate strings for comparison
    String normalize(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final String target = normalize(plate);
    final List<Map<String, dynamic>> docs = _vehicleDocuments.where((d) {
      final String v1 = (d['vehicle']?.toString() ?? '').trim();
      final String v2 = (d['vehiclePlate']?.toString() ?? '').trim();
      return normalize(v1) == target || normalize(v2) == target;
    }).toList();

    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No hay documentos para $plate', style: const TextStyle(color: Colors.white70)),
      );
    }

    return Column(
      children: docs.map((d) {
        final String name = d['name']?.toString() ?? 'Documento';
        final DateTime? expiry = _parseDocDate(d['expiryDate']?.toString());
        final DateTime? payment = _parseDocDate(d['paymentDate']?.toString());
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openVehicleDocument(d, plate),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white54, size: isCompact ? 18 : 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Vencimiento: ${expiry != null ? _dateFormat.format(expiry) : 'Sin fecha'}', style: const TextStyle(color: Colors.white70)),
                      if (payment != null) Text('Pago: ${_dateFormat.format(payment)}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Ver detalle y descargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _statusLabel(String status) {
    if (status.isEmpty) {
      return 'Desconocido';
    }
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }
    return _dateFormat.format(value);
  }

  Widget _buildDetailRow(String label, String value, bool isCompact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isCompact ? 80 : 100,
            child: Text(label, style: TextStyle(color: Colors.white70, fontSize: isCompact ? 10 : 11)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.white, fontSize: isCompact ? 10 : 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<_Vehicle> filtered = _filteredVehicles;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 620;
        final int gridColumns = isCompact ? 1 : 2;
        
        // Calcular childAspectRatio para que la altura sea fija
        final double paddingHorizontal = isCompact ? 16 : 24;
        final double totalPadding = paddingHorizontal * 2;
        final double spacingWidth = isCompact ? 0 : 16; // spacing entre columnas
        final double availableWidth = constraints.maxWidth - totalPadding - spacingWidth;
        final double cardWidth = availableWidth / gridColumns;
        final double fixedHeight = isCompact ? 160 : 195; // altura fija, mayor en PC
        final double dynamicChildAspectRatio = cardWidth / fixedHeight;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehiculos registrados',
                style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Consulta la flota disponible y su estado operativo.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 12),
              ),
              const SizedBox(height: 14),
              _buildFiltersRow(isCompact),
              const SizedBox(height: 12),
              _buildStatusChips(isCompact),
              const SizedBox(height: 14),
              if (_statusFilter != null || _searchTerm.isNotEmpty)
                _buildActiveFiltersBanner(isCompact),
              if (filtered.isEmpty)
                _buildEmptyFilteredMessage(isCompact)
              else
                GridView.count(
                  crossAxisCount: gridColumns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: isCompact ? 8 : 8,
                  crossAxisSpacing: isCompact ? 14 : 16,
                  childAspectRatio: dynamicChildAspectRatio,
                  children: filtered.map((vehicle) => _buildVehicleCard(vehicle, isCompact)).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFiltersRow(bool isCompact) {
    return Row(
      children: [
        Expanded(child: _buildSearchField(isCompact)),
        SizedBox(width: isCompact ? 10 : 10),
        TextButton.icon(
          onPressed: _clearFilters,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 6 : 8),
          ),
          icon: Icon(Icons.clear_all, size: isCompact ? 16 : 16),
          label: Text('Limpiar', style: TextStyle(fontSize: isCompact ? 11 : 11)),
        ),
      ],
    );
  }

  Widget _buildSearchField(bool isCompact) {
    return TextField(
      onChanged: (value) => setState(() {
        _searchTerm = value.trim();
      }),
      style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13),
      decoration: InputDecoration(
        hintText: 'Buscar por placa, marca o modelo',
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        prefixIcon: Icon(Icons.search, color: Colors.white54, size: isCompact ? 16 : 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 6, horizontal: isCompact ? 10 : 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
          borderSide: const BorderSide(color: Color(0xFF4F4CE8)),
        ),
      ),
    );
  }

  Widget _buildStatusChips(bool isCompact) {
    final Map<String, int> counts = _statusCounts;
    final List<String> orderedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    if (orderedKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: isCompact ? 8 : 10,
      runSpacing: isCompact ? 8 : 10,
      children: orderedKeys.map((key) {
        final bool selected = _statusFilter == key;
        return GestureDetector(
          onTap: () => _setStatusFilter(key),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 6 : 7),
              decoration: BoxDecoration(
                color: selected
                  ? _statusColor(key).withValues(alpha: 0.28)
                  : _statusColor(key).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? _statusColor(key) : _statusColor(key).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? Icons.check_circle : Icons.circle, color: _statusColor(key), size: 12),
                  const SizedBox(width: 5),
                  Text(
                    _statusLabel(key),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 10 : 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    counts[key].toString(),
                    style: TextStyle(color: Colors.white, fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveFiltersBanner(bool isCompact) {
    final List<String> badges = <String>[];
    if (_statusFilter != null) {
      badges.add('Estado: ${_statusLabel(_statusFilter!)}');
    }
    if (_searchTerm.isNotEmpty) {
      badges.add('Busqueda: $_searchTerm');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt, color: Colors.white70, size: isCompact ? 18 : 20),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: badges
                  .map((label) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(label, style: TextStyle(color: Colors.white, fontSize: isCompact ? 11 : 12)),
                      ))
                  .toList(),
            ),
          ),
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilteredMessage(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No hay vehiculos con los filtros actuales', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Prueba con otro estado, ajusta la busqueda o limpia los filtros.',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(_Vehicle vehicle, bool isCompact) {
    final String plate = vehicle.placa.trim();
    final String role = widget.role.toLowerCase();
    final bool isDriverLike = role == 'conductor' || role == 'empresa';
    final bool canExpandDocs = role == 'propietario' || isDriverLike;
    const int totalDocs = 5;
    final int completedDocs = _docsCountForPlate(plate).clamp(0, totalDocs);
    final double progress = (completedDocs / totalDocs).clamp(0.0, 1.0);
    final Color barColor = progress >= 1 ? _successColor : _warningColor;

    Widget card = Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 14, vertical: isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: _cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.placa, style: TextStyle(color: Colors.white, fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicle.marca} • ${vehicle.modelo}${vehicle.anio != null ? ' • $vehicle.anio' : ''}',
                      style: TextStyle(color: Colors.white70, fontSize: isCompact ? 10 : 11),
                    ),
                  ],
                ),
              ),
              _buildStatusTag(vehicle.estadoVehiculo, isCompact),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: isCompact ? 8 : 12,
            runSpacing: isCompact ? 6 : 8,
            children: [
              if (widget.showOwnerColumn)
                _buildInfoChip(Icons.person, 'Prop ${vehicle.idPropietario}', isCompact),
              if (vehicle.color != null && vehicle.color!.isNotEmpty)
                _buildInfoChip(Icons.color_lens, vehicle.color!, isCompact),
              if (isDriverLike && vehicle.anio != null)
                _buildInfoChip(Icons.calendar_today, 'Año ${vehicle.anio}', isCompact),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Docs: $completedDocs/$totalDocs',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 10 : 11),
          ),
          if (isDriverLike) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Estado', _statusLabel(vehicle.estadoVehiculo), isCompact),
          ],
        ],
      ),
    );

    // If role propietario/conductor enable modal on tap to show vehicle documents
    if (canExpandDocs) {
      return GestureDetector(
        onTap: () => _showVehicleModal(vehicle, isCompact),
        child: card,
      );
    }

    return card;
  }

  void _showVehicleModal(_Vehicle vehicle, bool isCompact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF151B47),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(maxWidth: isCompact ? 400 : 600, maxHeight: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.placa,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle.marca} • ${vehicle.modelo}${vehicle.anio != null ? ' • ${vehicle.anio}' : ''}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildVehicleDocumentsList(vehicle.placa, isCompact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 5 : 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: isCompact ? 13 : 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: isCompact ? 10 : 11)),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status, bool isCompact) {
    final Color color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: Colors.white, fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
