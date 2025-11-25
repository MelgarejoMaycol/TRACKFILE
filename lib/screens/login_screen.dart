import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import './roles/admin_screen.dart';
import './roles/conductor_screen.dart';
import './roles/propietario_screen.dart';
import './roles/empresa_screen.dart';
import './roles/secretaria_screen.dart';
import 'dart:io' show Platform;


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
  bool _loading = false;
  late final TabController _tabController;
  bool _isUneteValid = false;
  bool _isLoginValid = false;
  // Password visibility toggles
  bool _signupPassObscure = true;
  bool _confirmPassObscure = true;
  bool _loginPassObscure = true;

  String? _lastPickError;

  // Mock upload state
  String? _uploadedFileName;

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
    final hasPdf = _uploadedFileName != null && _uploadedFileName!.toLowerCase().endsWith('.pdf');

    final newUnete = nameOk && nitOk && repOk && emailOk && passOk && confirmOk && hasPdf;
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
    // Show the validation modal (48h notice) and then reset fields.
    if (!mounted) return;
    await _showValidationModal();
    // After user closes modal, clear form fields (simulate a reset)
    if (!mounted) return;
    setState(() {
      _signupPassCtrl.clear();
      _confirmPassCtrl.clear();
      _emailCtrl.clear();
      _nitCtrl.clear();
      _repCtrl.clear();
      _nameCtrl.clear();
      _uploadedFileName = null;
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
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'demo-token');
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _simulateUpload() async {
    String? name = await _pickFileOnce();
    if (name != null) {
      // Ensure selected file is PDF (case-insensitive)
      if (name.toLowerCase().endsWith('.pdf')) {
        if (mounted) setState(() => _uploadedFileName = name);
        if (mounted) _validateForms();
      } else {
        _lastPickError = 'El archivo debe ser un PDF';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un archivo PDF válido')));
      }
      return;
    }

    // If the picker failed or returned null, offer retry or manual entry
    if (!mounted) return;
    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Seleccionar archivo'),
          content: const Text('No se pudo abrir el selector de archivos. ¿Quieres intentar de nuevo o ingresar el nombre manualmente?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop('retry'), child: const Text('Reintentar')),
            TextButton(onPressed: () => Navigator.of(ctx).pop('manual'), child: const Text('Ingresar manualmente')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
          ],
        );
      },
    );

    if (choice == 'retry') {
      final retryName = await _pickFileOnce();
      if (retryName != null && mounted) {
        if (retryName.toLowerCase().endsWith('.pdf')) {
          setState(() => _uploadedFileName = retryName);
          _validateForms();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El archivo debe ser un PDF')));
        }
      }
      return;
    }

    if (choice == 'manual') {
      final manual = await _enterFileNameManually();
      if (manual != null && mounted) {
        if (manual.toLowerCase().endsWith('.pdf')) {
          setState(() => _uploadedFileName = manual);
          _validateForms();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El archivo debe ser un PDF')));
        }
      }
    }
    // If we get here, both pick attempts failed or user cancelled. Show helpful error message.
    if (_lastPickError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar archivo: $_lastPickError')));
    }
  }

  /// Called when the user taps the "Subir documento" button.
  /// On Android we'll try the native chooser via MethodChannel first so the
  /// user can pick which app (Files, Drive, etc.) to use. If that fails or
  /// on other platforms, fall back to the existing picker flow.
  Future<void> _onUploadPressed() async {
    if (!mounted) return;
    // Try Android native chooser first
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('app.channel/files');
        final String? name = await platform.invokeMethod('openDocumentPicker');
        if (name != null) {
          if (name.toLowerCase().endsWith('.pdf')) {
            if (mounted) setState(() => _uploadedFileName = name);
            if (mounted) _validateForms();
          } else {
            _lastPickError = 'El archivo debe ser un PDF';
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un archivo PDF válido')));
          }
          return;
        }
      } catch (e) {
        // keep the error in _lastPickError for diagnostics and fall through
        _lastPickError = 'platform intent failed: $e';
        debugPrint(_lastPickError);
      }
    }

    // Non-Android or intent failed: use the pickers
    await _simulateUpload();
  }

  Future<String?> _pickFileOnce() async {
    // On Android try the native intent chooser implemented in MainActivity first
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('app.channel/files');
        final String? name = await platform.invokeMethod('openDocumentPicker');
        if (name != null) return name;
      } catch (e) {
        _lastPickError = 'platform intent failed: $e';
        debugPrint(_lastPickError);
      }
    }

    // First try file_picker and restrict to PDF only for the signup flow
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) return result.files.single.name;
    } catch (e) {
      _lastPickError = 'file_picker failed: $e';
      debugPrint(_lastPickError);
    }

    // Fallback: try file_selector which is often better behaved on desktop platforms
    try {
      final typeGroup = fs.XTypeGroup(label: 'documents', extensions: ['pdf']);
      final fs.XFile? xf = await fs.openFile(acceptedTypeGroups: [typeGroup]);
      if (xf != null) return xf.name;
    } catch (e) {
      _lastPickError = 'file_selector fallback failed: $e';
      debugPrint(_lastPickError);
    }

    return null;
  }

  Future<String?> _enterFileNameManually() async {
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ingresar nombre de archivo'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'ej: documento.pdf'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
            TextButton(onPressed: () {
              final txt = controller.text.trim();
              if (!txt.toLowerCase().endsWith('.pdf')) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('El nombre debe terminar en .pdf')));
                return;
              }
              Navigator.of(ctx).pop(txt);
            }, child: const Text('Aceptar')),
          ],
        );
      },
    );
    controller.dispose();
    if (res != null && res.isNotEmpty) return res;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
                      width: size.width * 0.80,
                      height: size.height * 0.75,
                      margin: const EdgeInsets.only(top: 70),
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
                                  unselectedLabelColor: darkBlue.withOpacity(0.6),
                                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                  // Ensure the TabBar does not draw any underline or indicator
                                  indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.transparent, width: 0)),
                                  indicatorWeight: 0,
                                  indicatorPadding: EdgeInsets.zero,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  overlayColor: MaterialStatePropertyAll(Colors.transparent),
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
                          radius: 88,
                          backgroundColor: Colors.transparent,
                          child: ClipOval(
                            child: Image.asset('assets/logoCirculo.png', width: 160, height: 160, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Role quick-navigation buttons (temporary)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())), child: const Text('Admin')),
                      ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConductorScreen(userId: '1'))), child: const Text('Conductor')),
                      ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PropietarioScreen())), child: const Text('Propietario')),
                      ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmpresaScreen())), child: const Text('Empresa')),
                      ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecretariaScreen())), child: const Text('Secretaría')),
                    ],
                  ),
                ),
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
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _onUploadPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                backgroundColor: const Color(0xFFF5F7FA),
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.upload_file, color: Color(0xFF06135E)),
                  SizedBox(width: 8),
                  Text('Subir documento', style: TextStyle(color: Color(0xFF06135E))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_uploadedFileName != null) Text('Archivo subido: $_uploadedFileName'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUneteValid ? _doSignUp : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 0),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _isUneteValid ? const [Color(0xFF06135E), Color(0xFF16C79A)] : [Colors.grey.shade400, Colors.grey.shade500]),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              // Reducimos la altura mínima para que el botón sea más angosto verticalmente
              child: Container(alignment: Alignment.center, constraints: const BoxConstraints(minHeight: 40), child: const Text('Únete', style: TextStyle(color: Colors.white))),
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
            onPressed: (_isLoginValid && !_loading) ? _doLogin : null,
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
                child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Inicia Sesion', style: TextStyle(color: Colors.white)),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

}
