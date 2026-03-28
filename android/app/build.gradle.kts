plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.face_track"
    compileSdk = 36                         // ← explicit instead of flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"             // ← FIXED: override flutter.ndkVersion (was downloading broken NDK 28)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.face_track"
        minSdk = flutter.minSdkVersion                          // ← explicit instead of flutter.minSdkVersion
        targetSdk = 34                       // ← explicit instead of flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
