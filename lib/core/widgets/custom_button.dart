import 'package:flutter/material.dart';
import '../../app/theme.dart';

enum CustomButtonVariant { primary, secondary, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onPressed == null || isLoading;

    Widget buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == CustomButtonVariant.primary
                    ? Colors.white
                    : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: variant == CustomButtonVariant.primary
                ? Colors.white
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: variant == CustomButtonVariant.primary
                ? Colors.white
                : (isDisabled ? theme.disabledColor : theme.colorScheme.primary),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    if (variant == CustomButtonVariant.primary) {
      return Container(
        width: width,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isDisabled
              ? null
              : const LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    Color(0xFF8B84FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isDisabled ? theme.disabledColor.withOpacity(0.12) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: buttonContent,
            ),
          ),
        ),
      );
    } else if (variant == CustomButtonVariant.secondary) {
      return SizedBox(
        width: width,
        height: 52,
        child: OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isDisabled
                  ? theme.disabledColor.withOpacity(0.12)
                  : theme.colorScheme.primary,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: buttonContent,
        ),
      );
    } else {
      return SizedBox(
        width: width,
        height: 52,
        child: TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: buttonContent,
        ),
      );
    }
  }
}
