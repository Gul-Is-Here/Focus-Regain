import 'package:flutter/material.dart';

class FocusView extends StatelessWidget {
  const FocusView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: const Center(child: Text('Coming in Phase 7')),
    );
  }
}
