part of 'failures.dart';

final class PdfFailure extends Failure {
  const PdfFailure([super.message = 'PDF operation failed'])
      : super(code: 'PDF_ERROR');
}
