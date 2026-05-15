plugins {
    id("com.android.application")
    id("kotlin-android")

    // Flutter plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {

    namespace = "com.example.frontend"

    // FIXED SDK VERSION
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {

        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {

        applicationId = "com.example.frontend"

        // REQUIRED FOR YOUR PACKAGES
        minSdk = flutter.minSdkVersion

        // FIXED TARGET SDK
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {

        release {

            // TEMP DEBUG SIGNING
            // Production keystore can be added later
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {

    source = "../.."
}
