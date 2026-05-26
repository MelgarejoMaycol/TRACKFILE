import 'package:flutter/material.dart';
import 'package:trackfile/l10n/app_language.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/services/frontend_cache.dart';
import 'package:trackfile/services/notifications/notificaciones_preferencias_service.dart';
import 'package:trackfile/services/notifications/notificaciones_realtime_service.dart';
import 'package:trackfile/widgets/utils/logout_button.dart';
import 'package:trackfile/widgets/utils/shimmer_skeleton.dart';

class PerfilWidget extends StatefulWidget {
  final String? userId;
  final String role;
  final String? userName;
  final String? userCompany;
  final String? userEmail;
  final String? userPhone;
  final String? userAddress;
  final String? userDocument;
  final VoidCallback? onEmpresaActualizada;
  final Future<void> Function()? onPerfilActualizado;

  const PerfilWidget({
    super.key,
    required this.role,
    this.userId,
    this.userName,
    this.userCompany,
    this.userEmail,
    this.userPhone,
    this.userAddress,
    this.userDocument,
    this.onEmpresaActualizada,
    this.onPerfilActualizado,
  });

  @override
  State<PerfilWidget> createState() => _PerfilWidgetState();
}

class _PerfilUsuario {
  final String id;
  final String nombre;
  final String empresa;
  final String email;
  final String telefono;
  final String imagen;
  final List<_PerfilStat> estadisticas;
  final List<_PerfilDato> datos;
  final List<_CertificacionItem> certificaciones;
  final List<_VehiculoCompacto> vehiculos;

  const _PerfilUsuario({
    required this.id,
    required this.nombre,
    required this.empresa,
    required this.email,
    required this.telefono,
    required this.imagen,
    required this.estadisticas,
    required this.datos,
    required this.certificaciones,
    required this.vehiculos,
  });
}

class _PerfilStat {
  final String value;
  final String label;

  const _PerfilStat({required this.value, required this.label});
}

class _PerfilDato {
  final String label;
  final String value;

  const _PerfilDato({required this.label, required this.value});
}

class _CertificacionItem {
  final String nombre;
  final String estado;

  const _CertificacionItem({required this.nombre, required this.estado});
}

class _VehiculoCompacto {
  final String placa;
  final String modelo;
  final String estado;

  const _VehiculoCompacto({
    required this.placa,
    required this.modelo,
    required this.estado,
  });
}

class _PerfilWidgetState extends State<PerfilWidget> {
  static const Color _primaryColor = Color(0xFF3330BE);
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _textColor = Color(0xFF1F2937);
  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _cardColor = Color(0xFF20206B);
  static const Color _panelColor = Color(0xFF171968);
  static const Color _chipColor = Color(0xFF4643DC);
  static const Color _borderColor = Color(0xFF5653D9);
  static const Color _softBorderColor = Color(0xFF3E3BB8);

  bool _notificacionesActivas = true;
  bool _isLoading = true;
  bool _hasError = false;
  _PerfilUsuario? _perfil;
  Map<String, dynamic>? _empresaActual;

  @override
  void initState() {
    super.initState();
    AppLanguageController.instance.addListener(_onLanguageChanged);
    FrontendCache.revision.addListener(_reloadFromCacheUpdate);
    _cargarInicial();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    _cargarPerfil(showLoader: false);
  }

  void _reloadFromCacheUpdate() {
    if (!mounted) return;
    _cargarPerfil(showLoader: false);
  }

  @override
  void dispose() {
    AppLanguageController.instance.removeListener(_onLanguageChanged);
    FrontendCache.revision.removeListener(_reloadFromCacheUpdate);
    super.dispose();
  }

  Future<void> _cargarInicial() async {
    await Future.wait([_cargarPreferenciasNotificaciones(), _cargarPerfil()]);
  }

  Future<void> _cargarPreferenciasNotificaciones() async {
    final activas = await NotificacionesPreferenciasService.estanActivas();

    if (!mounted) return;

    setState(() {
      _notificacionesActivas = activas;
    });
  }

