import 'package:flutter/material.dart';

/// Signup screen — placeholder until AuthBloc is wired in Phase 1 auth work.
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: const Center(
        child: Text('Signup screen — coming soon.'),
      ),
    );
  }
}
