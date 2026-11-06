import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Production signing is explicitly configured; never substitute the debug key.
// Credentials remain in ignored key.properties or the build environment.
val gainpathSigning = Properties().apply {
    val source = rootProject.file("key.properties")
    if (source.isFile) source.inputStream().use { load(it) }
}
fun signingValue(key: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: gainpathSigning.getProperty(key)?.takeIf { it.isNotBlank() }
val productionStore = signingValue("storeFile", "GAINPATH_ANDROID_KEYSTORE_PATH")
val productionAlias = signingValue("keyAlias", "GAINPATH_ANDROID_KEY_ALIAS")
val productionStorePassword = signingValue("storePassword", "GAINPATH_ANDROID_STORE_PASSWORD")
val productionKeyPassword = signingValue("keyPassword", "GAINPATH_ANDROID_KEY_PASSWORD")
val productionSigningReady = productionStore != null &&
    rootProject.file(productionStore).isFile && productionAlias != null &&
    productionStorePassword != null && productionKeyPassword != null
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } &&
    !productionSigningReady) {
    throw GradleException("Production signing is not configured. Supply the approved keystore and credentials; debug signing fallback is disabled.")
}
// Aggregate assemble/build tasks also include release variants. Validate the
// actual task graph, including dry runs, rather than only requested names.
val gainpathAppProject = project
gradle.taskGraph.whenReady {
    if (!productionSigningReady && allTasks.any {
            it.project == gainpathAppProject && it.name.contains("release", ignoreCase = true)
        }) {
        throw GradleException("Production signing is not configured. Aggregate tasks cannot create an unsigned release.")
    }
}

android {
    namespace = "com.zyang.gainpath"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { buildConfig = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.zyang.gainpath"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // tflite_flutter Android runtime requirement
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (productionSigningReady) {
            create("production") {
                storeFile = rootProject.file(productionStore!!)
                keyAlias = productionAlias
                storePassword = productionStorePassword
                keyPassword = productionKeyPassword
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("production")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Same artifacts already supplied by tflite_flutter 0.12.1; no runtime upgrade.
    implementation("com.google.ai.edge.litert:litert:1.4.0")
    implementation("com.google.ai.edge.litert:litert-gpu:1.4.0")
}
