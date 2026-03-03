import 'package:flutter/material.dart';

/// Home screen — placeholder until pick sheet and standings are built in Phase 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffey Club Pickem'),
      ),
      body: const Center(
        child: Text('Welcome! Pick sheet coming in Phase 2.'),
      ),
    );
  }
}
