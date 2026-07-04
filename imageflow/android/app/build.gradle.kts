plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.oguzhan.imageflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.oguzhan.imageflow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Keep the TFLite object-detection model uncompressed so MediaPipe can
    // mmap it directly from the APK; compressing it forces a slow copy-to-disk
    // on first load and can break memory-mapped access.
    androidResources {
        noCompress += "tflite"
    }
}

dependencies {
    implementation("org.opencv:opencv:4.13.0")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    // MediaPipe Tasks Vision — EfficientDet-Lite0 object detection (Apache-2.0).
    implementation("com.google.mediapipe:tasks-vision:0.10.14")
}

flutter {
    source = "../.."
}
