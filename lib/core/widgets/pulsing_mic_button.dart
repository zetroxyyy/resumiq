import 'package:flutter/material.dart';

class PulsingMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback? onTap;

  const PulsingMicButton({
    super.key,
    required this.isListening,
    this.onTap,
  });

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.isListening ? 1.0 + (_controller.value * 0.2) : 1.0;
        final color = widget.isListening
            ? Color.lerp(theme.colorScheme.primary, theme.colorScheme.primaryContainer, _controller.value)
            : theme.colorScheme.onSurface.withOpacity(0.08);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: widget.isListening
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: _controller.value * 4,
                      )
                    ]
                  : null,
            ),
            child: IconButton(
              icon: Icon(
                widget.isListening ? Icons.mic_none : Icons.mic_none_outlined,
                color: widget.isListening ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
              onPressed: widget.onTap,
            ),
          ),
        );
      },
    );
  }
}

class ListeningLabel extends StatefulWidget {
  const ListeningLabel({super.key});

  @override
  State<ListeningLabel> createState() => _ListeningLabelState();
}

class _ListeningLabelState extends State<ListeningLabel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotsCount = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        final newDots = ((_controller.value * 3).floor() % 3) + 1;
        if (newDots != _dotsCount) {
          setState(() {
            _dotsCount = newDots;
          });
        }
      })..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dots = '.' * _dotsCount;
    return Text(
      'Listening$dots',
      style: TextStyle(
        color: theme.colorScheme.secondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
