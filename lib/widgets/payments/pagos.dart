import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class PagosWidget extends StatefulWidget {
  final String role;
  final String? userId;
  final String? jsonPath;
  final String? vehicleId;

  const PagosWidget({
    super.key,
    required this.role,
    this.userId,
    this.jsonPath,
    this.vehicleId,
  });

  @override
  State<PagosWidget> createState() => _PagosWidgetState();
}

class _Payment {
  final int idPago;
  final String idUsuario;
  final String? idVehiculo;
  final String concepto;
  final double monto;
  final DateTime? fechaPago;
  final String estado;
  final String? urlRecibo;
  final String roleDestino;

  const _Payment({
    required this.idPago,
    required this.idUsuario,
    required this.idVehiculo,
    required this.concepto,
    required this.monto,
    required this.fechaPago,
    required this.estado,
    required this.urlRecibo,
    required this.roleDestino,
  });

  bool get isPending => estado.toUpperCase() == 'PENDIENTE';
  bool get isPaid => estado.toUpperCase() == 'PAGADO';
  bool get isOverdue => estado.toUpperCase() == 'VENCIDO';
}

class _PagosWidgetState extends State<PagosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);

  bool _isLoading = true;
  late String _role;
  List<_Payment> _payments = const [];
  List<_Payment> _allPayments = const [];
  String? _statusFilter;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: 'COP \$',
    decimalDigits: 0,
  );

  List<_Payment> get _visiblePayments {
    if (_statusFilter == null) {
      return _payments;
    }
    final String normalized = _statusFilter!;
    return _payments.where((payment) => payment.estado.toUpperCase() == normalized).toList();
  }

  void _toggleStatusFilter(String status) {
    final String normalized = status.toUpperCase();
    setState(() {
      _statusFilter = _statusFilter == normalized ? null : normalized;
    });
  }

  void _clearStatusFilter() {
    if (_statusFilter == null) {
      return;
    }
    setState(() {
      _statusFilter = null;
    });
  }

  bool _isFilterActive(String status) {
    return _statusFilter == status.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _role = widget.role.trim().isEmpty ? 'conductor' : widget.role.trim().toLowerCase();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final String assetPath = (widget.jsonPath != null && widget.jsonPath!.isNotEmpty)
        ? widget.jsonPath!
        : 'assets/payments_data.json';

    List<_Payment> parsed = [];
    try {
      final String raw = await rootBundle.loadString(assetPath);
      parsed = _parsePayments(raw);
    } catch (_) {
    }

    if (parsed.isEmpty) {
      parsed = _fallbackPayments();
    }

    final List<_Payment> filtered = _filterPayments(parsed);

    if (!mounted) {
      return;
    }

    setState(() {
      _allPayments = parsed;
      _payments = filtered;
      _isLoading = false;
    });
  }

  List<_Payment> _parsePayments(String raw) {
    try {
      final dynamic decoded = json.decode(raw);
      final List<dynamic>? entries = decoded is Map<String, dynamic>
          ? decoded['pagos'] as List<dynamic>?
          : (decoded as List<dynamic>?);

      if (entries == null) {
        return [];
      }

      return entries.map((dynamic item) {
        if (item is! Map<String, dynamic>) {
          return null;
        }

        final Map<String, dynamic> map = item;
        final int? idPago = int.tryParse(map['id_pago']?.toString() ?? '');
        if (idPago == null) {
          return null;
        }

        final double? monto = double.tryParse(map['monto']?.toString() ?? '');
        final DateTime? fecha = DateTime.tryParse(map['fecha_pago']?.toString() ?? '');

        return _Payment(
          idPago: idPago,
          idUsuario: map['id_usuario']?.toString() ?? '',
          idVehiculo: map['id_vehiculo']?.toString().isEmpty == true ? null : map['id_vehiculo']?.toString(),
          concepto: map['concepto']?.toString() ?? 'Pago sin concepto',
          monto: monto ?? 0,
          fechaPago: fecha,
          estado: map['estado']?.toString() ?? 'PENDIENTE',
          urlRecibo: map['url_recibo']?.toString(),
          roleDestino: map['rol_destino']?.toString().toLowerCase() ?? 'conductor',
        );
      }).whereType<_Payment>().toList();
    } catch (_) {
      return [];
    }
  }

  List<_Payment> _fallbackPayments() {
    final DateTime today = DateTime.now();
    return [
      _Payment(
        idPago: 1,
        idUsuario: '1',
        idVehiculo: 'VH-001',
        concepto: 'Cuota de leasing',
        monto: 450000,
        fechaPago: today.add(const Duration(days: 12)),
        estado: 'PENDIENTE',
        urlRecibo: null,
        roleDestino: 'conductor',
      ),
      _Payment(
        idPago: 2,
        idUsuario: '1',
        idVehiculo: 'VH-001',
        concepto: 'Mantenimiento preventivo',
        monto: 180000,
        fechaPago: today.subtract(const Duration(days: 10)),
        estado: 'PAGADO',
        urlRecibo: null,
        roleDestino: 'conductor',
      ),
      _Payment(
        idPago: 3,
        idUsuario: '12',
        idVehiculo: 'VH-301',
        concepto: 'Impuesto departamental',
        monto: 310000,
        fechaPago: today.subtract(const Duration(days: 4)),
        estado: 'VENCIDO',
        urlRecibo: null,
        roleDestino: 'propietario',
      ),
    ];
  }

  List<_Payment> _filterPayments(List<_Payment> source) {
    List<_Payment> rolePayments = source.where((payment) => payment.roleDestino == _role).toList();

    if (rolePayments.isEmpty) {
      rolePayments = source;
    }

    if ((_role == 'conductor' || _role == 'propietario') && widget.userId != null) {
      final List<_Payment> userSpecific = rolePayments.where((payment) => payment.idUsuario == widget.userId).toList();
      if (userSpecific.isNotEmpty) {
        rolePayments = userSpecific;
      }
    }

    if (widget.vehicleId != null && widget.vehicleId!.isNotEmpty) {
      final List<_Payment> vehicleSpecific = rolePayments.where((payment) => payment.idVehiculo == widget.vehicleId).toList();
      if (vehicleSpecific.isNotEmpty) {
        rolePayments = vehicleSpecific;
      }
    }

    rolePayments.sort((a, b) {
      final DateTime aDate = a.fechaPago ?? DateTime(2100);
      final DateTime bDate = b.fechaPago ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    return rolePayments;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 640;

        if (_payments.isEmpty) {
          return _buildEmptyState(isCompact);
        }

        switch (_role) {
          case 'conductor':
            return _buildConductorView(isCompact);
          case 'propietario':
            return _buildPropietarioView(isCompact);
          case 'secretaria':
            return _buildSecretariaView(isCompact);
          case 'admin':
            return _buildAdminView(isCompact);
          default:
            return _buildGenericView(isCompact);
        }
      },
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 32 : 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, color: Colors.white54, size: isCompact ? 48 : 56),
            const SizedBox(height: 18),
            Text(
              'No hay pagos registrados para este rol.',
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando se creen registros en la tabla pagos se mostraran aqui de forma automatica.',
              style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(bool isCompact) {
    final String label = _statusFilter != null ? _capitalize(_statusFilter!) : 'filtro actual';
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 24 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, color: Colors.white54, size: isCompact ? 48 : 56),
            const SizedBox(height: 18),
            Text(
              'No hay pagos con estado $label.',
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona otro estado o limpia el filtro para ver todos los registros.',
              style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _clearStatusFilter,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Limpiar filtro'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBanner(bool isCompact) {
    if (_statusFilter == null) {
      return const SizedBox.shrink();
    }
    final String label = _capitalize(_statusFilter!);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, color: Colors.white70, size: isCompact ? 18 : 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Filtro activo: $label',
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _clearStatusFilter,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredListMessage(bool isCompact) {
    final String label = _statusFilter != null ? _capitalize(_statusFilter!) : 'filtro actual';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 18, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sin pagos con estado $label',
            style: TextStyle(color: Colors.white, fontSize: isCompact ? 14 : 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona otro estado o limpia el filtro para ver todos los pagos.',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _clearStatusFilter,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Limpiar filtro'),
          ),
        ],
      ),
    );
  }

  Widget _buildConductorView(bool isCompact) {
    if (_payments.isEmpty) {
      return _buildEmptyState(isCompact);
    }

    final List<_Payment> filtered = _visiblePayments;
    final _Payment nextPending = _payments.firstWhere(
      (payment) => payment.isPending,
      orElse: () => _payments.first,
    );

    final int pendingCount = _payments.where((payment) => payment.isPending).length;
    final int paidCount = _payments.where((payment) => payment.isPaid).length;
    final int overdueCount = _payments.where((payment) => payment.isOverdue).length;
    final double pendingAmount = _payments
        .where((payment) => payment.isPending)
        .fold(0, (double sum, payment) => sum + payment.monto);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pagos del conductor',
            style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Consulta tus obligaciones financieras, su estado y la fecha objetivo.',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
          ),
          const SizedBox(height: 20),
          _buildActiveFilterBanner(isCompact),
          if (_statusFilter != null) const SizedBox(height: 4),
          _buildHighlightedPayment(nextPending, pendingAmount, pendingCount, isCompact),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildMetricChip('Pendientes', pendingCount.toString(), _warningColor, statusKey: 'PENDIENTE'),
              _buildMetricChip('Pagados', paidCount.toString(), _successColor, statusKey: 'PAGADO'),
              _buildMetricChip('Vencidos', overdueCount.toString(), _dangerColor, statusKey: 'VENCIDO'),
            ],
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            _buildFilteredListMessage(isCompact)
          else
            ...filtered.map((payment) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildPaymentCard(payment, isCompact: isCompact),
                )),
        ],
      ),
    );
  }

  Widget _buildHighlightedPayment(_Payment payment, double pendingAmount, int pendingCount, bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 18 : 24, vertical: isCompact ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            _accentColor,
            _accentColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Proximo compromiso', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: isCompact ? 12 : 13)),
          const SizedBox(height: 8),
          Text(payment.concepto, style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: Colors.white, size: isCompact ? 16 : 18),
              const SizedBox(width: 8),
              Text(
                payment.fechaPago != null ? _dateFormat.format(payment.fechaPago!) : 'Sin fecha programada',
                style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13),
              ),
              const Spacer(),
              Text(_formatCurrency(pendingAmount), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isCompact ? 14 : 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pendingCount == 1
                ? 'Tienes 1 pago pendiente por completar.'
                : 'Tienes $pendingCount pagos pendientes en la cola.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: isCompact ? 12 : 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPropietarioView(bool isCompact) {
    final List<_Payment> visible = _visiblePayments;
    if (visible.isEmpty) {
      return _buildFilteredEmptyState(isCompact);
    }

    final Map<String, List<_Payment>> byVehicle = <String, List<_Payment>>{};
    for (final _Payment payment in visible) {
      final String key = payment.idVehiculo ?? 'Sin vehiculo';
      byVehicle.putIfAbsent(key, () => <_Payment>[]).add(payment);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flujo de pagos por vehiculo', style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Visualiza las obligaciones de cada unidad y detecta atrasos.', style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
          const SizedBox(height: 20),
          _buildActiveFilterBanner(isCompact),
          if (_statusFilter != null) const SizedBox(height: 4),
          ...byVehicle.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildVehicleCard(entry.key, entry.value, isCompact),
              )),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(String vehicleId, List<_Payment> payments, bool isCompact) {
    final double totalPending = payments.where((payment) => payment.isPending).fold(0, (double sum, payment) => sum + payment.monto);
    final int overdue = payments.where((payment) => payment.isOverdue).length;

    return Container(
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: isCompact ? 20 : 22),
              const SizedBox(width: 10),
              Text(vehicleId, style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildMetricChip('Pendiente', _formatCurrency(totalPending), _warningColor, dense: true),
            ],
          ),
          const SizedBox(height: 16),
          ...payments.map((payment) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildPaymentRow(payment, isCompact: isCompact),
              )),
          if (overdue > 0)
            Text(
              overdue == 1 ? 'Hay 1 pago vencido en este vehiculo.' : 'Hay $overdue pagos vencidos en este vehiculo.',
              style: TextStyle(color: _dangerColor, fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _buildSecretariaView(bool isCompact) {
    final List<_Payment> visible = _visiblePayments;
    if (visible.isEmpty) {
      return _buildFilteredEmptyState(isCompact);
    }

    final Map<String, List<_Payment>> byStatus = <String, List<_Payment>>{};
    for (final _Payment payment in _payments) {
      final String key = payment.estado.toUpperCase();
      byStatus.putIfAbsent(key, () => <_Payment>[]).add(payment);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 12),
            child: Text('Seguimiento de pagos', style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          _buildActiveFilterBanner(isCompact),
          if (_statusFilter != null) const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              dataTextStyle: const TextStyle(color: Colors.white70),
              columnSpacing: isCompact ? 28 : 48,
              columns: const [
                DataColumn(label: Text('Concepto')),
                DataColumn(label: Text('Usuario')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Monto')),
              ],
              rows: visible.map((payment) {
                return DataRow(cells: [
                  DataCell(Text(payment.concepto)),
                  DataCell(Text(payment.idUsuario)),
                  DataCell(_buildStatusTag(payment.estado)),
                  DataCell(Text(payment.fechaPago != null ? _dateFormat.format(payment.fechaPago!) : 'Sin fecha')),
                  DataCell(Text(_formatCurrency(payment.monto))),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: byStatus.entries.map((entry) {
              final double total = entry.value.fold(0, (double sum, payment) => sum + payment.monto);
              return _buildMetricChip('${_capitalize(entry.key)} (${entry.value.length})', _formatCurrency(total), _statusColor(entry.key), dense: false, statusKey: entry.key);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminView(bool isCompact) {
    final List<_Payment> visible = _visiblePayments;
    if (visible.isEmpty) {
      return _buildFilteredEmptyState(isCompact);
    }

    final Map<String, List<_Payment>> byStatus = _groupByStatus(_allPayments);
    final double totalGeneral = _allPayments.fold(0, (double sum, payment) => sum + payment.monto);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vision general de pagos', style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Consolida la informacion proveniente de todos los roles.', style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
          const SizedBox(height: 20),
          _buildActiveFilterBanner(isCompact),
          if (_statusFilter != null) const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildMetricChip('Registros', _allPayments.length.toString(), _accentColor),
              _buildMetricChip('Monto total', _formatCurrency(totalGeneral), _accentColor),
              ...byStatus.entries.map((entry) {
                final double subtotal = entry.value.fold(0, (double sum, payment) => sum + payment.monto);
                return _buildMetricChip(_capitalize(entry.key), _formatCurrency(subtotal), _statusColor(entry.key), statusKey: entry.key);
              }),
            ],
          ),
          const SizedBox(height: 24),
          ...visible.map((payment) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPaymentCard(payment, isCompact: isCompact),
              )),
        ],
      ),
    );
  }

  Widget _buildGenericView(bool isCompact) {
    final List<_Payment> visible = _visiblePayments;
    if (visible.isEmpty) {
      return _buildFilteredEmptyState(isCompact);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pagos registrados', style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _buildActiveFilterBanner(isCompact),
          if (_statusFilter != null) const SizedBox(height: 8),
          ...visible.map((payment) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPaymentCard(payment, isCompact: isCompact),
              )),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(_Payment payment, {required bool isCompact}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20, vertical: isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: _cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 12)),
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
                    Text(payment.concepto, style: TextStyle(color: Colors.white, fontSize: isCompact ? 15 : 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Usuario ${payment.idUsuario}', style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
                  ],
                ),
              ),
              _buildStatusTag(payment.estado),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: Colors.white54, size: isCompact ? 16 : 18),
              const SizedBox(width: 8),
              Text(payment.fechaPago != null ? _dateFormat.format(payment.fechaPago!) : 'Sin fecha programada', style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
              const Spacer(),
              Text(_formatCurrency(payment.monto), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: isCompact ? 14 : 15)),
            ],
          ),
          if (payment.idVehiculo != null || payment.urlRecibo != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (payment.idVehiculo != null) ...[
                  Icon(Icons.directions_car_rounded, color: Colors.white54, size: isCompact ? 16 : 18),
                  const SizedBox(width: 8),
                  Text(payment.idVehiculo!, style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
                ],
                if (payment.idVehiculo != null && payment.urlRecibo != null) const SizedBox(width: 16),
                if (payment.urlRecibo != null)
                  InkWell(
                    onTap: null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, color: Colors.white54, size: isCompact ? 16 : 18),
                          const SizedBox(width: 6),
                          Text('Recibo', style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(_Payment payment, {required bool isCompact}) {
    final DateTime? fechaPago = payment.fechaPago;
    final String fechaTexto = fechaPago != null ? _dateFormat.format(fechaPago) : 'Sin fecha';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(payment.concepto, style: TextStyle(color: Colors.white, fontSize: isCompact ? 13 : 14, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(fechaTexto, style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(_formatCurrency(payment.monto), style: TextStyle(color: Colors.white, fontSize: isCompact ? 13 : 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 18),
          _buildStatusTag(payment.estado),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color, {bool dense = false, String? statusKey}) {
    final bool isSelected = statusKey != null && _isFilterActive(statusKey);

    final Widget content = Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 8 : 10),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.28) : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSelected ? Icons.check_circle : Icons.circle, color: color, size: dense ? 12 : 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: dense ? 11 : 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (statusKey == null) {
      return content;
    }

    return GestureDetector(
      onTap: () => _toggleStatusFilter(statusKey),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: content,
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    final String normalized = status.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(normalized).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _statusColor(normalized).withValues(alpha: 0.5)),
      ),
      child: Text(
        _capitalize(normalized),
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _statusColor(String status) {
    final String normalized = status.toUpperCase();
    if (normalized == 'PAGADO') {
      return _successColor;
    }
    if (normalized == 'PENDIENTE') {
      return _warningColor;
    }
    if (normalized == 'VENCIDO') {
      return _dangerColor;
    }
    return _accentColor;
  }

  String _formatCurrency(double value) {
    return _currencyFormat.format(value);
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Map<String, List<_Payment>> _groupByStatus(List<_Payment> payments) {
    final Map<String, List<_Payment>> grouped = <String, List<_Payment>>{};
    for (final _Payment payment in payments) {
      final String key = payment.estado.toUpperCase();
      grouped.putIfAbsent(key, () => <_Payment>[]).add(payment);
    }
    return grouped;
  }
}
