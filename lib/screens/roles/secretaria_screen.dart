import 'package:flutter/material.dart';

class SecretariaScreen extends StatelessWidget {
  const SecretariaScreen({super.key});
  static const route = '/secretaria';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secretaría')),
      body: const Center(child: Text('Pantalla Secretaría')),
    );
  }
}
