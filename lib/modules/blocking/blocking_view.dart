import 'package:flutter/material.dart';

class BlockingView extends StatelessWidget {
  const BlockingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocking')),
      body: const Center(child: Text('Coming in Phase 5')),
    );
  }
}
