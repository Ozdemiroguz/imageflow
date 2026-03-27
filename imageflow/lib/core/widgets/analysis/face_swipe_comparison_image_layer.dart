part of 'face_swipe_comparison.dart';

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({required this.path, required this.cacheWidth});

  final String path;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surface.withValues(alpha: 0.18),
      child: AppCachedImage(
        imagePath: path,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        placeholder: ColoredBox(color: context.skeletonBlockColor),
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          color: context.colors.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
