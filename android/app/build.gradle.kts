plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
=======
=======
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
=======
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
=======
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
}

android {
    namespace = "com.trumos.lagja"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.trumos.lagja"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
=======
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
=======
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
        }
    }
    buildTypes {
        release {
<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
<<<<<<< C:/projects/Lagja/android/app/build.gradle.kts
            signingConfig signingConfigs.release
=======
            signingConfig = signingConfigs.getByName("release")
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
=======
            signingConfig = signingConfigs.getByName("release")
>>>>>>> C:/Users/Windows 11/.windsurf/worktrees/Lagja/Lagja-91fd7245/android/app/build.gradle.kts
        }
    }
}

flutter {
    source = "../.."
}
