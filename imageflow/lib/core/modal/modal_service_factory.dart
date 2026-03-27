import '../services/modal_service.dart';
import 'app_modal_content_builder.dart';

class ModalServiceFactory {
  const ModalServiceFactory._();

  static ModalService create() {
    return ModalService(contentBuilder: const AppModalContentBuilder());
  }
}
