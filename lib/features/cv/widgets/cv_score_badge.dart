import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CvScoreBadge extends StatelessWidget {
  final int score;

  const CvScoreBadge({
    super.key,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    if (score >= 80) {
      color = isDark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B);
    } else if (score >= 50) {
      color = isDark ? const Color(0xFFD19A4E) : const Color(0xFFC48A3D);
    } else {
      color = isDark ? const Color(0xFFC5645A) : const Color(0xFFB5544A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        'Score: $score',
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
