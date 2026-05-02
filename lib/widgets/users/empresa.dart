import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Muestra informacion de la empresa vinculada a un conductor con vision, mision y feedback.
class EmpresaWidget extends StatefulWidget {
  final String? userId;
  final String? jsonPath;
  final String? companyId;

  const EmpresaWidget({super.key, this.userId, this.jsonPath, this.companyId});

  @override
  State<EmpresaWidget> createState() => _EmpresaWidgetState();
}

class _Company {
  final int id;
  final String nombre;
  final String logo;
  final String vision;
  final String mision;
  final String descripcion;
  final String contactoEmail;
  final String contactoTelefono;

  const _Company({
    required this.id,
    required this.nombre,
    required this.logo,
    required this.vision,
    required this.mision,
    required this.descripcion,
    required this.contactoEmail,
    required this.contactoTelefono,
  });
}

class _EmpresaWidgetState extends State<EmpresaWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _surfaceColor = Color(0xFF131760);

  bool _isLoading = true;
  _Company? _company;
  final TextEditingController _messageController = TextEditingController();
  bool _feedbackSending = false;
  bool _feedbackSent = false;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCompany() async {
    final String path = (widget.jsonPath != null && widget.jsonPath!.isNotEmpty)
        ? widget.jsonPath!
        : 'assets/companies_data.json';

    try {
      final String raw = await rootBundle.loadString(path);
      final dynamic decoded = json.decode(raw);
      final List<dynamic>? companies = decoded is Map<String, dynamic>
          ? decoded['companies'] as List<dynamic>?
          : decoded as List<dynamic>?;

      if (companies != null && companies.isNotEmpty) {
        _Company? selected;
        if (widget.companyId != null) {
          final int? target = int.tryParse(widget.companyId!);
          if (target != null) {
            selected = companies
                .whereType<Map<String, dynamic>>()
                .map(_mapToCompany)
                .firstWhere(
                  (company) => company.id == target,
                  orElse: () => companies
                      .whereType<Map<String, dynamic>>()
                      .map(_mapToCompany)
                      .first,
                );
          }
        }
        selected ??= companies.whereType<Map<String, dynamic>>().map(_mapToCompany).first;

        if (!mounted) {
          return;
        }
        setState(() {
          _company = selected;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error cargando empresa: $e');
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _company = const _Company(
        id: 0,
        nombre: 'Empresa sin datos',
        logo: 'assets/logo.png',
        vision: 'Sin vision disponible.',
        mision: 'Sin mision disponible.',
        descripcion: 'No se encontro informacion de la empresa.',
        contactoEmail: 'contacto@empresa.com',
        contactoTelefono: '+57 300 000 0000',
      );
      _isLoading = false;
    });
  }

  _Company _mapToCompany(Map<String, dynamic> map) {
    return _Company(
      id: int.tryParse(map['id_empresa']?.toString() ?? '') ?? 0,
      nombre: map['nombre']?.toString() ?? 'Empresa',
      logo: map['logo']?.toString() ?? 'assets/logo.png',
      vision: map['vision']?.toString() ?? 'Sin vision disponible.',
      mision: map['mision']?.toString() ?? 'Sin mision disponible.',
      descripcion: map['descripcion']?.toString() ?? 'Sin descripcion.',
      contactoEmail: map['contacto_email']?.toString() ?? 'contacto@empresa.com',
      contactoTelefono: map['contacto_telefono']?.toString() ?? '+57 300 000 0000',
    );
  }

  void _showInfoModal({required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Text(body, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      setState(() {
        _feedbackSent = false;
      });
      return;
    }

    setState(() {
      _feedbackSending = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) {
      return;
    }
    setState(() {
      _feedbackSending = false;
      _feedbackSent = true;
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_company == null) {
      return const Center(child: Text('No se encontro la empresa.', style: TextStyle(color: Colors.white)));
    }

    final _Company company = _company!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 640;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      company.logo,
                      width: isCompact ? 72 : 92,
                      height: isCompact ? 72 : 92,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.nombre,
                          style: TextStyle(color: Colors.white, fontSize: isCompact ? 20 : 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          company.descripcion,
                          style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _buildInfoButton(
                    icon: Icons.visibility_rounded,
                    label: 'Vision',
                    onTap: () => _showInfoModal(title: 'Vision', body: company.vision),
                  ),
                  _buildInfoButton(
                    icon: Icons.flag_rounded,
                    label: 'Mision',
                    onTap: () => _showInfoModal(title: 'Mision', body: company.mision),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildContactCard(company, isCompact),
              const SizedBox(height: 28),
              _buildFeedbackSection(isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [_accentColor.withValues(alpha: 0.85), _accentColor.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 12)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(_Company company, bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 18 : 22, vertical: 20),
      decoration: BoxDecoration(
        color: _cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contacto directo', style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.email_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(company.contactoEmail, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone_in_talk_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(company.contactoTelefono, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 18 : 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enviar mensaje a la empresa',
            style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Comparte reseñas o peticiones para el equipo administrativo. El mensaje se enviara al buzón corporativo.',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Escribe tu mensaje...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: _accentColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _feedbackSent
                      ? const Text(
                          'Mensaje enviado correctamente.',
                          key: ValueKey('sent'),
                          style: TextStyle(
                            color: Color(0xFF7CFC9A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          'Los mensajes se remiten al area administrativa.',
                          key: const ValueKey('helper'),
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _feedbackSending ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _feedbackSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Enviar'),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
