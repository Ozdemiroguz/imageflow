import 'package:image_picker/image_picker.dart';

import 'image_picker_gateway.dart';

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
