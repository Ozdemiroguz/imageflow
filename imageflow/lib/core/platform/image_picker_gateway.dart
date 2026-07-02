/// Picks images from the device gallery, returning plugin-free file paths.
///
/// This is the anti-corruption boundary for `image_picker`: callers depend on
/// this contract and receive plain paths, so no controller imports the plugin
/// and the picker can be mocked in tests. The concrete implementation lives in
/// [image_picker_gateway_impl.dart] so this contract stays plugin-free.
abstract interface class ImagePickerGateway {
  /// Picks a single image from the gallery. Returns its file path, or null if
  /// the user cancelled.
  Future<String?> pickImageFromGallery({int imageQuality = 90});

  /// Picks multiple images from the gallery. Returns their file paths (empty if
  /// the user cancelled).
  Future<List<String>> pickMultipleFromGallery({int imageQuality = 90});
}
