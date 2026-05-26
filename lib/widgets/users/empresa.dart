import 'package:flutter/material.dart';
import 'package:trackfile/l10n/app_language.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EmpresaWidget extends StatefulWidget {
  final String? userId;
  final String? jsonPath;
  final String? companyId;

  const EmpresaWidget({
    super.key,
    this.userId,
    this.jsonPath,
    this.companyId,
  });

  @override
  State<EmpresaWidget> createState() => _EmpresaWidgetState();
}

class _EmpresaInfo {
  final String nombre;
  final String correo;
  final String telefono;
  final String direccion;

  const _EmpresaInfo({
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.direccion,
  });
}

class _EmpresaWidgetState extends State<EmpresaWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _surfaceColor = Color(0xFF131760);

  bool _isLoading = true;
  String? _error;
  _EmpresaInfo? _empresa;

  @override
  void initState() {
    super.initState();
    _loadEmpresa();
  }

  Future<void> _loadEmpresa() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getMiEmpresa();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _empresa = null;
          _error = context.t('company.notFound');
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _empresa = _mapEmpresa(data);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = context.t('company.loadError');
        _isLoading = false;
      });

    }
  }

  _EmpresaInfo _mapEmpresa(Map<String, dynamic> map) {
    return _EmpresaInfo(
      nombre: _value(
        map['nombreEmpresa'] ??
            map['nombre_empresa'] ??
            map['nombre'] ??
            map['razonSocial'],
      ),
      correo: _value(map['correo'] ?? map['email']),
      telefono: _value(map['telefono'] ?? map['celular']),
      direccion: _value(map['direccion']),
    );
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? context.t('common.notRegistered') : text;
  }

  Future<void> _openEmail(String correo) async {
    if (correo == context.t('common.notRegistered')) return;

    final uri = Uri(
      scheme: 'mailto',
      path: correo,
      query: 'subject=Contacto desde TrackFile',
    );

    await _launch(uri);
  }

  Future<void> _openPhone(String telefono) async {
    if (telefono == context.t('common.notRegistered')) return;

    final cleanPhone = telefono.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);

    await _launch(uri);
  }

  Future<void> _launch(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('company.openError')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _empresa == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? context.t('company.notFound'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final empresa = _empresa!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 18 : 34,
            vertical: 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(empresa, isCompact),
                  const SizedBox(height: 24),
                  _buildMainInfo(empresa, isCompact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_EmpresaInfo empresa, bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _cardColor.withValues(alpha: 0.96),
            _accentColor.withValues(alpha: 0.38),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 64 : 78,
            height: isCompact ? 64 : 78,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('company.linked'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  empresa.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 23 : 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo(_EmpresaInfo empresa, bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 18 : 26,
        vertical: isCompact ? 18 : 24,
      ),
      decoration: BoxDecoration(
        color: _surfaceColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _buildContactRow(
            icon: Icons.email_rounded,
            title: context.t('profile.email'),
            value: empresa.correo,
            actionText: context.t('company.sendEmail'),
            onTap: () => _openEmail(empresa.correo),
          ),
          _divider(),
          _buildContactRow(
            icon: Icons.phone_in_talk_rounded,
            title: context.t('profile.phone'),
            value: empresa.telefono,
            actionText: context.t('company.call'),
            onTap: () => _openPhone(empresa.telefono),
          ),
          _divider(),
          _buildContactRow(
            icon: Icons.location_on_rounded,
            title: context.t('profile.address'),
            value: empresa.direccion,
            actionText: null,
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String title,
    required String value,
    required String? actionText,
    required VoidCallback? onTap,
  }) {
    final bool canTap = onTap != null && value != 'No registrado';

    return InkWell(
      onTap: canTap ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (canTap && actionText != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.38),
                  ),
                ),
                child: Text(
                  actionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}
