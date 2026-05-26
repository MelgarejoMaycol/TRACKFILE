import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:trackfile/l10n/app_language.dart';
import 'package:trackfile/services/frontend_cache.dart';
import 'package:trackfile/utils/api_config.dart';

enum TipoGestionPersona { conductor, propietario }

class GestionPersonasWidget extends StatefulWidget {
  final TipoGestionPersona tipoInicial;
  final bool permitirCambiarTipo;
  final String nombreEmpresa;
  final String? initialSearch;
  final void Function({
    required int usuarioId,
    required String tipoPersona,
    required String nombrePersona,
  })?
  onVerDocumentosPersona;

  final void Function({
    required int usuarioId,
    required String tipoPersona,
    required String nombrePersona,
  })?
  onVerMantenimientosPersona;

  final void Function({
    required int usuarioId,
    required String tipoPersona,
    required String nombrePersona,
  })?
  onVerVehiculosPersona;

  final void Function({
    required int usuarioId,
    required String tipoPersona,
    required String nombrePersona,
  })?
  onVerCertificadosPersona;

  const GestionPersonasWidget({
    super.key,
    this.tipoInicial = TipoGestionPersona.conductor,
    this.permitirCambiarTipo = true,
    this.nombreEmpresa = '',
    this.onVerDocumentosPersona,
    this.onVerMantenimientosPersona,
    this.onVerVehiculosPersona,
    this.onVerCertificadosPersona,
    this.initialSearch,
  });

  @override
  State<GestionPersonasWidget> createState() => _GestionPersonasWidgetState();
}

class _GestionPersonasWidgetState extends State<GestionPersonasWidget> {
  static const Color _primaryColor = Color(0xFF3330BE); // principal
  static const Color _accentColor = Color(0xFF4F4CE8); // botones / detalles
  static const Color _bgColor = Color(0xFF131760); // fondo oscuro
  static const Color _cardColor = Color.fromARGB(255, 42, 42, 104);
  static const Color _panelColor = Color.fromARGB(255, 45, 45, 99);

  double _paddingResponsive(double width) {
    if (width < 360) return 12;
    if (width < 600) return 16;
    return 24;
  }

  late TipoGestionPersona _tipoActual;

  List<Map<String, dynamic>> _personas = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  String _baseUrl = ApiConfig.fallbackBaseUrl();
  final http.Client _client = http.Client();
  String? _tokenCache;
  Timer? _searchDebounce;

  String _iniciales(Map<String, dynamic> item) {
    final nombre = _value(item, ['nombre']).trim();
    final apellido = _value(item, ['apellido']).trim();

    if (nombre.isNotEmpty && apellido.isNotEmpty) {
      return '${nombre[0]}${apellido[0]}'.toUpperCase();
    }

    final completo = _nombreCompleto(item).trim();
    final partes = completo.split(' ').where((p) => p.isNotEmpty).toList();

    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }

    if (partes.isNotEmpty) {
      return partes[0][0].toUpperCase();
    }

