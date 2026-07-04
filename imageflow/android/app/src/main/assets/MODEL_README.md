# Object detection model (Android)

`ObjectDetectionHandler` expects an EfficientDet-Lite0 TFLite model at:

    android/app/src/main/assets/efficientdet_lite0.tflite

It is **not committed** (≈4.5 MB binary). Download it from MediaPipe's model
gallery (Apache-2.0, COCO-80 labels):

    curl -L -o android/app/src/main/assets/efficientdet_lite0.tflite \
      https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/int8/1/efficientdet_lite0.tflite

Until the file is present the handler degrades gracefully: every call returns
"no objects" (empty list) and the rest of the app is unaffected.

Model source: https://ai.google.dev/edge/mediapipe/solutions/vision/object_detector
