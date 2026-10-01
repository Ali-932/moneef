plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.moneef.mobile_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "io.moneef.mobile_app"
        // gomobile AAR requires API 21+
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystore = providers.environmentVariable("MONEEF_KEYSTORE").orNull
    if (keystore != null) {
        signingConfigs.create("release") {
            storeFile = file(keystore)
            storePassword = providers.environmentVariable("MONEEF_KEYSTORE_PASSWORD").get()
            keyAlias = "moneef"
            keyPassword = storePassword // keytool's PKCS12 keystores use one password
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (keystore != null) "release" else "debug")
        }
    }
}

// Gomobile-bound Go core. Drop new builds into `app/libs/moneef.aar`
// and re-run the Flutter build to pick up the new symbols.
dependencies {
    implementation(files("libs/moneef.aar"))
}

flutter {
    source = "../.."
}
