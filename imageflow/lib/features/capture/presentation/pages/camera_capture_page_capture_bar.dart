part of 'camera_capture_page.dart';

class _CaptureBar extends StatelessWidget {
  const _CaptureBar({required this.controller});

  final CameraCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tokens.spacingLg,
        tokens.spacingMd,
        tokens.spacingLg,
        tokens.spacingXl + MediaQuery.paddingOf(context).bottom,
      ),
      color: Colors.black.withValues(alpha: 0.84),
      child: Obx(
        () => Center(
          child: SizedBox(
            width: 84,
            height: 84,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacingSm),
                child: Material(
                  color: controller.isCapturing.value
                      ? Colors.white38
                      : Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: controller.isCapturing.value
                        ? null
                        : controller.capture,
                    child: controller.isCapturing.value
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

