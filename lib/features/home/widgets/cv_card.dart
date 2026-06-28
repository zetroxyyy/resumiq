import 'package:flutter/material.dart';

class CvCard extends StatelessWidget {
  const CvCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('CV Card Placeholder'),
      ),
    );
  }
}