  Future<void> _cargarPerfil({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final perfilBackend = await ApiService.getMiPerfil();
      final empresaBackend = await ApiService.getMiEmpresa();
      if (!mounted) return;

      if (perfilBackend == null) {
        throw Exception('Perfil vacío');
      }

      final empresa = empresaBackend ?? perfilBackend['empresa'];

      final nombreCompleto =
          '${perfilBackend['nombre'] ?? ''} ${perfilBackend['apellido'] ?? ''}'
              .trim();

      final String empresaNombre = empresa is Map<String, dynamic>
          ? empresa['nombreEmpresa']?.toString() ?? context.t('common.noCompany')
          : context.t('common.noCompany');

      final _PerfilUsuario perfil = _PerfilUsuario(
        id: perfilBackend['id']?.toString() ?? '0',
        nombre: nombreCompleto.isNotEmpty ? nombreCompleto : 'Usuario',
        empresa: empresaNombre,
        email: perfilBackend['correo']?.toString() ?? 'Sin correo',
        telefono: perfilBackend['telefono']?.toString() ?? 'Sin teléfono',
        imagen: '',
        estadisticas: [
          _PerfilStat(
            value: widget.role,
            label: context.t('profile.userRole').replaceAll(' ', '\n'),
          ),
          _PerfilStat(
            value: empresaNombre,
            label: context.t('profile.companyAssociated').replaceAll(' ', '\n'),
          ),
          _PerfilStat(
            value: context.t('profile.active'),
            label: context.t('profile.status').replaceAll(' ', '\n'),
          ),
        ],
        datos: [
          _PerfilDato(
            label: context.t('profile.name'),
            value: perfilBackend['nombre']?.toString() ?? '-',
          ),
          _PerfilDato(
            label: context.t('profile.lastName'),
            value: perfilBackend['apellido']?.toString() ?? '-',
          ),
          _PerfilDato(
            label: context.t('profile.email'),
            value: perfilBackend['correo']?.toString() ?? '-',
          ),
          _PerfilDato(
            label: context.t('profile.phone'),
            value: perfilBackend['telefono']?.toString() ?? '-',
          ),
          _PerfilDato(
            label: context.t('profile.address'),
            value: perfilBackend['direccion']?.toString() ?? '-',
          ),
          _PerfilDato(
            label: context.t('profile.role'),
            value: perfilBackend['rol']?.toString() ?? widget.role,
          ),
        ],
        certificaciones: const [],
        vehiculos: const [],
      );

      if (!mounted) return;

      setState(() {
        _perfil = perfil;
        _empresaActual = empresa is Map<String, dynamic> ? empresa : null;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerPerfilPage();
    }
    if (_hasError || _perfil == null) {
      return _buildError();
    }
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Container(
        color: _surfaceColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 920;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 24,
                24,
                isCompact ? 16 : 24,
                isCompact ? 120 : 80,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isCompact),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _buildPerfilCard(isCompact),
                          _buildDetallesCard(isCompact),
                        ],
                      ),

                      if (widget.role.toLowerCase() == 'empresa') ...[
                        const SizedBox(height: 24),
                        _buildEmpresaInfoCard(isCompact),
                      ],

                      const SizedBox(height: 24),
                      _buildPreferenciasCard(isCompact),
                      const SizedBox(height: 24),
                      _buildAccionesPerfil(isCompact),
                      const SizedBox(height: 30),
                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: const LogoutButton(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.person_pin_circle_rounded,
              color: _primaryColor,
              size: isCompact ? 24 : 28,
            ),
            const SizedBox(width: 10),
            Text(
              context.t('profile.title'),
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 19 : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.t('profile.subtitle'),
          style: TextStyle(
            color: Colors.white70,
            fontSize: isCompact ? 12.5 : 13.5,
          ),
        ),

        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _chipColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                perfil.empresa,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerfilCard(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    return Container(
      width: isCompact ? double.infinity : 360,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 18 : 22,
        22,
        isCompact ? 18 : 22,
        22,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(perfil.imagen),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      perfil.email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      perfil.telefono,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: perfil.estadisticas.map(_buildStatChip).toList(),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  Widget _buildDetallesCard(bool isCompact) {
    final _PerfilUsuario perfil = _perfil!;
    return Container(
      width: isCompact ? double.infinity : 640,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: _primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                context.t('profile.personalInfo'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            children: perfil.datos
                .map(
                  (dato) => SizedBox(
                    width: isCompact ? double.infinity : 280,
                    child: _buildDatoTile(dato),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpresaInfoCard(bool isCompact) {
    final empresa = _empresaActual ?? {};

    final datosEmpresa = [
      _PerfilDato(
        label: context.t('profile.companyName'),
        value: _empresaValor(
          empresa['nombreEmpresa'] ??
              empresa['nombre_empresa'] ??
              empresa['nombre'],
        ),
      ),
      _PerfilDato(
        label: context.t('profile.companyEmail'),
        value: _empresaValor(empresa['correo'] ?? empresa['email']),
      ),
      _PerfilDato(
        label: context.t('profile.phone'),
        value: _empresaValor(empresa['telefono'] ?? empresa['celular']),
      ),
      _PerfilDato(
        label: context.t('profile.address'),
        value: _empresaValor(empresa['direccion']),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_rounded, color: _primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                context.t('profile.companyInfo'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            children: datosEmpresa
                .map(
                  (dato) => SizedBox(
                    width: isCompact ? double.infinity : 310,
                    child: _buildDatoTile(dato),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesPerfil(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.manage_accounts_rounded,
                color: _primaryColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                context.t('profile.accountActions'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: isCompact ? double.infinity : 260,
                child: ElevatedButton.icon(
                  onPressed: _abrirEditarPerfil,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(context.t('profile.editInfo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _chipColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              SizedBox(
                width: isCompact ? double.infinity : 260,
                child: OutlinedButton.icon(
                  onPressed: _abrirCambiarPassword,
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: Text(context.t('profile.changePassword')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              if (widget.role.toLowerCase() == 'empresa')
                SizedBox(
                  width: isCompact ? double.infinity : 260,
                  child: ElevatedButton.icon(
                    onPressed: _abrirEditarEmpresa,
                    icon: const Icon(Icons.business_rounded, size: 18),
                    label: Text(context.t('profile.editCompany')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildPreferenciasCard(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: _primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                context.t('profile.preferences'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final language = _buildLanguageSelector(isCompact);
              final notifications = _buildNotificationsPreference();

              if (compact) {
                return Column(
                  children: [
                    language,
                    const SizedBox(height: 14),
                    notifications,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: language),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: notifications),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsPreference() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.55)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _notificacionesActivas,
        onChanged: (value) async {
          await NotificacionesPreferenciasService.guardar(value);

          if (value) {
            await NotificacionesRealtimeService.start();
          } else {
            NotificacionesRealtimeService.stop();
          }

          if (!mounted) return;

          setState(() {
            _notificacionesActivas = value;
          });
        },
        activeThumbColor: Colors.white,
        activeTrackColor: _accentColor,
        inactiveThumbColor: Colors.white70,
        inactiveTrackColor: Colors.white24,
        title: Text(
          context.t('profile.notifications'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          _notificacionesActivas
              ? context.t('profile.notificationsOn')
              : context.t('profile.notificationsOff'),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        secondary: const Icon(
          Icons.notifications_active_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAvatar(String imagen) {
    if (imagen.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: AssetImage(imagen),
        backgroundColor: _textColor.withValues(alpha: 0.1),
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: _primaryColor.withValues(alpha: 0.10),
      child: const Icon(Icons.person, color: _primaryColor, size: 32),
    );
  }

  Widget _buildLanguageSelector(bool isCompact) {
    final selectedCode = AppLanguageController.instance.value.languageCode;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('language.settings'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.t('language.subtitle'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppLanguageController.supportedLanguages.map((language) {
              final selected = language.code == selectedCode;
              return ChoiceChip(
                avatar: Text(
                  language.flag,
                  style: const TextStyle(fontSize: 16),
                ),
                label: Text(language.nativeName),
                selected: selected,
                showCheckmark: false,
                selectedColor: _accentColor,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(
                  color: selected ? _borderColor : Colors.white24,
                ),
                labelStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
                onSelected: (_) async {
                  await AppLanguageController.instance.setLanguage(
                    language.code,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t('language.changed'))),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            context.t('language.helper'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(_PerfilStat stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.82),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              stat.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              stat.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatoTile(_PerfilDato dato) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border.all(color: _softBorderColor.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dato.label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            dato.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _modalDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
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
          offset: const Offset(0, 18),
        ),
      ],
    );
  }

  Widget _modalHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onClose,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4F4CE8)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _abrirEditarPerfil() {
    final nombre = TextEditingController(text: _valorDato(context.t('profile.name')));
    final apellido =
        TextEditingController(text: _valorDato(context.t('profile.lastName')));
    final telefono =
        TextEditingController(text: _valorDato(context.t('profile.phone')));
    final direccion =
        TextEditingController(text: _valorDato(context.t('profile.address')));

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: _modalDecoration(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modalHeader(
                          icon: Icons.person_rounded,
                          title: 'Editar información personal',
                          subtitle: 'Actualiza tus datos básicos de contacto.',
                          onClose: guardando
                              ? null
                              : () => Navigator.pop(context),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _inputDialog(
                                  'Nombre',
                                  nombre,
                                  icon: Icons.badge_rounded,
                                ),
                                _inputDialog(
                                  'Apellido',
                                  apellido,
                                  icon: Icons.person_rounded,
                                ),
                                _inputDialog(
                                  'Teléfono',
                                  telefono,
                                  icon: Icons.phone_rounded,
                                  keyboardType: TextInputType.phone,
                                ),
                                _inputDialog(
                                  'Dirección',
                                  direccion,
                                  icon: Icons.location_on_rounded,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: guardando
                                            ? null
                                            : () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(context.t('common.cancel')),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: guardando
                                            ? null
                                            : () async {
                                                setDialogState(
                                                  () => guardando = true,
                                                );

                                                final ok =
                                                    await ApiService.updateMiPerfil(
                                                      nombre: nombre.text,
                                                      apellido: apellido.text,
                                                      telefono: telefono.text,
                                                      direccion: direccion.text,
                                                    );

                                                if (!context.mounted) return;

                                                Navigator.pop(context);

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      ok
                                                          ? 'Perfil actualizado correctamente'
                                                          : 'No se pudo actualizar el perfil',
                                                    ),
                                                  ),
                                                );

                                                if (ok) {
                                                  await _cargarPerfil(
                                                    showLoader: false,
                                                  );
                                                  await widget
                                                      .onPerfilActualizado
                                                      ?.call();
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accentColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          guardando
                                              ? context.t('common.saving')
                                              : context.t('common.save'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirEditarEmpresa() {
    final empresa = _empresaActual ?? {};

    final nombreEmpresa = TextEditingController(
      text: empresa['nombreEmpresa']?.toString() ?? _perfil?.empresa ?? '',
    );

    final telefono = TextEditingController(
      text: empresa['telefono']?.toString() ?? '',
    );

    final direccion = TextEditingController(
      text: empresa['direccion']?.toString() ?? '',
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: _modalDecoration(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modalHeader(
                          icon: Icons.business_rounded,
                          title: 'Editar empresa',
                          subtitle:
                              'Actualiza la información básica de la empresa.',
                          onClose: guardando
                              ? null
                              : () => Navigator.pop(context),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _inputDialog(
                                  'Nombre de empresa',
                                  nombreEmpresa,
                                  icon: Icons.apartment_rounded,
                                ),
                                _inputDialog(
                                  'Teléfono',
                                  telefono,
                                  icon: Icons.phone_rounded,
                                  keyboardType: TextInputType.phone,
                                ),
                                _inputDialog(
                                  'Dirección',
                                  direccion,
                                  icon: Icons.location_city_rounded,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: guardando
                                            ? null
                                            : () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(context.t('common.cancel')),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: guardando
                                            ? null
                                            : () async {
                                                setDialogState(
                                                  () => guardando = true,
                                                );

                                                final ok =
                                                    await ApiService.updateMiEmpresa(
                                                      nombreEmpresa:
                                                          nombreEmpresa.text,
                                                      telefono: telefono.text,
                                                      direccion: direccion.text,
                                                    );

                                                if (!context.mounted) return;

                                                Navigator.pop(context);

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      ok
                                                          ? 'Empresa actualizada correctamente'
                                                          : 'No se pudo actualizar la empresa',
                                                    ),
                                                  ),
                                                );

                                                if (ok) {
                                                  await _cargarPerfil();
                                                  widget.onEmpresaActualizada
                                                      ?.call();
                                                  await widget
                                                      .onPerfilActualizado
                                                      ?.call();
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accentColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          guardando
                                              ? context.t('common.saving')
                                              : context.t('common.save'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirCambiarPassword() {
    final actual = TextEditingController();
    final nueva = TextEditingController();
    final confirmarNueva = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  decoration: _modalDecoration(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modalHeader(
                          icon: Icons.lock_reset_rounded,
                          title: 'Cambiar contraseña',
                          subtitle:
                              'Ingresa tu contraseña actual y define una nueva.',
                          onClose: guardando
                              ? null
                              : () => Navigator.pop(context),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _inputDialog(
                                  'Contraseña actual',
                                  actual,
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: true,
                                ),
                                _inputDialog(
                                  'Nueva contraseña',
                                  nueva,
                                  icon: Icons.lock_reset_rounded,
                                  obscureText: true,
                                ),
                                _inputDialog(
                                  'Confirmar nueva contraseña',
                                  confirmarNueva,
                                  icon: Icons.lock_person_rounded,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: guardando
                                            ? null
                                            : () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(context.t('common.cancel')),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: guardando
                                            ? null
                                            : () async {
                                                if (nueva.text.trim() !=
                                                    confirmarNueva.text
                                                        .trim()) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'La nueva contraseña y la confirmación no coinciden.',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                if (nueva.text.trim().isEmpty ||
                                                    confirmarNueva.text
                                                        .trim()
                                                        .isEmpty) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'La nueva contraseña no puede estar vacía.',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                setDialogState(
                                                  () => guardando = true,
                                                );

                                                final result =
                                                    await ApiService.cambiarMiPassword(
                                                      passwordActual:
                                                          actual.text,
                                                      passwordNueva: nueva.text,
                                                    );

                                                if (!context.mounted) return;

                                                Navigator.pop(context);

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      result['ok'] == true
                                                          ? result['mensaje']
                                                                .toString()
                                                          : result['error']
                                                                .toString(),
                                                    ),
                                                  ),
                                                );
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accentColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          guardando
                                              ? context.t('common.saving')
                                              : 'Cambiar',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _valorDato(String label) {
    final perfil = _perfil;
    if (perfil == null) return '';

    final dato = perfil.datos.where((item) => item.label == label).toList();

    if (dato.isEmpty) return '';

    return dato.first.value == '-' ? '' : dato.first.value;
  }

  String _empresaValor(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? context.t('common.notRegistered') : text;
  }

  Widget _inputDialog(
    String label,
    TextEditingController controller, {
    IconData icon = Icons.edit_rounded,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70, size: 20),
          filled: true,
          fillColor: _panelColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: _softBorderColor.withValues(alpha: 0.55),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accentColor, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return ColoredBox(
      color: _surfaceColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),

              const Text(
                'No pudimos cargar tu información',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                'Por favor vuelve a iniciar sesión para ver tu perfil.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: () {
                    FrontendCache.invalidateAll();
                    _cargarPerfil();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(context.t('common.retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              const SizedBox(width: 220, child: LogoutButton()),
            ],
          ),
        ),
      ),
    );
  }
}
