import 'package:flutter/material.dart';

import 'package:frontendproyecto/widgets/logout_button.dart';

class SecretariaScreen extends StatelessWidget {
  const SecretariaScreen({super.key});
  static const route = '/secretaria';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secretaría')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(
                child: Center(
                  child: Text('Pantalla Secretaría'),
                ),
              ),
              LogoutButton(),
            ],
          ),
        ),
      ),
    );
  }
}
