import 'package:camera/camera.dart';

import '../utils/log.dart';

class CameraSessionService {
  static const _tag = 'CameraSession';

  CameraController? _controller;
  CameraDescription? _description;
  final _availableCameras = <CameraDescription>[];
  Future<void> Function(CameraImage image)? _onStreamFrame;
  var _isStreamFrameBusy = false;

  CameraController? get controller => _controller;
  CameraDescription? get description => _description;
  List<CameraDescription> get cameras => List.unmodifiable(_availableCameras);
  bool get canSwitchCamera => _availableCameras.length > 1;

  Future<void> initializeAndActivatePreferred({
    required ResolutionPreset resolutionPreset,
    required ImageFormatGroup imageFormatGroup,
    bool enableAudio = false,
  }) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no-camera', 'No camera found on this device.');
    }

    _availableCameras
      ..clear()
      ..addAll(cameras);

    final initial = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    await activateCamera(
      initial,
      resolutionPreset: resolutionPreset,
      imageFormatGroup: imageFormatGroup,
      enableAudio: enableAudio,
    );
  }

  Future<void> activateCamera(
    CameraDescription camera, {
    required ResolutionPreset resolutionPreset,
    required ImageFormatGroup imageFormatGroup,
    bool enableAudio = false,
  }) async {
    final controller = CameraController(
      camera,
      resolutionPreset,
      enableAudio: enableAudio,
      imageFormatGroup: imageFormatGroup,
    );
    await controller.initialize();
    _description = camera;
    _controller = controller;
  }

  CameraDescription? resolveNextCamera() {
    final current = _description;
    if (current == null || _availableCameras.isEmpty) return null;

    final targetDirection = current.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final opposite = _availableCameras.where(
      (c) => c.lensDirection == targetDirection,
    );
    if (opposite.isNotEmpty) return opposite.first;

    final currentIndex = _availableCameras.indexWhere(
      (c) => c.name == current.name && c.lensDirection == current.lensDirection,
    );
    if (currentIndex < 0) return _availableCameras.first;
    return _availableCameras[(currentIndex + 1) % _availableCameras.length];
  }

  Future<bool> startImageStream(
    Future<void> Function(CameraImage image) onFrame,
  ) async {
    final cam = _controller;
    if (cam == null ||
        !cam.value.isInitialized ||
        cam.value.isStreamingImages) {
      return false;
    }

    _onStreamFrame = onFrame;
    _isStreamFrameBusy = false;

    await cam.startImageStream((image) async {
      final handler = _onStreamFrame;
      if (handler == null || _isStreamFrameBusy) return;
      _isStreamFrameBusy = true;
      try {
        await handler(image);
      } catch (e, st) {
        Log.error(
          'Image stream frame handler failed',
          error: e,
          stackTrace: st,
          tag: _tag,
        );
      } finally {
        _isStreamFrameBusy = false;
      }
    });
    return true;
  }

  Future<void> stopImageStream() async {
    _onStreamFrame = null;

    final cam = _controller;
    if (cam == null ||
        !cam.value.isInitialized ||
        !cam.value.isStreamingImages) {
      _isStreamFrameBusy = false;
      return;
    }

    try {
      await cam.stopImageStream();
    } on CameraException catch (e) {
      Log.warning(
        'stopImageStream camera exception: ${e.description}',
        tag: _tag,
      );
    } catch (e) {
      Log.warning('stopImageStream failed: $e', tag: _tag);
    } finally {
      _isStreamFrameBusy = false;
    }
  }

  /// Avoids disposing a controller while CameraPreview still uses it.
  /// We first drop the reference, yield one microtask, then dispose.
  Future<void> disposeControllerSafely() async {
    final oldController = _controller;
    if (oldController == null) return;

    _controller = null;
    _isStreamFrameBusy = false;
    await Future<void>.delayed(Duration.zero);

    try {
      await oldController.dispose();
    } on CameraException catch (e) {
      Log.warning('Camera dispose warning: ${e.description}', tag: _tag);
    } catch (e) {
      Log.warning('Camera dispose warning: $e', tag: _tag);
    }
  }
}
