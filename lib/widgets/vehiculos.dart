import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  String? _statusFilter;
  String _searchTerm = '';
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadVehicles();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<_Vehicle> filtered = _filteredVehicles;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 620;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehiculos registrados',
                style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Consulta la flota disponible y su estado operativo.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
              ),
              const SizedBox(height: 20),
              _buildFiltersRow(isCompact),
              const SizedBox(height: 16),
              _buildStatusChips(isCompact),
              const SizedBox(height: 20),
              if (_statusFilter != null || _searchTerm.isNotEmpty)
                _buildActiveFiltersBanner(isCompact),
              if (filtered.isEmpty)
                _buildEmptyFilteredMessage(isCompact)
              else
                ...filtered.map((vehicle) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _buildVehicleCard(vehicle, isCompact),
                    )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFiltersRow(bool isCompact) {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: _clearFilters,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.08),
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 12),
          ),
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Limpiar'),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() {
        _searchTerm = value.trim();
      }),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Buscar por placa, marca o modelo',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
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
      spacing: 12,
      runSpacing: 12,
      children: orderedKeys.map((key) {
        final bool selected = _statusFilter == key;
        return GestureDetector(
          onTap: () => _setStatusFilter(key),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? _statusColor(key).withOpacity(0.28)
                    : _statusColor(key).withOpacity(0.18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: selected ? _statusColor(key) : _statusColor(key).withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? Icons.check_circle : Icons.circle, color: _statusColor(key), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel(key),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    counts[key].toString(),
                    style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.w700),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                          color: Colors.white.withOpacity(0.08),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20, vertical: isCompact ? 18 : 22),
      decoration: BoxDecoration(
        color: _cardColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 12)),
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
                    Text(vehicle.placa, style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      '${vehicle.marca} • ${vehicle.modelo}${vehicle.anio != null ? ' • ${vehicle.anio}' : ''}',
                      style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
                    ),
                  ],
                ),
              ),
              _buildStatusTag(vehicle.estadoVehiculo),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildInfoChip(Icons.confirmation_number, 'ID ${vehicle.idVehiculo}'),
              if (widget.showOwnerColumn)
                _buildInfoChip(Icons.person, 'Propietario ${vehicle.idPropietario}'),
              if (vehicle.vin != null && vehicle.vin!.isNotEmpty)
                _buildInfoChip(Icons.credit_card, 'VIN ${vehicle.vin}'),
              if (vehicle.color != null && vehicle.color!.isNotEmpty)
                _buildInfoChip(Icons.color_lens, vehicle.color!),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.speed, color: Colors.white54, size: isCompact ? 18 : 20),
              const SizedBox(width: 8),
              Text('${vehicle.kilometrajeActual} km', style: TextStyle(color: Colors.white, fontSize: isCompact ? 13 : 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.event_available, color: Colors.white54, size: isCompact ? 18 : 20),
              const SizedBox(width: 8),
              Text(_formatDate(vehicle.fechaCreacion), style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    final Color color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
