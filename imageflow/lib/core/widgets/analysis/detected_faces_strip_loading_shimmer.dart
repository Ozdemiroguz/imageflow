part of 'detected_faces_strip.dart';

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer({required this.maxItems});

  static const double _tileWidth = 54;
  static const double _tileHeight = 72;

  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tileCount = math.min(maxItems, 4);
    if (tileCount <= 0) return const SizedBox.shrink();

    return AppShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tileCount,
        separatorBuilder: (context, index) => SizedBox(width: tokens.spacingXs),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: ColoredBox(
            color: context.skeletonBlockColor,
            child: const SizedBox(width: _tileWidth, height: _tileHeight),
          ),
        ),
      ),
    );
  }
}
