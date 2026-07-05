import 'package:flutter/material.dart';

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

    final accentColor = theme.colorScheme.primary;
    final primaryTextColor = theme.colorScheme.onSurface;
    final dividerColor = theme.colorScheme.outline;

    Color getTextColor() {
      if (variant == CustomButtonVariant.primary) {
        return Colors.white;
      }
      return primaryTextColor;
    }

    final contentColor = getTextColor();

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
              valueColor: AlwaysStoppedAnimation<Color>(contentColor),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: contentColor,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: contentColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    Widget finalButton;

    if (variant == CustomButtonVariant.primary) {
      finalButton = Container(
        width: width,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: accentColor,
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: buttonContent,
            ),
          ),
        ),
      );
    } else if (variant == CustomButtonVariant.secondary) {
      finalButton = SizedBox(
        width: width,
        height: 52,
        child: OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.transparent,
            side: BorderSide(
              color: dividerColor,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: buttonContent,
        ),
      );
    } else {
      finalButton = SizedBox(
        width: width,
        height: 52,
        child: TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: buttonContent,
        ),
      );
    }

    if (isDisabled) {
      return Opacity(
        opacity: 0.4,
        child: finalButton,
      );
    }

    return finalButton;
  }
}
