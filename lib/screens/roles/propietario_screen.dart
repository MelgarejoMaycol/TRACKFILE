import 'package:flutter/material.dart';

class PropietarioScreen extends StatelessWidget {
  const PropietarioScreen({super.key});
  static const route = '/propietario';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Propietario')),
      body: const Center(child: Text('Pantalla Propietario')),
    );
  }
}
