part of 'pdf_raster_service.dart';

typedef PdfRasterizer =
    Future<List<Uint8List>> Function(Uint8List pdfBytes, double dpi);
