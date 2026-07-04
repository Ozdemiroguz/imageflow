# ML Kit Text Recognition — Latin only, other scripts not included in this build
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# MediaPipe Tasks (object detection) pulls in AutoValue, whose generated code
# references compile-time-only javax.lang.model.* APIs that don't exist on
# Android. They are never used at runtime, so silence the R8 missing-class error.
-dontwarn javax.lang.model.**
-dontwarn autovalue.shaded.**
-dontwarn com.google.auto.value.**

# Keep MediaPipe Tasks classes — loaded reflectively through JNI.
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# MediaPipe's Graph.<clinit> walks the call stack to identify its initializer
# (com.google.mediapipe.framework.Graph -> "no caller found on the stack for").
# R8 renames AND optimizes/inlines the frames it walks, so a plain -keep is not
# enough — the class must also keep its ORIGINAL NAME and not be optimized away.
# Disable optimization on the whole MediaPipe package so the call stack it
# inspects stays intact at runtime.
-keepnames class com.google.mediapipe.** { *; }
-keep,allowshrinking,includedescriptorclasses class com.google.mediapipe.framework.** { *; }
-optimizations !method/inlining/*
# Keep our own native handlers un-renamed so MediaPipe finds a valid caller
# frame when it walks the stack from ObjectDetectionHandler.buildDetector.
-keep class com.oguzhan.imageflow.** { *; }
-keepnames class com.oguzhan.imageflow.** { *; }
# Google Protobuf/Flatbuffers (MediaPipe serialization) are reflection/field
# sensitive; keep them intact.
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
-keep class com.google.flatbuffers.** { *; }
-dontwarn com.google.flatbuffers.**
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
