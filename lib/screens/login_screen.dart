import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:frontendproyecto/utils/role_router.dart';


class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
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

  static const String _compiledBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  String get _baseUrl {
    if (_compiledBaseUrl.isNotEmpty) return _compiledBaseUrl;
    if (kIsWeb) return 'http://localhost:8080';
    if (io.Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final nitOk = _nitCtrl.text.trim().isNotEmpty && RegExp(r'^\d+$').hasMatch(_nitCtrl.text.trim());
    final repOk = _repCtrl.text.trim().isNotEmpty;
    final emailOk = _isValidEmail(_emailCtrl.text.trim());
    final passOk = _isValidSignupPassword(_signupPassCtrl.text.trim());
    final confirmOk = _signupPassCtrl.text.trim().isNotEmpty && _signupPassCtrl.text.trim() == _confirmPassCtrl.text.trim();
    final newUnete = nameOk && nitOk && repOk && emailOk && passOk && confirmOk;
    final newLogin = _userCtrl.text.trim().isNotEmpty && _passCtrl.text.trim().isNotEmpty;
    if (newUnete != _isUneteValid || newLogin != _isLoginValid) {
      setState(() {
        _isUneteValid = newUnete;
        _isLoginValid = newLogin;
      });
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
    setState(() => _signUpLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/empresas'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nombreEmpresa': _nameCtrl.text.trim(),
              'nit': _nitCtrl.text.trim(),
              'correo': _emailCtrl.text.trim(),
              'representanteLegal': _repCtrl.text.trim(),
              'cedulaRepresentante': _repCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _showValidationModal();
        if (!mounted) return;
        _resetSignUpForm();
      } else {
        final message = response.body.isNotEmpty ? response.body : 'No se pudo completar el registro.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El servidor tardó demasiado en responder. Inténtalo de nuevo.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar la empresa: $e')));
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
      _isUneteValid = false;
    });
  }

  Future<void> _showValidationModal() async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 48),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF06135E), Color(0xFF162A89)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tu cuenta tiene una validación de 48h',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'En máximo 48 horas recibirás respuesta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF06135E)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    child: const Icon(Icons.notifications, color: Color(0xFF16C79A), size: 36),
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
            Uri.parse('$_baseUrl/api/auth/login'),
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
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final estado = (data['estado'] as String?)?.toUpperCase();
          if (estado != null && estado != 'ACTIVO') {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tu usuario se encuentra en estado $estado. Comunícate con soporte.')));
            return;
          }

          await persistSession(data);
          if (!mounted) return;

          final target = screenForRole(data);
          if (target == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol no reconocido para este usuario.')));
            return;
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => target),
            (route) => false,
          );
        } on FormatException {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respuesta del servidor inválida.')));
        }
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.body.isNotEmpty ? response.body : 'Credenciales incorrectas.')));
      } else {
        final message = response.body.isNotEmpty ? response.body : 'No se pudo iniciar sesión.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tiempo de espera agotado. Verifica tu conexión.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al iniciar sesión: $e')));
      }
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
                        child: SizedBox.expand(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                // Simple TabBar without any visible selection indicator
                                TabBar(
                                  controller: _tabController,
                                  labelColor: darkBlue,
                                  unselectedLabelColor: darkBlue.withValues(alpha: 0.6),
                                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                  // Ensure the TabBar does not draw any underline or indicator
                                  indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.transparent, width: 0)),
                                  indicatorWeight: 0,
                                  indicatorPadding: EdgeInsets.zero,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
                                  tabs: const [Tab(text: 'ÚNETE'), Tab(text: 'INICIA SESIÓN')],
                                ),
                                const SizedBox(height: 8),
                                // Let the TabBarView expand to fill available space inside the card
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [_wrapCenter(_buildUneteSection(darkBlue)), _wrapCenter(_buildLoginSection(darkBlue))],
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
        TextField(controller: _nameCtrl, decoration: _inputDecoration('Nombre de Empresa')),
        const SizedBox(height: 8),
        TextField(
          controller: _nitCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration('Nit').copyWith(
              errorText: _nitCtrl.text.isEmpty ? null : (RegExp(r'^\d+$').hasMatch(_nitCtrl.text) ? null : 'El NIT debe contener solo números'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(controller: _repCtrl, decoration: _inputDecoration('Representante legal C.C')),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Correo Electrónico').copyWith(
            errorText: _emailCtrl.text.isEmpty ? null : (_isValidEmail(_emailCtrl.text.trim()) ? null : 'Correo inválido'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _signupPassCtrl,
          obscureText: _signupPassObscure,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
          decoration: _inputDecoration('Contraseña').copyWith(
            prefixIcon: IconButton(
              icon: Icon(_signupPassObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _signupPassObscure = !_signupPassObscure),
            ),
            errorText: _signupPassCtrl.text.isEmpty ? null : (_isValidSignupPassword(_signupPassCtrl.text) ? null : 'Debe tener mayúscula, número y sin caracteres especiales'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _confirmPassObscure,
          decoration: _inputDecoration('Confirmar Contraseña').copyWith(
            prefixIcon: IconButton(
              icon: Icon(_confirmPassObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _confirmPassObscure = !_confirmPassObscure),
            ),
            errorText: _confirmPassCtrl.text.isEmpty ? null : (_confirmPassCtrl.text == _signupPassCtrl.text ? null : 'Las contraseñas no coinciden'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Únete', style: TextStyle(color: Colors.white)),
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
        TextField(controller: _userCtrl, decoration: _inputDecoration('Usuario')),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: _loginPassObscure,
          decoration: _inputDecoration('Contraseña').copyWith(
            prefixIcon: IconButton(
              icon: Icon(_loginPassObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _loginPassObscure = !_loginPassObscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Olvidaste contraseña?'))),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isLoginValid && !_loginLoading) ? _doLogin : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 0),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
              child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF06135E), Color(0xFF16C79A)]),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              // Reducimos la altura mínima para que el botón sea más angosto verticalmente
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 40),
                child: _loginLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Inicia Sesion', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Wrap a section so it centers vertically when there's extra space, and scrolls when content is large
  Widget _wrapCenter(Widget child) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(padding: EdgeInsets.symmetric(horizontal: 0), child: child),
            ],
          ),
        ),
      );
    });
  }

  double _responsiveClamp({required double value, required double min, required double max}) {
    return value.clamp(min, max).toDouble();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildRoleShortcutButtons() {
    const roleConfigs = [
      {'label': 'Conductor', 'role': 'CONDUCTOR', 'icon': Icons.directions_bus},
      {'label': 'Empresa', 'role': 'EMPRESA', 'icon': Icons.apartment},
      {'label': 'Propietario', 'role': 'PROPIETARIO', 'icon': Icons.person_pin},
      {'label': 'Secretaria', 'role': 'SECRETARIA', 'icon': Icons.support_agent},
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
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
