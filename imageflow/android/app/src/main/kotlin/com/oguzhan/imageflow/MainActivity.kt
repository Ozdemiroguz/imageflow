package com.oguzhan.imageflow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(CornerDetectionHandler())
        flutterEngine.plugins.add(PdfExternalOpenHandler())
        flutterEngine.plugins.add(PdfRasterizeHandler())
    }
}
