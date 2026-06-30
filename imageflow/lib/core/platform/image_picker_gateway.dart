import 'package:image_picker/image_picker.dart';

/// Picks images from the device gallery, returning plugin-free file paths.
///
/// This is the anti-corruption boundary for `image_picker`: callers depend on
/// this contract and receive plain paths, so no controller imports the plugin
/// and the picker can be mocked in tests.
abstract interface class ImagePickerGateway {
  /// Picks a single image from the gallery. Returns its file path, or null if
  /// the user cancelled.
  Future<String?> pickImageFromGallery({int imageQuality = 90});

  /// Picks multiple images from the gallery. Returns their file paths (empty if
  /// the user cancelled).
  Future<List<String>> pickMultipleFromGallery({int imageQuality = 90});
}

/// [ImagePickerGateway] backed by the `image_picker` plugin.
class ImagePickerGatewayImpl implements ImagePickerGateway {
  ImagePickerGatewayImpl({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImageFromGallery({int imageQuality = 90}) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
    return image?.path;
  }

  @override
  Future<List<String>> pickMultipleFromGallery({int imageQuality = 90}) async {
    final images = await _picker.pickMultiImage(imageQuality: imageQuality);
    return images.map((image) => image.path).toList(growable: false);
  }
}
