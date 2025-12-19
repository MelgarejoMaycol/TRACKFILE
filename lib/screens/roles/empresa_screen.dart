import 'package:flutter/material.dart';

class EmpresaScreen extends StatelessWidget {
  const EmpresaScreen({super.key, this.usuario, this.empresa});
  static const route = '/empresa';

  final Map<String, dynamic>? usuario;
  final Map<String, dynamic>? empresa;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? company = empresa ?? usuario?['empresa'] as Map<String, dynamic>?;
    final String companyName = company?['nombreEmpresa']?.toString() ?? 'Mi empresa';
    final String representante = company?['representanteLegal']?.toString() ?? usuario?['nombre']?.toString() ?? '';
    final String nit = company?['nit']?.toString() ?? '--';

    return Scaffold(
      appBar: AppBar(title: Text(companyName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NIT: $nit', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Representante: $representante', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Tablero en construcción', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
