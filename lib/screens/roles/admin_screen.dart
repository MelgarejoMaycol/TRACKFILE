import 'package:flutter/material.dart';

import 'package:frontendproyecto/widgets/logout_button.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  static const route = '/admin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(
                child: Center(
                  child: Text('Pantalla Admin'),
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
