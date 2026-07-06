import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../controllers/corner_adjust_controller.dart';
import '../widgets/draggable_corner_overlay.dart';

/// Lets the user confirm or drag the detected document corners before the image
/// is cropped. See [CornerAdjustController].
class CornerAdjustPage extends GetView<CornerAdjustController> {
  const CornerAdjustPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust corners'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: Get.back,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isDetecting.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final corners = controller.corners.value;
          if (corners == null) {
            // Detection found nothing; the controller already navigates onward.
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacingLg),
                  child: _ImageWithCorners(imagePath: controller.imagePath),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacingLg,
                  0,
                  tokens.spacingLg,
                  tokens.spacingLg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controller.useAutomatic,
                        child: const Text('Auto'),
                      ),
                    ),
                    SizedBox(width: tokens.spacingMd),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: controller.confirm,
                        icon: const Icon(Icons.check),
                        label: const Text('Use these corners'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Displays the image at its natural aspect ratio and overlays the draggable
/// corners in the SAME coordinate space via a `FittedBox → SizedBox(imageSize)`
/// wrapper, so normalized corners map straight to pixels with no letterbox math.
class _ImageWithCorners extends StatefulWidget {
  const _ImageWithCorners({required this.imagePath});
  final String imagePath;

  @override
  State<_ImageWithCorners> createState() => _ImageWithCornersState();
}

class _ImageWithCornersState extends State<_ImageWithCorners> {
  final _controller = Get.find<CornerAdjustController>();
  Size? _imageSize;
  late final ImageProvider _provider;
  ImageStreamListener? _listener;
  ImageStream? _stream;

  @override
  void initState() {
    super.initState();
    _provider = FileImage(File(widget.imagePath));
    _resolveImageSize();
  }

  void _resolveImageSize() {
    _stream = _provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    if (size == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(image: _provider, fit: BoxFit.fill),
              Obx(() {
                final corners = _controller.corners.value;
                if (corners == null) return const SizedBox.shrink();
                return DraggableCornerOverlay(
                  corners: corners,
                  onCornerMoved: _controller.moveCorner,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
