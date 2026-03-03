import 'package:flutter/material.dart';

/// Login screen — placeholder until AuthBloc is wired in Phase 1 auth work.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: const Center(
        child: Text('Login screen — coming soon.'),
      ),
    );
  }
}
