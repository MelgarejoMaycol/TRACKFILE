import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/services/api_link.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/services/notifications/notificaciones_realtime_service.dart';
import 'package:trackfile/utils/api_config.dart';
import 'package:trackfile/utils/role_router.dart';
import 'package:trackfile/widgets/android_download_prompt.dart';

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
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    // Usar directamente getApiLink() en lugar de cargar desde SharedPreferences
    _baseUrl = getApiLink();
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

  Uri _endpoint(String path) => ApiConfig.resolve(_baseUrl, path);

  // ignore: unused_element
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
      // Verificar en el front si el NIT ya existe para evitar error de clave única
      try {
        final nitValue = _nitCtrl.text.trim();
        if (nitValue.isNotEmpty) {
          final empresasResp = await http
              .get(_endpoint('/api/empresas'))
              .timeout(const Duration(seconds: 15));

          if (empresasResp.statusCode == 200 && empresasResp.body.isNotEmpty) {
            final decodedList = jsonDecode(empresasResp.body);
            if (decodedList is List) {
              final exists = decodedList.any((item) {
                try {
                  if (item is Map) {
                    final nit = item['nit']?.toString().trim();
                    return nit != null && nit == nitValue;
                  }
                } catch (_) {}
                return false;
              });

              if (exists) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El NIT ingresado ya está registrado. Si perteneces a esta empresa solicita acceso o usa otro NIT.',
                      ),
                    ),
                  );
                }
                return;
              }
            }
          }
        }
      } catch (_) {
        // Si falla la verificación previa, continuar con el registro y dejar
        // que el backend maneje posibles errores. No bloqueamos el flujo.
      }
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

  String _roleToRoute(dynamic role) {
    final normalized = _stringValue(role)?.toUpperCase() ?? '';

    switch (normalized) {
      case 'EMPRESA':
      case 'ROLE_EMPRESA':
        return 'empresa';

      case 'PROPIETARIO':
      case 'ROLE_PROPIETARIO':
        return 'propietario';

      case 'CONDUCTOR':
      case 'ROLE_CONDUCTOR':
        return 'conductor';

      case 'ADMIN':
      case 'ROLE_ADMIN':
        return 'admin';

      case 'SECRETARIA':
      case 'ROLE_SECRETARIA':
        return 'secretaria';

      default:
        return '';
    }
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

          final Map<String, dynamic> loginData = _safeJsonMap(decoded);
          final bool emailConfirmado = loginData['emailConfirmado'] == true;
          final String email =
              _stringValue(loginData['correo']) ?? _userCtrl.text.trim();
          final String? verificationLink = _resolveVerificationLink(
            loginData['verificationLink'],
          );

          if (!emailConfirmado) {
            await _showVerificationPendingDialog(
              email,
              verificationLink: verificationLink,
            );
            return;
          }

          final String role =
              _stringValue(loginData['rol'])?.toUpperCase() ?? '';

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

          final String? token = _stringValue(loginData['token']);
          final Map<String, dynamic>? profile = await _fetchUserDetails(
            usuarioId,
            token: token,
          );
          if (!mounted) return;
          if (profile == null) {
            return;
          }

          final Map<String, dynamic> sessionData = _composeSessionData(
            profile,
            loginData,
            usuarioId: usuarioId,
            fallbackRole: role,
            email: email,
            emailConfirmado: emailConfirmado,
          );

          NotificacionesRealtimeService.stop();
          ApiService.clearTokenCache();

          final prefs = await SharedPreferences.getInstance();

          await prefs.remove('auth_user');
          await prefs.remove('auth_token');
          await prefs.remove('token');
          await prefs.remove('rol');
          await prefs.remove('role');
          await prefs.remove('user_id');
          await prefs.remove('usuario_id');
          await prefs.remove('empresa_id');
          await prefs.remove('conductor_id');
          await prefs.remove('propietario_id');

          // Validación de estado de empresa removida - no es requerida por el backend
          await persistSession(sessionData);

          // Guardar también los datos que usa app_router.dart

          final String? tokenSesion = _stringValue(sessionData['token']);
          final String rolRuta = _roleToRoute(sessionData['rol']);

          if (tokenSesion == null || tokenSesion.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se recibió token de sesión.')),
            );
            return;
          }

          if (rolRuta.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rol no reconocido para este usuario.'),
              ),
            );
            return;
          }
          await prefs.setString('token', tokenSesion);
          await prefs.setString('auth_token', tokenSesion);
          ApiService.setTokenCache(tokenSesion);
          ApiService.startAutoRefreshToken();

          await prefs.setString('rol', rolRuta);
          await prefs.setString('role', rolRuta);

          await prefs.setString('user_id', usuarioId.toString());
          await prefs.setString('usuario_id', usuarioId.toString());

          final empresaId = sessionData['empresaId']?.toString();
          if (empresaId != null && empresaId.isNotEmpty) {
            await prefs.setString('empresa_id', empresaId);
          }

          if (!mounted) return;

          final shouldShowAndroidPrompt =
              AndroidDownloadPrompt.shouldShowForContext(context);

          if (shouldShowAndroidPrompt) {
            unawaited(
              AndroidDownloadPrompt.precacheImages(context).catchError((_) {}),
            );
            await prefs.setBool(
              AndroidDownloadPrompt.pendingAfterLoginKey,
              true,
            );
          } else {
            await prefs.remove(AndroidDownloadPrompt.pendingAfterLoginKey);
          }

          if (!mounted) return;

          final sessionQuery =
              'session=${DateTime.now().millisecondsSinceEpoch}';
          final apkQuery = shouldShowAndroidPrompt ? '&showApk=1' : '';
          context.go('/dashboard/$rolRuta?$sessionQuery$apkQuery');

          // Iniciar notificaciones después de navegar, sin bloquear el login
          unawaited(NotificacionesRealtimeService.start());
        } on FormatException {
          if (!mounted) return;
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
            content: Text(
              'El servidor esta en mantenimiento. Intente nuevamente en 5 minutos.',
            ),
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

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final String str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  Map<String, dynamic> _safeJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        if (key == null) return;
        final normalizedKey = key is String ? key : key.toString();
        if (normalizedKey.isNotEmpty) {
          result[normalizedKey] = val;
        }
      });
      return result;
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _composeSessionData(
    Map<String, dynamic> profile,
    Map<String, dynamic> loginData, {
    required int usuarioId,
    required String fallbackRole,
    required String email,
    required bool emailConfirmado,
  }) {
    final session = _safeJsonMap(profile);

    session['id'] ??= usuarioId;
    session['usuarioId'] ??= usuarioId;
    session['correo'] ??= email;
    session['emailConfirmado'] =
        (session['emailConfirmado'] == true) || emailConfirmado;

    final String role =
        _stringValue(loginData['rol'])?.toUpperCase() ??
        _stringValue(session['rol'])?.toUpperCase() ??
        fallbackRole;

    session['rol'] = role;

    // Copiar el token JWT desde loginData (obtenido en /api/auth/login)
    final String? token = _stringValue(loginData['token']);
    if (token != null && token.isNotEmpty) {
      session['token'] = token;
    } else {}

    final int? empresaId =
        _toInt(session['empresaId']) ?? _toInt(loginData['empresaId']);
    if (empresaId != null) {
      session['empresaId'] = empresaId;
    }

    final Map<String, dynamic> empresa = _extractEmpresa(session);
    if (empresaId != null) {
      empresa['id'] ??= empresaId;
    }

    final String? estadoVerificacion = _stringValue(
      empresa['estadoVerificacion'] ?? loginData['estadoVerificacion'],
    );
    if (estadoVerificacion != null) {
      empresa['estadoVerificacion'] = estadoVerificacion;
    }

    final String? nombreEmpresa = _stringValue(
      empresa['nombreEmpresa'] ?? loginData['nombreEmpresa'],
    );
    if (nombreEmpresa != null) {
      empresa['nombreEmpresa'] = nombreEmpresa;
    }

    if (empresa.isNotEmpty) {
      session['empresa'] = empresa;
    }

    return session;
  }

  Map<String, dynamic> _extractEmpresa(Map<String, dynamic> session) {
    final dynamic rawEmpresa = session['empresa'];
    final Map<String, dynamic> empresa = _safeJsonMap(rawEmpresa);
    session['empresa'] = empresa;
    return empresa;
  }

  // ignore: unused_element
  bool _isEmpresaVerificada(String state) {
    final normalized = state.toUpperCase();
    const approved = {'APROBADA', 'APROBADO'};
    return approved.contains(normalized);
  }

  String? _resolveVerificationLink(dynamic rawLink) {
    final String? link = _stringValue(rawLink);
    if (link == null) return null;
    final String? normalized = ApiConfig.normalize(link);
    if (normalized != null) {
      return normalized;
    }

    final String base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final String sanitized = link.startsWith('/') ? link : '/$link';
    return '$base$sanitized';
  }

  Future<Map<String, dynamic>?> _fetchUserDetails(
    int userId, {
    String? token,
  }) async {
    try {
      final Map<String, String> headers = {'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(_endpoint('/api/usuarios/$userId'), headers: headers)
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

  Future<void> _showVerificationPendingDialog(
    String email, {
    String? verificationLink,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = const Color(0xFF0C1C58);
        final secondary = const Color(0xFF1D2B7B);
        final overlay = Colors.white.withValues(alpha: 0.14);
        final bool isDark = theme.brightness == Brightness.dark;
        final footerColor = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF3F6FF);

        return Dialog(
          backgroundColor: const Color.fromARGB(0, 255, 255, 255),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 26,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: overlay,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(13),
                        child: const Icon(
                          Icons.mark_email_unread,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Verifica tu correo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tu cuenta está pendiente de validación.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hemos enviado un enlace de verificación a $email. '
                        'Completa la verificación desde tu correo electrónico antes de iniciar sesión.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                      if (verificationLink != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          '¿No lo encuentras?',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Puedes abrir manualmente el siguiente enlace de verificación:',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: SelectableText(
                              verificationLink,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => _copyToClipboard(verificationLink),
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copiar enlace'),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: footerColor,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE1E6F5),
                      ),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      child: const Text('Entendido'),
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

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles')),
    );
  }

  // ignore: unused_element
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
    final bool isDesktop = size.width >= 900;
    // Desktop: use a narrower factor (33%) and cap the width so the
    // card doesn't become too wide on very large screens.
    final double cardWidthFactor = isDesktop
        ? 0.33
        : (isCompactWidth ? 0.92 : (size.width <= 420 ? 0.86 : 0.80));
    final double cardWidth = size.width * cardWidthFactor;

    final double cardWidthLimited = isDesktop
        ? cardWidth.clamp(360.0, 520.0)
        : cardWidth.clamp(300.0, 430.0);

    final double horizontalPadding = size.width < 380 ? 12 : 16;

    // More responsive and smaller logo with better scaling for web
    final double logoFactor = isDesktop ? 0.18 : 0.25;
    final double logoDiameter = _responsiveClamp(
      value: size.width * logoFactor,
      min: 80,
      max: 140,
    );
    final double logoRadius = logoDiameter / 2;
    const darkBlue = Color(0xFF06135E);
    return Scaffold(
      backgroundColor: const Color(0xFF101F63),
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
                      width: cardWidthLimited,
                      margin: EdgeInsets.only(top: logoRadius * 1.2),
                      constraints: const BoxConstraints(minHeight: 0),
                      child: Card(
                        color: Colors.white,
                        elevation: 14,
                        shadowColor: const Color(
                          0xFF06135E,
                        ).withValues(alpha: 0.18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide.none,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding + 8,
                            24,
                            horizontalPadding + 8,
                            22,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Simple TabBar without any visible selection indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F6FF),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE4E8F8),
                                    width: 1,
                                  ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  dividerColor: Colors.transparent,
                                  indicatorColor: Colors.transparent,
                                  indicatorWeight: 0.01,
                                  indicatorSize: TabBarIndicatorSize.label,
                                  overlayColor:
                                      const WidgetStatePropertyAll<Color>(
                                        Colors.transparent,
                                      ),
                                  labelColor: const Color(0xFF06135E),
                                  unselectedLabelColor: const Color(
                                    0xFF06135E,
                                  ).withValues(alpha: 0.48),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 0.3,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    letterSpacing: 0.1,
                                  ),
                                  tabs: const [
                                    Tab(text: 'ÚNETE'),
                                    Tab(text: 'INICIA SESIÓN'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Let the TabBarView expand to fill available space inside the card
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                alignment: Alignment.topCenter,
                                child: _tabController.index == 0
                                    ? _buildUneteSection(darkBlue)
                                    : _buildLoginSection(darkBlue),
                              ),
                            ],
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
        const SizedBox(height: 2),
        TextField(
          controller: _nameCtrl,
          decoration: _inputDecoration('Nombre de Empresa'),
        ),
        const SizedBox(height: 6),
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
        const SizedBox(height: 6),
        TextField(
          controller: _repCtrl,
          decoration: _inputDecoration('Representante legal C.C'),
        ),
        const SizedBox(height: 6),
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
        const SizedBox(height: 6),
        TextField(
          controller: _signupPassCtrl,
          obscureText: _signupPassObscure,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          ],
          decoration: _inputDecoration('Contraseña').copyWith(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
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
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _confirmPassObscure,
          decoration: _inputDecoration('Confirmar Contraseña').copyWith(
            prefixIcon: const Icon(Icons.verified_user_outlined),
            suffixIcon: IconButton(
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
        const SizedBox(height: 6),
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
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isUneteValid && !_signUpLoading) ? _doSignUp : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: EdgeInsets.zero,
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
                      ? const [Color(0xFF06135E), Color(0xFF3330BE)]
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
        const SizedBox(height: 6),
        const SizedBox(height: 12),
        TextField(
          controller: _userCtrl,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
          decoration: _inputDecoration(
            'Correo electrónico',
          ).copyWith(prefixIcon: const Icon(Icons.mail_outline_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
          obscureText: _loginPassObscure,
          decoration: _inputDecoration('Contraseña').copyWith(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
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
                  colors: [Color(0xFF06135E), Color(0xFF3330BE)],
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
                        'Iniciar sesión',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ],
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
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF06135E).withValues(alpha: 0.72),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF06135E),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      prefixIconColor: const Color(0xFF06135E),
      suffixIconColor: const Color(0xFF06135E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E7F3), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E7F3), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF3330BE), width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD92D20), width: 1.3),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD92D20), width: 1.5),
      ),
    );
  }

  Widget _buildRoleShortcutButtons() {
    return Column(
      children: [
        const Text(
          'Aplicación demo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = constraints.maxWidth < 420
                ? constraints.maxWidth * 0.92
                : 180.0;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children:
                  [
                    _buildDirectAccessButton(
                      context: context,
                      label: 'Empresa',
                      role: 'ROLE_EMPRESA',
                    ),
                    _buildDirectAccessButton(
                      context: context,
                      label: 'Propietario',
                      role: 'ROLE_PROPIETARIO',
                    ),
                    _buildDirectAccessButton(
                      context: context,
                      label: 'Conductor',
                      role: 'ROLE_CONDUCTOR',
                    ),
                  ].map((button) {
                    return SizedBox(width: buttonWidth, child: button);
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDirectAccessButton({
    required BuildContext context,
    required String label,
    required String role,
  }) {
    return FilledButton.icon(
      onPressed: (_loginLoading || _signUpLoading)
          ? null
          : () => _openRoleShortcut(role),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF06135E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  Future<void> _doDirectLogin(String email, String password) async {
    if (_loginLoading) return;
    // populate controllers and validate
    _userCtrl.text = email;
    _passCtrl.text = password;
    _validateForms();
    if (!mounted) return;
    setState(() => _isLoginValid = true);
    await _doLogin();
  }

  void _openRoleShortcut(String roleKey) {
    // Use real test accounts when available
    switch (roleKey) {
      case 'ROLE_EMPRESA':
        _doDirectLogin('empresademo@test.com', 'Juan12345678');
        return;
      case 'ROLE_PROPIETARIO':
        _doDirectLogin('propietario@test.com', 'Juan12345678');
        return;
      case 'ROLE_CONDUCTOR':
        _doDirectLogin('conductor@test.com', 'Juan12345678');
        return;
      default:
        // Fallback demo user for other roles
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

        final String rolRuta = _roleToRoute(demoUser['rol']);

        if (rolRuta.isEmpty) return;

        context.go('/dashboard/$rolRuta');
    }
  }
}
