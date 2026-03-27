part of 'app_cached_image.dart';

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(child: ColoredBox(color: context.skeletonBlockColor));
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: context.colors.onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}
