import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:frontendproyecto/utils/api_config.dart';
import 'package:frontendproyecto/utils/role_router.dart';

class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // Controllers for Únete form
  final _nameCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _repCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loginLoading = false;
  bool _signUpLoading = false;
  late final TabController _tabController;
  bool _isUneteValid = false;
  bool _isLoginValid = false;
  // Password visibility toggles
  bool _signupPassObscure = true;
  bool _confirmPassObscure = true;
  bool _loginPassObscure = true;
  PlatformFile? _rutPdfFile;
  String _baseUrl = ApiConfig.fallbackBaseUrl();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initBaseUrl();
    // Listen to inputs to update button states
    _nameCtrl.addListener(_validateForms);
    _nitCtrl.addListener(_validateForms);
    _repCtrl.addListener(_validateForms);
    _emailCtrl.addListener(_validateForms);
    _signupPassCtrl.addListener(_validateForms);
    _confirmPassCtrl.addListener(_validateForms);
    _userCtrl.addListener(_validateForms);
    _passCtrl.addListener(_validateForms);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _nitCtrl.dispose();
    _repCtrl.dispose();
    _emailCtrl.dispose();
    _signupPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _validateForms() {
    final nameOk = _nameCtrl.text.trim().isNotEmpty;
    final nitOk =
        _nitCtrl.text.trim().isNotEmpty &&
        RegExp(r'^\d+$').hasMatch(_nitCtrl.text.trim());
    final repOk = _repCtrl.text.trim().isNotEmpty;
    final emailOk = _isValidEmail(_emailCtrl.text.trim());
    final passOk = _isValidSignupPassword(_signupPassCtrl.text.trim());
    final confirmOk =
        _signupPassCtrl.text.trim().isNotEmpty &&
        _signupPassCtrl.text.trim() == _confirmPassCtrl.text.trim();
    final pdfOk = _rutPdfFile != null;
    final newUnete =
        nameOk && nitOk && repOk && emailOk && passOk && confirmOk && pdfOk;
    final newLogin =
        _userCtrl.text.trim().isNotEmpty && _passCtrl.text.trim().isNotEmpty;
    if (newUnete != _isUneteValid || newLogin != _isLoginValid) {
      setState(() {
        _isUneteValid = newUnete;
        _isLoginValid = newLogin;
      });
    }
  }

  Future<void> _initBaseUrl() async {
    final resolved = await ApiConfig.loadBaseUrl();
    if (!mounted) return;
    setState(() => _baseUrl = resolved);
  }

  Uri _endpoint(String path) => ApiConfig.resolve(_baseUrl, path);

  Future<void> _promptBaseUrlChange() async {
    if (_loginLoading || _signUpLoading) return;
    final controller = TextEditingController(text: _baseUrl);
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (innerCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Configura el servidor'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'URL base',
                      hintText: 'http://192.168.0.5:8080',
                      errorText: errorText,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usa la IP del equipo que ejecuta el backend. Ejemplo: http://192.168.1.10:8080',
                    style: Theme.of(innerCtx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(innerCtx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    final normalized = ApiConfig.normalize(controller.text);
                    if (normalized == null) {
                      setDialogState(
                        () => errorText =
                            'Ingresa una URL válida (http:// o https://)',
                      );
                      return;
                    }
                    Navigator.of(dialogCtx).pop(normalized);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    final String? normalizedResult = result == null
        ? null
        : ApiConfig.normalize(result);
    if (normalizedResult == null || normalizedResult == _baseUrl) {
      return;
    }

    try {
      await ApiConfig.saveBaseUrl(normalizedResult);
      if (!mounted) return;
      setState(() => _baseUrl = normalizedResult);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Servidor actualizado')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la URL ingresada')),
        );
      }
    }
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r"^[\w\-\.]+@[\w\-]+\.[a-zA-Z]{2,}");
    return emailRegex.hasMatch(email);
  }

  bool _isValidSignupPassword(String pass) {
    if (pass.isEmpty) return false;
    // At least one uppercase, at least one digit, and only letters and digits (no special chars)
    final hasUpper = pass.contains(RegExp(r'[A-Z]'));
    final hasDigit = pass.contains(RegExp(r'\d'));
    final onlyLettersDigits = RegExp(r'^[A-Za-z\d]+$').hasMatch(pass);
    return hasUpper && hasDigit && onlyLettersDigits;
  }

  Future<void> _doSignUp() async {
    if (!_isUneteValid || _signUpLoading) return;
    final file = _rutPdfFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes adjuntar el RUT en formato PDF.')),
      );
      return;
    }

    setState(() => _signUpLoading = true);
    try {
      final uri = _endpoint('/api/auth/registro-empresa');
      final request = http.MultipartRequest('POST', uri)
        ..fields.addAll({
          'nombreEmpresa': _nameCtrl.text.trim(),
          'nit': _nitCtrl.text.trim(),
          'correo': _emailCtrl.text.trim(),
          'representanteLegal': _repCtrl.text.trim(),
          'cedulaRepresentante': _repCtrl.text.trim(),
          'contrasena': _signupPassCtrl.text.trim(),
        });

      http.MultipartFile? multipartFile;
      if (file.bytes != null) {
        multipartFile = http.MultipartFile.fromBytes(
          'rutPdf',
          file.bytes!,
          filename: file.name,
          contentType: MediaType('application', 'pdf'),
        );
      } else if (file.path != null) {
        multipartFile = await http.MultipartFile.fromPath(
          'rutPdf',
          file.path!,
          filename: file.name,
          contentType: MediaType('application', 'pdf'),
        );
      }

      if (multipartFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo leer el archivo seleccionado.'),
            ),
          );
        }
        return;
      }

      request.files.add(multipartFile);

      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _showValidationModal();
        if (!mounted) return;
        _resetSignUpForm();
      } else {
        final message = response.body.isNotEmpty
            ? response.body
            : 'No se pudo completar el registro.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar la empresa: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _signUpLoading = false);
    }
  }

  void _resetSignUpForm() {
    setState(() {
      _signupPassCtrl.clear();
      _confirmPassCtrl.clear();
      _emailCtrl.clear();
      _nitCtrl.clear();
      _repCtrl.clear();
      _nameCtrl.clear();
      _rutPdfFile = null;
      _isUneteValid = false;
    });
  }

  Future<void> _pickRutPdf() async {
    if (_signUpLoading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      setState(() {
        _rutPdfFile = result.files.single;
      });
      _validateForms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo adjuntar el PDF: $e')),
        );
      }
    }
  }

  void _clearRutPdf() {
    if (!mounted) return;
    setState(() {
      _rutPdfFile = null;
    });
    _validateForms();
  }

  Future<void> _showValidationModal() async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 48),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06135E), Color(0xFF162A89)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Revisa tu correo y confirma el enlace de verificación',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Después de verificar tu correo validaremos la empresa y te responderemos en máximo 48 horas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF06135E),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            'Aceptar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Circular avatar overlapping top
              Positioned(
                top: 0,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF0D2B7B),
                    child: const Icon(
                      Icons.notifications,
                      color: Color(0xFF16C79A),
                      size: 36,
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

  Future<void> _doLogin() async {
    if (!_isLoginValid || _loginLoading) return;
    setState(() => _loginLoading = true);
    try {
      final response = await http
          .post(
            _endpoint('/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'correo': _userCtrl.text.trim(),
              'contrasena': _passCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is! Map) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Respuesta del servidor inválida.')),
            );
            return;
          }

          final Map<String, dynamic> loginData = Map<String, dynamic>.from(
            decoded.cast<String, dynamic>(),
          );
          final bool emailConfirmado = loginData['emailConfirmado'] == true;
          final String email =
              loginData['correo']?.toString() ?? _userCtrl.text.trim();

          if (!emailConfirmado) {
            await _showVerificationPendingDialog(email);
            return;
          }

          final String role = (loginData['rol']?.toString() ?? '')
              .toUpperCase();
          final String? estadoVerificacion = loginData['estadoVerificacion']
              ?.toString();
          if (role == 'EMPRESA' && estadoVerificacion != null) {
            final Set<String> allowedStates = {'APROBADA', 'APROBADO'};
            if (!allowedStates.contains(estadoVerificacion.toUpperCase())) {
              await _showEmpresaEstadoDialog(estadoVerificacion);
              return;
            }
          }

          final int? usuarioId = _toInt(loginData['usuarioId']);
          if (usuarioId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El servidor no devolvió el identificador del usuario.',
                ),
              ),
            );
            return;
          }

          final Map<String, dynamic>? profile = await _fetchUserDetails(
            usuarioId,
          );
          if (!mounted) return;
          if (profile == null) {
            return;
          }

          profile['id'] ??= usuarioId;
          profile['usuarioId'] ??= usuarioId;
          profile['rol'] = (profile['rol']?.toString() ?? role).toUpperCase();
          profile['emailConfirmado'] ??= emailConfirmado;
          profile['empresaId'] ??= _toInt(loginData['empresaId']);

          if (estadoVerificacion != null) {
            final company = profile['empresa'];
            if (company is Map<String, dynamic>) {
              company['estadoVerificacion'] ??= estadoVerificacion;
            } else {
              profile['estadoVerificacion'] ??= estadoVerificacion;
            }
          }

          await persistSession(profile);
          if (!mounted) return;

          final target = screenForRole(profile);
          if (target == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rol no reconocido para este usuario.'),
              ),
            );
            return;
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => target),
            (route) => false,
          );
        } on FormatException {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Respuesta del servidor inválida.')),
          );
        }
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.body.isNotEmpty
                  ? response.body
                  : 'Credenciales incorrectas.',
            ),
          ),
        );
      } else {
        final message = response.body.isNotEmpty
            ? response.body
            : 'No se pudo iniciar sesión.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiempo de espera agotado. Verifica tu conexión.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al iniciar sesión: $e')));
      }
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserDetails(int userId) async {
    try {
      final response = await http
          .get(_endpoint('/api/usuarios/$userId'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded.cast<String, dynamic>());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Formato inesperado al consultar el perfil.'),
            ),
          );
        }
        return null;
      }

      final message = response.body.isNotEmpty
          ? response.body
          : 'No se pudo obtener el perfil del usuario.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiempo de espera agotado al consultar el perfil.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error consultando el perfil: $e')),
        );
      }
    }
    return null;
  }

  Future<void> _showVerificationPendingDialog(String email) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Verifica tu correo'),
          content: Text(
            'Hemos enviado un enlace de verificación a $email. '
            'Completa la verificación desde tu correo electrónico antes de iniciar sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEmpresaEstadoDialog(String estado) async {
    if (!mounted) return;
    final String upper = estado.toUpperCase();
    final String message;
    if (upper == 'PENDIENTE') {
      message =
          'Tu empresa aún está en revisión. Te avisaremos por correo cuando el proceso termine.';
    } else if (upper == 'RECHAZADA') {
      message =
          'Tu empresa fue rechazada. Comunícate con soporte para más información.';
    } else {
      message =
          'Tu empresa se encuentra en estado $estado. Comunícate con soporte para continuar.';
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cuenta en validación'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isCompactWidth = size.width <= 360;
    final double cardWidthFactor = isCompactWidth
        ? 0.92
        : (size.width <= 420 ? 0.86 : 0.80);
    final double cardWidth = size.width * cardWidthFactor;
    final double cardHeight = size.height * (size.height < 720 ? 0.82 : 0.75);

    final double logoDiameter = _responsiveClamp(
      value: size.width * 0.34,
      min: 110,
      max: 180,
    );
    final double logoRadius = logoDiameter / 2;
    const darkBlue = Color(0xFF06135E);
    return Scaffold(
      backgroundColor: const Color(0xFF0C1C58),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      width: cardWidth,
                      height: cardHeight,
                      margin: EdgeInsets.only(top: logoRadius * 1.2),
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide.none,
                        ),
                        child: SizedBox.expand(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 28,
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                // Simple TabBar without any visible selection indicator
                                TabBar(
                                  controller: _tabController,
                                  labelColor: darkBlue,
                                  unselectedLabelColor: darkBlue.withValues(
                                    alpha: 0.6,
                                  ),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                  // Ensure the TabBar does not draw any underline or indicator
                                  indicator: const UnderlineTabIndicator(
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 0,
                                    ),
                                  ),
                                  indicatorWeight: 0,
                                  indicatorPadding: EdgeInsets.zero,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  overlayColor: WidgetStatePropertyAll<Color>(
                                    Colors.transparent,
                                  ),
                                  tabs: const [
                                    Tab(text: 'ÚNETE'),
                                    Tab(text: 'INICIA SESIÓN'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Let the TabBarView expand to fill available space inside the card
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _wrapCenter(_buildUneteSection(darkBlue)),
                                      _wrapCenter(_buildLoginSection(darkBlue)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // logo outside the white card
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: CircleAvatar(
                          radius: logoRadius,
                          backgroundColor: Colors.transparent,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logoCirculo.png',
                              width: logoDiameter,
                              height: logoDiameter,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildRoleShortcutButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUneteSection(Color darkBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: _inputDecoration('Nombre de Empresa'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nitCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration('Nit').copyWith(
            errorText: _nitCtrl.text.isEmpty
                ? null
                : (RegExp(r'^\d+$').hasMatch(_nitCtrl.text)
                      ? null
                      : 'El NIT debe contener solo números'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _repCtrl,
          decoration: _inputDecoration('Representante legal C.C'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Correo Electrónico').copyWith(
            errorText: _emailCtrl.text.isEmpty
                ? null
                : (_isValidEmail(_emailCtrl.text.trim())
                      ? null
                      : 'Correo inválido'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _signupPassCtrl,
          obscureText: _signupPassObscure,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          ],
          decoration: _inputDecoration('Contraseña').copyWith(
            prefixIcon: IconButton(
              icon: Icon(
                _signupPassObscure ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _signupPassObscure = !_signupPassObscure),
            ),
            errorText: _signupPassCtrl.text.isEmpty
                ? null
                : (_isValidSignupPassword(_signupPassCtrl.text)
                      ? null
                      : 'Debe tener mayúscula, número y sin caracteres especiales'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _confirmPassObscure,
          decoration: _inputDecoration('Confirmar Contraseña').copyWith(
            prefixIcon: IconButton(
              icon: Icon(
                _confirmPassObscure ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _confirmPassObscure = !_confirmPassObscure),
            ),
            errorText: _confirmPassCtrl.text.isEmpty
                ? null
                : (_confirmPassCtrl.text == _signupPassCtrl.text
                      ? null
                      : 'Las contraseñas no coinciden'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_signUpLoading) ? null : _pickRutPdf,
                icon: Icon(Icons.picture_as_pdf, color: darkBlue),
                label: Text(
                  _rutPdfFile?.name ?? 'Adjuntar RUT (PDF)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_rutPdfFile != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: _signUpLoading ? null : _clearRutPdf,
                tooltip: 'Quitar archivo',
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Validaremos que el correo exista dentro del RUT adjunto.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isUneteValid && !_signUpLoading) ? _doSignUp : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 0),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: (_isUneteValid && !_signUpLoading)
                      ? const [Color(0xFF06135E), Color(0xFF16C79A)]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                ),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              // Reducimos la altura mínima para que el botón sea más angosto verticalmente
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 40),
                child: _signUpLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Únete',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginSection(Color darkBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const SizedBox(height: 12),
        TextField(
          controller: _userCtrl,
          decoration: _inputDecoration('Correo electrónico'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: _loginPassObscure,
          decoration: _inputDecoration('Contraseña').copyWith(
            prefixIcon: IconButton(
              icon: Icon(
                _loginPassObscure ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _loginPassObscure = !_loginPassObscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text('Olvidaste contraseña?'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _baseUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_ethernet_outlined, size: 20),
              tooltip: 'Cambiar servidor',
              onPressed: (_loginLoading || _signUpLoading)
                  ? null
                  : _promptBaseUrlChange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isLoginValid && !_loginLoading) ? _doLogin : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 0),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF06135E), Color(0xFF16C79A)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              // Reducimos la altura mínima para que el botón sea más angosto verticalmente
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 40),
                child: _loginLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Inicia Sesion',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Wrap a section so it centers vertically when there's extra space, and scrolls when content is large
  Widget _wrapCenter(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0),
                  child: child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _responsiveClamp({
    required double value,
    required double min,
    required double max,
  }) {
    return value.clamp(min, max).toDouble();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildRoleShortcutButtons() {
    const roleConfigs = [
      {'label': 'Conductor', 'role': 'CONDUCTOR', 'icon': Icons.directions_bus},
      {'label': 'Empresa', 'role': 'EMPRESA', 'icon': Icons.apartment},
      {'label': 'Propietario', 'role': 'PROPIETARIO', 'icon': Icons.person_pin},
      {
        'label': 'Secretaria',
        'role': 'SECRETARIA',
        'icon': Icons.support_agent,
      },
      {'label': 'Admin', 'role': 'ADMIN', 'icon': Icons.admin_panel_settings},
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(
            'Ingresar directo por rol',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: roleConfigs.map((config) {
              final String label = config['label']! as String;
              final String roleKey = config['role']! as String;
              final IconData icon = config['icon']! as IconData;

              return SizedBox(
                width: 150,
                child: ElevatedButton.icon(
                  icon: Icon(icon, size: 20),
                  label: Text(label),
                  onPressed: () => _openRoleShortcut(roleKey),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF06135E),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _openRoleShortcut(String roleKey) {
    final Map<String, dynamic> demoUser = {
      'rol': roleKey,
      'id': 'demo_$roleKey',
      'nombre': 'Usuario',
      'apellido': roleKey.toLowerCase(),
      'empresa': {
        'nombreEmpresa': 'Demo Logistics',
        'representanteLegal': 'Demo Admin',
        'nit': '900123456',
      },
    };

    final Widget? target = screenForRole(demoUser);
    if (target == null) return;

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
  }
}
