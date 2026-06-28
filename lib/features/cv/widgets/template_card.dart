import 'package:flutter/material.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Template Card Placeholder'),
      ),
    );
  }
}
