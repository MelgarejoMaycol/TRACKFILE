import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontendproyecto/utils/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class PropietariosWidget extends StatefulWidget {
  const PropietariosWidget({super.key});

  @override
  State<PropietariosWidget> createState() => _PropietariosWidgetState();
}

class _PropietariosWidgetState extends State<PropietariosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);

  List<Map<String, dynamic>> _propietarios = [];
  bool _isLoading = true;
  String? _error;
  String _baseUrl = ApiConfig.fallbackBaseUrl();

  @override
  void initState() {
    super.initState();
    _initBaseUrl();
    _loadPropietarios();
  }

  Future<void> _initBaseUrl() async {
    final resolved = await ApiConfig.loadBaseUrl();
    if (!mounted) return;
    _baseUrl = resolved;
  }

  Future<void> _loadPropietarios() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Obtener token de SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('No hay sesión activa');
      }

      final uri = ApiConfig.resolve(_baseUrl, '/api/propietarios');
      debugPrint('🔗 Llamando a: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 Respuesta: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final List<Map<String, dynamic>> propietarios = data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        setState(() {
          _propietarios = propietarios;
          _isLoading = false;
        });
        
        debugPrint('✅ ${propietarios.length} propietarios cargados');
      } else if (response.statusCode == 403) {
        throw Exception('Acceso denegado. No tienes permisos para ver los propietarios.');
      } else if (response.statusCode == 404) {
        setState(() {
          _propietarios = [];
          _isLoading = false;
        });
        debugPrint('⚠️ No se encontraron propietarios');
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando propietarios: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadOwnerDetail(int ownerId, Function(Map<String, dynamic>) onSuccess) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('No hay sesión activa');
      }

      final uri = ApiConfig.resolve(_baseUrl, '/api/propietarios/$ownerId/detalle');
      debugPrint('🔗 Llamando a: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        onSuccess(data);
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando detalle: $e');
    }
  }

  Widget _buildEmptyState(String title, String message) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }

  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE66B6B), size: 48),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar propietarios',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadPropietarios,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
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
          // 3 skeleton cards
          ...List.generate(3, (index) {
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
                  Shimmer.fromColors(
                    baseColor: Colors.white.withValues(alpha: 0.1),
                    highlightColor: Colors.white.withValues(alpha: 0.2),
                    child: Container(
                      width: 200,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.1),
                          highlightColor: Colors.white.withValues(alpha: 0.2),
                          child: Container(
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.email_rounded, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.1),
                          highlightColor: Colors.white.withValues(alpha: 0.2),
                          child: Container(
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.1),
                          highlightColor: Colors.white.withValues(alpha: 0.2),
                          child: Container(
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showOwnerDetails(Map<String, dynamic> propietario) {
    Map<String, dynamic> detalle = {};
    int ownerId = propietario['id'] ?? 0;

    if (ownerId > 0) {
      _loadOwnerDetail(ownerId, (data) {
        detalle = data;
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          _loadOwnerDetail(ownerId, (data) {
            detalle = data;
            setState(() {});
          });

          return DraggableScrollableSheet(
            initialChildSize: 0.90,
            maxChildSize: 1.0,
            minChildSize: 0.75,
            expand: false,
            snap: true,
            snapSizes: const [0.75, 0.90, 1.0],
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 🔹 DRAG HANDLE
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      /// 🔹 HEADER CON AVATAR
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_accentColor, _accentColor.withValues(alpha: 0.6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 2),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROPIETARIO',
                                  style: TextStyle(
                                    color: _accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  propietario['nombreCompleto'] ??
                                      '${propietario['nombre'] ?? ''} ${propietario['apellido'] ?? ''}'.trim(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      /// 🔹 INFORMACIÓN PERSONAL
                      _buildDetailSection(
                        icon: Icons.person_rounded,
                        title: 'Información Personal',
                        backgroundColor: const Color(0xFF2D2D4A),
                        fields: [
                          (label: 'Nombre', value: propietario['nombre']?.toString() ?? 'N/A'),
                          (label: 'Apellido', value: propietario['apellido']?.toString() ?? 'N/A'),
                          (label: 'Documento', value: propietario['numeroDocumento']?.toString() ?? 'N/A'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// 🔹 CONTACTO
                      _buildDetailSection(
                        icon: Icons.contact_mail_rounded,
                        title: 'Información de Contacto',
                        backgroundColor: const Color(0xFF2D2D4A),
                        fields: [
                          (label: 'Teléfono', value: propietario['telefono']?.toString() ?? 'N/A'),
                          (label: 'Correo', value: propietario['correo']?.toString() ?? 'N/A'),
                        ],
                      ),

                      if (detalle.isNotEmpty) ...
                        [
                          const SizedBox(height: 16),
                          /// 🔹 ESTADO
                          _buildDetailSection(
                            icon: Icons.check_circle_rounded,
                            title: 'Estado',
                            backgroundColor: const Color(0xFF2D2D4A),
                            fields: [
                              (label: 'Estado', value: detalle['estado']?.toString() ?? 'N/A'),
                            ],
                          ),
                        ],

                      const SizedBox(height: 24),

                      /// 🔹 BOTONES DE ACCIÓN
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Cerrar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required List<({String label, String value})> fields,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...fields.asMap().entries.map((entry) {
            bool isLast = entry.key == fields.length - 1;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          entry.value.label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(Map<String, dynamic> propietario) {
    final String nombre = propietario['nombre']?.toString() ?? '';
    final String apellido = propietario['apellido']?.toString() ?? '';
    final String nombreCompleto = propietario['nombreCompleto']?.toString() ?? '$nombre $apellido'.trim();
    final String telefono = propietario['telefono']?.toString() ?? '';
    final String correo = propietario['correo']?.toString() ?? '';
    final String numeroDocumento = propietario['numeroDocumento']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _showOwnerDetails(propietario),
      child: Container(
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
                    nombreCompleto,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.badge_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Documento: $numeroDocumento',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (correo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.email_rounded, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      correo,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (telefono.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone_rounded, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    telefono,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    if (_error != null) {
      return _buildErrorState(_error!);
    }

    if (_propietarios.isEmpty) {
      return _buildEmptyState(
        'Propietarios aliados',
        'No se encontraron propietarios registrados en el sistema.',
      );
    }

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
          ..._propietarios.map(_buildOwnerCard),
        ],
      ),
    );
  }
}
