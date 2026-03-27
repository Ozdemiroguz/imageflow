part of 'gradient_fab.dart';

class _QuickActionFab extends StatelessWidget {
  const _QuickActionFab({
    required this.heroTag,
    required this.onPressed,
    required this.gradient,
    required this.icon,
    required this.tooltip,
    this.hasBonusBadge = false,
  });

  final String heroTag;
  final VoidCallback onPressed;
  final Gradient gradient;
  final IconData icon;
  final String tooltip;
  final bool hasBonusBadge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
              ),
              child: FloatingActionButton(
                heroTag: heroTag,
                onPressed: onPressed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                tooltip: tooltip,
                child: Icon(icon),
              ),
            ),
          ),
          if (hasBonusBadge)
            Positioned(
              right: 0,
              child: Icon(
                Icons.star_rounded,
                size: 18,
                color: context.tokens.bonusYellow,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
              ),
            ),
        ],
      ),
    );
  }
}
