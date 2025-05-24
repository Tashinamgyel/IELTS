// lib/screens/essay_screen.dart
import 'package:flutter/material.dart';
import '../models/essay.dart';
import '../widgets/essay_view.dart';

class EssayScreen extends StatelessWidget {
  final Essay essay;

  const EssayScreen({super.key, required this.essay});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IELTS Essay'),
        actions: [
          // Bookmark functionality to be implemented.
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bookmark functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: EssayView(essay: essay),
      ),
    );
  }
}
