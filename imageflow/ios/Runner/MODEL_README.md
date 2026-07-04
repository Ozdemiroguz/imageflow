# Object detection model (iOS)

`ObjectDetectionHandler` loads a Core ML detector named **`ObjectDetector`** that
emits `VNRecognizedObjectObservation` boxes. Add it to the Xcode project (target
membership: Runner) as either:

    ios/Runner/ObjectDetector.mlmodel     (Xcode compiles it to .mlmodelc)

or a precompiled `ObjectDetector.mlmodelc`. It is **not committed** (binary).

Use an Apple-gallery object detector with a **non-viral** license — e.g.:

  - **YOLOv3-Tiny** — https://developer.apple.com/machine-learning/models/
  - **MobileNetV2-SSDLite**

Do NOT use Ultralytics YOLOv8/YOLO11 exports: they are **AGPL-3.0** (viral) and
unsuitable for a distributable app without a commercial license.

After downloading, rename the model file to `ObjectDetector.mlmodel` (or set
`modelName` in `ObjectDetectionHandler.swift`) and drag it into the Runner
target in Xcode.

Until the model is present the handler degrades gracefully: every call returns
"no objects" and the rest of the app is unaffected.
