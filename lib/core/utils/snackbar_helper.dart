import 'package:flutter/material.dart';

enum SnackType { info, success, warning, error }

void showAppSnackBar(BuildContext context, String message, 
    {SnackType type = SnackType.info}) {
  final theme = Theme.of(context);
  Color bg;
  switch (type) {
    case SnackType.success: bg = const Color(0xFF4C9A6B); break;
    case SnackType.warning: bg = const Color(0xFFC48A3D); break;
    case SnackType.error: bg = const Color(0xFFB5544A); break;
    default: bg = theme.colorScheme.surface;
  }
  
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}
