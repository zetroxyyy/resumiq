import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProBadge extends StatelessWidget {
  final double fontSize;
  final EdgeInsets padding;

  const ProBadge({
    super.key,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'PRO',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