    return '?';
  }

  @override
  void initState() {
    super.initState();
    _tipoActual = widget.tipoInicial;
    _search = widget.initialSearch?.trim() ?? '';
    FrontendCache.revision.addListener(_reloadFromCacheUpdate);
    _init();
  }

  void _reloadFromCacheUpdate() {
    if (!mounted) return;
    _loadPersonas();
  }

  @override
  void didUpdateWidget(covariant GestionPersonasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSearch != oldWidget.initialSearch) {
      setState(() {
        _search = widget.initialSearch?.trim() ?? '';
      });
    }
  }

  Future<void> _init() async {
    final resolved = await ApiConfig.loadBaseUrl();
    if (!mounted) return;
    _baseUrl = resolved;
    await _loadPersonas();
  }

  bool get _esConductor => _tipoActual == TipoGestionPersona.conductor;

  String get _titulo =>
      _esConductor ? context.t('users.drivers') : context.t('users.owners');

  String get _endpointBase =>
      _esConductor ? '/api/conductores' : '/api/propietarios';

  IconData get _iconoPrincipal =>
      _esConductor ? Icons.badge_rounded : Icons.person_rounded;

  Future<String> _token() async {
    if (_tokenCache != null && _tokenCache!.isNotEmpty) {
      return _tokenCache!;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa');
    }

    _tokenCache = token;
    return token;
  }

  Future<void> _loadPersonas() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await _token();

      final usuariosUri = ApiConfig.resolve(_baseUrl, '/api/usuarios');
      final personasUri = ApiConfig.resolve(_baseUrl, _endpointBase);

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        FrontendCache.httpGet(
          key: 'personas-widget:$usuariosUri:${token.hashCode}',
          request: () => _client.get(usuariosUri, headers: headers),
        ),
        FrontendCache.httpGet(
          key: 'personas-widget:$personasUri:${token.hashCode}',
          request: () => _client.get(personasUri, headers: headers),
        ),
      ]);

      final usuariosResponse = responses[0];
      final personasResponse = responses[1];

      if (usuariosResponse.statusCode != 200) {
        throw Exception(
          'Error usuarios ${usuariosResponse.statusCode}: ${usuariosResponse.body}',
        );
      }

      final List<Map<String, dynamic>> usuarios =
          (json.decode(usuariosResponse.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      final List<Map<String, dynamic>> registrosRol =
          personasResponse.statusCode == 200
          ? (json.decode(personasResponse.body) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : [];

      final rolBuscado = _esConductor ? 'CONDUCTOR' : 'PROPIETARIO';

      final Map<String, Map<String, dynamic>> personasPorUsuario = {};

      for (final user in usuarios) {
        final rol = _value(user, ['rol']).toUpperCase();

        if (!rol.contains(rolBuscado)) continue;

        final usuarioId = _value(user, ['id', 'idUsuario', 'id_usuario']);
        if (usuarioId.isEmpty) continue;

        personasPorUsuario[usuarioId] = {
          ...user,
          'usuarioId': usuarioId,
          'idUsuario': usuarioId,
          'nombreCompleto':
              '${_value(user, ['nombre'])} ${_value(user, ['apellido'])}'
                  .trim(),
        };
      }

      for (final persona in registrosRol) {
        final usuarioId = _obtenerUsuarioId(persona)?.toString() ?? '';
        if (usuarioId.isEmpty) continue;

        personasPorUsuario[usuarioId] = {
          ...?personasPorUsuario[usuarioId],
          ...persona,
          'usuarioId': usuarioId,
          'idUsuario': usuarioId,
        };
      }

      if (!mounted) return;

      setState(() {
        _personas = personasPorUsuario.values.toList()
          ..sort((a, b) => _nombreCompleto(a).compareTo(_nombreCompleto(b)));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadDetalle(int id) async {
    try {
      final token = await _token();
      final uri = ApiConfig.resolve(_baseUrl, '$_endpointBase/$id/detalle');

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = await FrontendCache.httpGet(
            key: 'personas-widget:$uri:${token.hashCode}',
            request: () => _client.get(uri, headers: headers),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body) as Map);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _crearPersona(Map<String, dynamic> body) async {
    FrontendCache.invalidateAll();
    final token = await _token();
    final uri = ApiConfig.resolve(_baseUrl, _endpointBase);

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    await _loadPersonas();
  }

  Future<void> _editarPersona(int id, Map<String, dynamic> body) async {
    FrontendCache.invalidateAll();
    final token = await _token();
    final uri = ApiConfig.resolve(_baseUrl, '$_endpointBase/$id');

    final response = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    await _loadPersonas();
  }

  Future<int> _crearUsuario(Map<String, dynamic> body) async {
    FrontendCache.invalidateAll();
    final token = await _token();
    final uri = ApiConfig.resolve(_baseUrl, '/api/usuarios');

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    // 🔥 SOLO lanza error si falla
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error creando usuario ${response.statusCode}: '
        '${response.body.isEmpty ? 'Sin detalle del servidor.' : response.body}',
      );
    }

    // ✅ Si funciona, obtiene el ID
    final data = json.decode(response.body) as Map<String, dynamic>;
    return int.parse(data['id'].toString());
  }

  List<Map<String, dynamic>> get _filtrados {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) return _personas;

    return _personas.where((item) {
      final nombre = _nombreCompleto(item).toLowerCase();
      final documento = _value(item, [
        'numeroDocumento',
        'documentoPropietario',
      ]).toLowerCase();
      final correo = _value(item, ['correo']).toLowerCase();
      final licencia = _value(item, ['licenciaConduccion']).toLowerCase();

      return nombre.contains(query) ||
          documento.contains(query) ||
          correo.contains(query) ||
          licencia.contains(query);
    }).toList();
  }

  String _value(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  String _nombreCompleto(Map<String, dynamic> item) {
    final completo = _value(item, ['nombreCompleto']);
    if (completo.isNotEmpty) return completo;

    final nombre = _value(item, ['nombre']);
    final apellido = _value(item, ['apellido']);

    final full = '$nombre $apellido'.trim();
    return full.isEmpty ? 'Sin nombre' : full;
  }

  int? _obtenerUsuarioId(Map<String, dynamic> item) {
    final raw =
        item['usuarioId'] ??
        item['idUsuario'] ??
        item['id_usuario'] ??
        (item['usuario'] is Map ? (item['usuario'] as Map)['id'] : null) ??
        item['id'];

    return int.tryParse(raw?.toString() ?? '');
  }

  void _verDocumentosPersona(Map<String, dynamic> item) {
    final usuarioId = _obtenerUsuarioId(item);
    if (usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.userNotFound'))),
      );
      return;
    }

    if (widget.onVerDocumentosPersona != null) {
      widget.onVerDocumentosPersona!.call(
        usuarioId: usuarioId,
        tipoPersona: _esConductor ? 'CONDUCTOR' : 'PROPIETARIO',
        nombrePersona: _nombreCompleto(item),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.configureDocumentsNav'))),
      );
    }
  }

  void _verMantenimientosPersona(Map<String, dynamic> item) {
    final usuarioId = _obtenerUsuarioId(item);

    if (usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.userNotFound'))),
      );
      return;
    }

    if (widget.onVerMantenimientosPersona != null) {
      widget.onVerMantenimientosPersona!.call(
        usuarioId: usuarioId,
        tipoPersona: _esConductor ? 'CONDUCTOR' : 'PROPIETARIO',
        nombrePersona: _nombreCompleto(item),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.configureMaintenanceNav'))),
      );
    }
  }

  void _verVehiculosPersona(Map<String, dynamic> item) {
    final usuarioId = _obtenerUsuarioId(item);

    if (usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.userNotFound'))),
      );
      return;
    }

    if (widget.onVerVehiculosPersona != null) {
      widget.onVerVehiculosPersona!.call(
        usuarioId: usuarioId,
        tipoPersona: _esConductor ? 'CONDUCTOR' : 'PROPIETARIO',
        nombrePersona: _nombreCompleto(item),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.configureVehiclesNav'))),
      );
    }
  }

  void _verCertificadosPersona(Map<String, dynamic> item) {
    final usuarioId = _obtenerUsuarioId(item);

    if (usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.userNotFound'))),
      );
      return;
    }

    if (widget.onVerCertificadosPersona != null) {
      widget.onVerCertificadosPersona!.call(
        usuarioId: usuarioId,
        tipoPersona: _esConductor ? 'CONDUCTOR' : 'PROPIETARIO',
        nombrePersona: _nombreCompleto(item),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('users.configureCertificatesNav'))),
      );
    }
  }

  String _limpiarTextoCorreo(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _dominioEmpresa() {
    final empresaLimpia = _limpiarTextoCorreo(widget.nombreEmpresa);

    if (empresaLimpia.isEmpty) {
      return 'empresa.com';
    }

    return '$empresaLimpia.com';
  }

  String _crearCorreoEmpresa(String alias) {
    final aliasLimpio = _limpiarTextoCorreo(alias);
    return '$aliasLimpio@${_dominioEmpresa()}';
  }

  BoxDecoration _modalGradientDecoration(double radius) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF20276D), Color(0xFF121842), Color(0xFF0D1234)],
      ),
      border: Border.all(color: Colors.white24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 28,
          offset: Offset(0, 18),
        ),
      ],
    );
  }

  void _showDetalle(Map<String, dynamic> persona) {
    final id = persona['id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: id is int ? _loadDetalle(id) : Future.value(null),
          builder: (context, snapshot) {
            final detalle = snapshot.data ?? {};
            final data = {...persona, ...detalle};

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              maxChildSize: 1,
              minChildSize: 0.65,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                  decoration: _modalGradientDecoration(28),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        Row(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _accentColor,
                                    _accentColor.withValues(alpha: 0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _iniciales(data),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _esConductor ? 'CONDUCTOR' : 'PROPIETARIO',
                                    style: const TextStyle(
                                      color: _accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _nombreCompleto(data),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        _detailSection(
                          icon: Icons.person_rounded,
                          title: context.t('profile.personalInfo'),
                          fields: [
                            (context.t('profile.name'), _value(data, ['nombre'])),
                            (context.t('profile.lastName'), _value(data, ['apellido'])),
                            (
                              context.t('vehicles.document'),
                              _value(data, [
                                'numeroDocumento',
                                'documentoPropietario',
                              ]),
                            ),
                            (
                              context.t('vehicles.status'),
                              _value(data, ['estado', 'estadoUsuario']),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        _detailSection(
                          icon: Icons.contact_mail_rounded,
                            title: context.t('users.contact'),
                          fields: [
                            (context.t('profile.email'), _value(data, ['correo'])),
                            (context.t('profile.phone'), _value(data, ['telefono'])),
                          ],
                        ),

                        if (_esConductor) ...[
                          const SizedBox(height: 14),
                          _detailSection(
                            icon: Icons.drive_eta_rounded,
                            title: context.t('users.drivingInfo'),
                            fields: [
                              (
                                context.t('vehicles.license'),
                                _value(data, ['licenciaConduccion']),
                              ),
                              (
                                context.t('vehicles.category'),
                                _value(data, ['categoriaLicencia']),
                              ),
                              (
                                context.t('documents.expires'),
                                _value(data, ['fechaVencimientoLicencia']),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showFormModal(persona: data);
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: Text(context.t('users.editInfo')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
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
          },
        );
      },
    );
  }

  Future<void> _abrirEditarConDetalle(Map<String, dynamic> persona) async {
    final id = persona['id'];

    Map<String, dynamic> data = Map<String, dynamic>.from(persona);

    if (id is int) {
      final detalle = await _loadDetalle(id);
      if (detalle != null) {
        data = {...data, ...detalle};
      }
    }

    if (!mounted) return;
    _showFormModal(persona: data);
  }

  void _showFormModal({Map<String, dynamic>? persona}) {
    final bool editando = persona != null;

    final nombreController = TextEditingController(
      text: editando ? _value(persona, ['nombre']) : '',
    );
    final apellidoController = TextEditingController(
      text: editando ? _value(persona, ['apellido']) : '',
    );
    final tipoDocumentoController = TextEditingController(
      text: editando
          ? _value(persona, ['tipoDocumento', 'tipo_documento'])
          : 'CC',
    );
    final numeroDocumentoController = TextEditingController(
      text: editando
          ? _value(persona, ['numeroDocumento', 'numero_documento'])
          : '',
    );
    final correoAliasController = TextEditingController();
    final telefonoController = TextEditingController(
      text: editando ? _value(persona, ['telefono']) : '',
    );
    final direccionController = TextEditingController(
      text: editando ? _value(persona, ['direccion']) : '',
    );
    final ciudadController = TextEditingController();
    final departamentoController = TextEditingController();
    final barrioController = TextEditingController();
    final contrasenaController = TextEditingController();

    final licenciaController = TextEditingController(
      text: editando
          ? _value(persona, ['licenciaConduccion', 'licencia_conduccion'])
          : '',
    );

    final categoriaController = TextEditingController(
      text: editando
          ? _value(persona, ['categoriaLicencia', 'categoria_licencia'])
          : '',
    );

    final vencimientoController = TextEditingController(
      text: editando
          ? _value(persona, [
              'fechaVencimientoLicencia',
              'fecha_vencimiento_licencia',
            ])
          : '',
    );
    final documentoPropietarioController = TextEditingController(
      text: editando
          ? _value(persona, ['documentoPropietario', 'numeroDocumento'])
          : '',
    );

    bool guardando = false;
    String? error;

    String tipoDocumentoSeleccionado = tipoDocumentoController.text.isNotEmpty
        ? tipoDocumentoController.text
        : 'CC';

    String categoriaLicenciaSeleccionada = categoriaController.text.isNotEmpty
        ? categoriaController.text
        : 'B1';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) {
        final width = MediaQuery.of(context).size.width;
        final height = MediaQuery.of(context).size.height;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: width < 600 ? 18 : 32,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width < 600 ? width * 0.94 : 460,
                maxHeight: height * 0.86,
              ),
              child: Container(
                decoration: _modalGradientDecoration(28),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: StatefulBuilder(
                    builder: (context, setModalState) {
                      Future<void> guardar() async {
                        try {
                          setModalState(() {
                            guardando = true;
                            error = null;
                          });

                          if (_esConductor) {
                            if (licenciaController.text.trim().isEmpty) {
                              throw Exception('La licencia es obligatoria');
                            }

                            if (vencimientoController.text.trim().isEmpty) {
                              throw Exception(
                                'Selecciona la fecha de vencimiento de la licencia.',
                              );
                            }
                          }

                          if (!_esConductor &&
                              documentoPropietarioController.text
                                  .trim()
                                  .isEmpty) {
                            throw Exception('El documento es obligatorio');
                          }

                          int? idUsuario;

                          if (!editando) {
                            if (nombreController.text.trim().isEmpty ||
                                apellidoController.text.trim().isEmpty ||
                                tipoDocumentoController.text.trim().isEmpty ||
                                numeroDocumentoController.text.trim().isEmpty ||
                                correoAliasController.text.trim().isEmpty ||
                                contrasenaController.text.trim().isEmpty) {
                              throw Exception(
                                'Completa los datos obligatorios del usuario.',
                              );
                            }

                            idUsuario = await _crearUsuario({
                              'nombre': nombreController.text.trim(),
                              'apellido': apellidoController.text.trim(),
                              'tipoDocumento': tipoDocumentoSeleccionado,
                              'numeroDocumento': numeroDocumentoController.text
                                  .trim(),
                              'correo': _crearCorreoEmpresa(
                                correoAliasController.text,
                              ),
                              'telefono': telefonoController.text.trim(),
                              'direccion':
                                  '${direccionController.text.trim()}, ${barrioController.text.trim()}, ${ciudadController.text.trim()}, ${departamentoController.text.trim()}',
                              'contrasena': contrasenaController.text.trim(),
                              'rol': _esConductor ? 'CONDUCTOR' : 'PROPIETARIO',
                              'emailConfirmado': true,
                            });
                          }

                          final Map<String, dynamic> body = _esConductor
                              ? {
                                  if (!editando) 'idUsuario': idUsuario,
                                  if (!editando)
                                    'nombre': nombreController.text.trim(),
                                  if (!editando)
                                    'apellido': apellidoController.text.trim(),
                                  if (!editando)
                                    'tipoDocumento': tipoDocumentoSeleccionado,
                                  if (!editando)
                                    'numeroDocumento': numeroDocumentoController
                                        .text
                                        .trim(),
                                  if (!editando)
                                    'telefono': telefonoController.text.trim(),
                                  if (!editando)
                                    'direccion': direccionController.text
                                        .trim(),
                                  'licenciaConduccion': licenciaController.text
                                      .trim(),
                                  'categoriaLicencia':
                                      categoriaLicenciaSeleccionada,
                                  'fechaVencimientoLicencia':
                                      vencimientoController.text.trim(),
                                }
                              : {
                                  if (!editando) 'idUsuario': idUsuario,
                                  if (!editando)
                                    'nombre': nombreController.text.trim(),
                                  if (!editando)
                                    'apellido': apellidoController.text.trim(),
                                  if (!editando)
                                    'tipoDocumento': tipoDocumentoSeleccionado,
                                  if (!editando)
                                    'numeroDocumento': numeroDocumentoController
                                        .text
                                        .trim(),
                                  if (!editando)
                                    'telefono': telefonoController.text.trim(),
                                  if (!editando)
                                    'direccion': direccionController.text
                                        .trim(),
                                  'documentoPropietario':
                                      documentoPropietarioController.text
                                          .trim(),
                                };

                          if (editando) {
                            final int id = int.parse(persona['id'].toString());

                            body['idUsuario'] = _obtenerUsuarioId(
                              persona,
                            )?.toString();

                            await _editarPersona(id, body);
                          } else {
                            await _crearPersona(body);
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                editando
                                    ? '✅ Información actualizada correctamente'
                                    : '✅ Registro creado correctamente',
                              ),
                            ),
                          );
                        } catch (e) {
                          setModalState(() {
                            error = e.toString();
                            guardando = false;
                          });
                        }
                      }

                      return Padding(
                        padding: EdgeInsets.only(
                          left: 18,
                          right: 18,
                          top: 18,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      editando
                                          ? 'Editar $_titulo'
                                          : 'Crear ${_esConductor ? 'conductor' : 'propietario'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: width < 380 ? 17 : 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              _formInput(
                                controller: nombreController,
                                label: 'Nombre',
                                icon: Icons.person_rounded,
                                enabled: !editando,
                              ),
                              _formInput(
                                controller: apellidoController,
                                label: 'Apellido',
                                icon: Icons.person_outline_rounded,
                                enabled: !editando,
                              ),
                              _formSelect(
                                label: 'Tipo documento',
                                icon: Icons.badge_rounded,
                                value: tipoDocumentoSeleccionado,
                                items: const [
                                  'CC',
                                  'CE',
                                  'TI',
                                  'Pasaporte',
                                  'NIT',
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    tipoDocumentoSeleccionado = value!;
                                    tipoDocumentoController.text = value;
                                  });
                                },
                              ),
                              _formInput(
                                controller: numeroDocumentoController,
                                label: 'Número documento',
                                icon: Icons.confirmation_number_rounded,
                                enabled: !editando,
                              ),
                              _formInput(
                                controller: telefonoController,
                                label: 'Teléfono',
                                hint: 'Ej: 3001234567',
                                icon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                                enabled: !editando,
                              ),
                              _formInput(
                                controller: direccionController,
                                label: 'Dirección',
                                icon: Icons.location_on_rounded,
                                enabled: !editando,
                              ),

                              if (!editando) ...[
                                _formEmailEmpresaInput(
                                  controller: correoAliasController,
                                  label: 'Correo',
                                  icon: Icons.alternate_email_rounded,
                                ),
                                _formInput(
                                  controller: contrasenaController,
                                  label: 'Contraseña',
                                  icon: Icons.lock_rounded,
                                ),
                              ],

                              if (_esConductor) ...[
                                _formInput(
                                  controller: licenciaController,
                                  label: 'Licencia de conducción',
                                  icon: Icons.badge_rounded,
                                ),
                                _formSelect(
                                  label: 'Categoría licencia',
                                  icon: Icons.credit_card_rounded,
                                  value: categoriaLicenciaSeleccionada,
                                  items: const [
                                    'A1',
                                    'A2',
                                    'B1',
                                    'B2',
                                    'B3',
                                    'C1',
                                    'C2',
                                    'C3',
                                  ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      categoriaLicenciaSeleccionada = value!;
                                      categoriaController.text = value;
                                    });
                                  },
                                ),
                                _formDateInput(
                                  controller: vencimientoController,
                                  label: 'Fecha vencimiento licencia',
                                  icon: Icons.calendar_month_rounded,
                                ),
                              ] else ...[
                                _formInput(
                                  controller: documentoPropietarioController,
                                  label: 'Documento propietario',
                                  icon: Icons.badge_rounded,
                                ),
                              ],

                              if (error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Color(0xFFE66B6B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: guardando ? null : guardar,
                                  icon: guardando
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_rounded),
                                  label: Text(
                                    guardando ? 'Guardando...' : 'Guardar',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _formInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        enabled: enabled,
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: enabled ? Colors.white : Colors.white54),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: enabled ? Colors.white70 : Colors.white38,
          ),
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(
            icon,
            color: enabled ? Colors.white54 : Colors.white30,
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          filled: true,
          fillColor: enabled
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.025),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _formEmailEmpresaInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    final dominio = '@${_dominioEmpresa()}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white),
        onChanged: (value) {
          final limpio = _limpiarTextoCorreo(value);

          if (value != limpio) {
            controller.value = TextEditingValue(
              text: limpio,
              selection: TextSelection.collapsed(offset: limpio.length),
            );
          }
        },
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          labelText: label,
          hintText: 'juanperez',
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white54, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          suffixText: dominio,
          suffixStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _formSelect({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: _cardColor,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white54, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryColor),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _formDateInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          labelText: label,
          hintText: 'Seleccionar fecha',
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white54, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          suffixIcon: const Icon(
            Icons.expand_more_rounded,
            color: Colors.white54,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryColor),
          ),
        ),
        onTap: () async {
          final now = DateTime.now();

          final picked = await showDatePicker(
            context: context,
            initialDate: now.add(const Duration(days: 365)),
            firstDate: now,
            lastDate: DateTime(now.year + 20),
          );

          if (picked != null) {
            controller.text =
                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          }
        },
      ),
    );
  }

  Widget _detailSection({
    required IconData icon,
    required String title,
    required List<(String, String)> fields,
  }) {
    final visibles = fields
        .where((field) => field.$2.trim().isNotEmpty)
        .toList();

    if (visibles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...visibles.map((field) {
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      field.$1,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      field.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final small = width < 380;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 18,
            vertical: small ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: small ? 36 : 42,
                height: small ? 36 : 42,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconoPrincipal,
                  color: Colors.white,
                  size: small ? 20 : 24,
                ),
              ),
              SizedBox(width: small ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: small ? 16 : 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _esConductor
                          ? context.t('users.driverControl')
                          : context.t('users.ownerControl'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white60,
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
                    horizontal: small ? 9 : 14,
                    vertical: small ? 7 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${_personas.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: small ? 11 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 380;

        if (small) {
          return Column(
            children: [
              _searchBox(),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => _showFormModal(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.t('common.create')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _searchBox()),
            const SizedBox(width: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showFormModal(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.t('common.create')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _searchBox() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        onChanged: (value) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            setState(() => _search = value);
          });
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _esConductor
              ? context.t('users.searchDriver')
              : context.t('users.searchOwner'),
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final nombre = _nombreCompleto(item);
    final documento = _value(item, ['numeroDocumento', 'documentoPropietario']);
    final correo = _value(item, ['correo']);
    final telefono = _value(item, ['telefono']);
    final licencia = _value(item, ['licenciaConduccion']);
    final estado = _value(item, ['estado', 'estadoUsuario']);
    final activo = estado.toUpperCase() != 'INACTIVO';

    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 330;

        return Container(
          padding: EdgeInsets.all(small ? 12 : 16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: small ? 20 : 24,
                    backgroundColor: _accentColor.withValues(alpha: 0.25),
                    child: Text(
                      _iniciales(item),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: small ? 12 : 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: small ? 7 : 9,
                      vertical: small ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: activo
                          ? const Color(0xFF16C79A).withValues(alpha: 0.16)
                          : const Color(0xFFE66B6B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      activo ? context.t('common.active') : context.t('common.inactive'),
                      style: TextStyle(
                        color: activo
                            ? const Color(0xFF16C79A)
                            : const Color(0xFFE66B6B),
                        fontSize: small ? 9 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white54,
                      size: small ? 18 : 20,
                    ),
                    color: _panelColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    itemBuilder: (context) => [
                      _menuItem(1, Icons.visibility_rounded, context.t('users.viewInfo')),
                      _menuItem(2, Icons.edit_rounded, context.t('users.editInfo')),
                      _menuItem(3, Icons.folder_copy_rounded, context.t('vehicles.viewDocuments')),
                      _menuItem(4, Icons.build_rounded, context.t('vehicles.viewMaintenance')),
                      _menuItem(
                        5,
                        Icons.directions_car_rounded,
                        context.t('users.viewVehicles'),
                      ),
                      _menuItem(6, Icons.verified_rounded, context.t('users.viewCertificates')),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 1:
                          _showDetalle(item);
                          break;
                        case 2:
                          _abrirEditarConDetalle(item);
                          break;
                        case 3:
                          _verDocumentosPersona(item);
                          break;
                        case 4:
                          _verMantenimientosPersona(item);
                          break;
                        case 5:
                          _verVehiculosPersona(item);
                          break;
                        case 6:
                          _verCertificadosPersona(item);
                          break;
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: small ? 10 : 12),
              Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: small ? 14 : 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (documento.isNotEmpty)
                _compactInfo(Icons.badge_rounded, documento),
              if (_esConductor && licencia.isNotEmpty)
                _compactInfo(Icons.credit_card_rounded, licencia),
              if (correo.isNotEmpty) _compactInfo(Icons.email_rounded, correo),
              if (telefono.isNotEmpty)
                _compactInfo(Icons.phone_rounded, telefono),
            ],
          ),
        );
      },
    );
  }

  PopupMenuItem<int> _menuItem(int value, IconData icon, String text) {
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _compactInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: EdgeInsets.all(
        _paddingResponsive(MediaQuery.of(context).size.width),
      ),
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        ...List.generate(4, (_) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.white.withValues(alpha: 0.08),
              highlightColor: Colors.white.withValues(alpha: 0.20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        Container(height: 14, color: Colors.white),
                        const SizedBox(height: 9),
                        Container(height: 12, color: Colors.white),
                        const SizedBox(height: 9),
                        Container(height: 12, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      padding: EdgeInsets.all(
        _paddingResponsive(MediaQuery.of(context).size.width),
      ),
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE66B6B),
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(
                context.t('users.loadError'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  FrontendCache.invalidateAll();
                  _loadPersonas();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.t('common.retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(_iconoPrincipal, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(
            _esConductor ? context.t('users.emptyDrivers') : context.t('users.emptyOwners'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _esConductor
                ? context.t('users.emptyDriversHelp')
                : context.t('users.emptyOwnersHelp'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    FrontendCache.revision.removeListener(_reloadFromCacheUpdate);
    _searchDebounce?.cancel();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    if (_error != null) return _buildError();

    final items = _filtrados;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(26),
        topRight: Radius.circular(26),
      ),
      child: Container(
        color: _bgColor,
        child: RefreshIndicator(
          onRefresh: () async {
            FrontendCache.invalidateAll();
            await _loadPersonas();
          },
          color: _accentColor,
          child: ListView(
            padding: EdgeInsets.all(
              _paddingResponsive(MediaQuery.of(context).size.width),
            ),
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildSearchAndActions(),
              const SizedBox(height: 18),

              if (items.isEmpty)
                _buildEmpty()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    final crossAxisCount = width > 1100
                        ? 3
                        : width > 720
                        ? 2
                        : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: width < 360 ? 205 : 190,
                      ),
                      itemBuilder: (context, index) {
                        return _buildCard(items[index]);
                      },
                    );
                  },
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
