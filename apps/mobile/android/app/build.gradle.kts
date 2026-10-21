import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material is optional and never committed: copy
// android/key.properties.example to android/key.properties (gitignored) and fill it in.
// When the file is absent (CI, fresh clone, local debug work) the release build falls back
// to the debug keystore so `flutter build apk --release` / `flutter run --release` keep
// working locally — such an APK is NOT distributable.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties =
    Properties().apply {
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }

fun requiredKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException(
            "android/key.properties exists but is missing `$name`. " +
                "See android/key.properties.example for the four required keys.",
        )

val releaseSigningAvailable = keystorePropertiesFile.exists()

/** True when this invocation actually asks for a release task: keeps the fallback warning off debug builds. */
val buildingRelease =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

android {
    namespace = "edu.profesorgo.profesor_go"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "edu.profesorgo.profesor_go"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // API 24 (flutter.minSdkVersion in Flutter 3.47). The nfc_manager and geolocator_android
        // plugin modules are built at that same floor, so a lower value here is silently raised to
        // 24 in the merged manifest anyway. Keep it in sync with Flutter instead of hardcoding it.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningAvailable) {
            create("release") {
                val storeFilePath = requiredKeystoreProperty("storeFile")
                storeFile =
                    File(storeFilePath).let { candidate ->
                        if (candidate.isAbsolute) candidate else rootProject.file(storeFilePath)
                    }
                storePassword = requiredKeystoreProperty("storePassword")
                keyAlias = requiredKeystoreProperty("keyAlias")
                keyPassword = requiredKeystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningAvailable) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // TODO_EXTERNAL: a store-ready release needs an upload keystore that only the
                // university can create and hold: the .jks/.keystore file plus its store password,
                // key alias and key password, written into android/key.properties
                // (see android/key.properties.example). Until that exists the release build is
                // signed with the shared debug keystore: fine for local testing and sideloading,
                // rejected by Play and not safe to distribute.
                signingConfig = signingConfigs.getByName("debug")
                if (buildingRelease) {
                    // `flutter build` runs Gradle with -q, which hides WARN and LIFECYCLE:
                    // QUIET is the only level that still reaches the flutter output.
                    logger.quiet(
                        "Profesor GO: android/key.properties not found -> release APK signed with the " +
                            "DEBUG keystore. Local/sideload only, Play will reject it. " +
                            "See android/key.properties.example.",
                    )
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
