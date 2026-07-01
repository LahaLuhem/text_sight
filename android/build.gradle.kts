import java.util.Properties

group = "com.lahaluhem.text_sight"
version = "1.0-SNAPSHOT"

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

// Bundled vs unbundled ML Kit text recognition is a build-time choice — the Kotlin API is identical,
// so only the artifact (and the app-size / availability trade-off) differs. Default unbundled
// (~260 KB/script, fetched via Google Play Services); a consuming app opts into the bundled model
// (~4 MB/script/arch, in-APK, instant + offline) by setting this in its android/gradle.properties:
//
//     com.lahaluhem.text_sight.useBundled=true
//
// Mirrors mobile_scanner's gradle flag, inverted because our default is unbundled. The value also
// feeds BuildConfig.USE_BUNDLED, so the readiness path can skip Google Play Services when the model
// ships in the APK. A consumer's root gradle.properties propagates here, so findProperty sees it.
val useBundled =
    (project.findProperty("com.lahaluhem.text_sight.useBundled") as? String)?.toBoolean() ?: false

android {
    namespace = "com.lahaluhem.text_sight"

    // Latest STABLE API level, matching Flutter's default (flutter.compileSdkVersion). Deliberately
    // NOT a newer/preview level: AGP bakes this into the AAR as minCompileSdk, forcing every consumer
    // to compile against >= it — and since pub.dev ships this as source, they'd also need that SDK
    // platform installed. A higher value here breaks stock-Flutter consumers (see APPENDIX).
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Library BuildConfig is off by default in AGP 9; enabled for the USE_BUNDLED field below.
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        minSdk = 24

        // Bundled into the AAR and merged into every consuming app's R8 config. Keeps ML
        // Kit's reflectively-resolved classes from being renamed in release builds.
        // without it the recognizer can't initialize and the plugin fails to attach.
        consumerProguardFiles("consumer-rules.pro")

        // Surfaces `useBundled` to Kotlin: the readiness path short-circuits to "ready" (no Play
        // Services round-trip) when the model is statically linked into the APK.
        buildConfigField("boolean", "USE_BUNDLED", useBundled.toString())
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all { testTask ->
                testTask.useJUnitPlatform()

                // Mockito's inline mock-maker loads as a Java agent (self-attach is deprecated on
                // JDK 21+). Point -javaagent at the mockito-core jar already on the resolved test
                // classpath — doFirst defers the lookup to execution time, when it's resolvable.
                testTask.doFirst {
                    val agentJar = testTask.classpath.first { jar -> jar.name.startsWith("mockito-core-") }
                    testTask.jvmArgs("-javaagent:${agentJar.absolutePath}")
                }

                testTask.outputs.upToDateWhen { false }

                testTask.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
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

dependencies {
    // Recognition + camera live ONLY here — never in the Dart pubspec (no-bundling). ML Kit text
    // recognition is bundled or unbundled per `useBundled`: identical Kotlin API, only the artifact
    // and model delivery differ.
    if (useBundled) {
        // Bundled: model statically linked into the APK — instant + offline, ~4 MB/script/arch.
        implementation("com.google.mlkit:text-recognition:16.0.1")
    } else {
        // Unbundled (default): model fetched via Google Play Services, ~260 KB/script/arch.
        implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
    }
    // ModuleInstallClient — the app-controlled fetch + download progress behind
    // TextSightModel.ensureReady(). The readiness code references it regardless of `useBundled`
    // (the bundled path just never calls it), so keep it on the classpath; ML Kit pulls it anyway.
    implementation("com.google.android.gms:play-services-base:18.10.0")

    implementation("androidx.camera:camera-core:1.6.1")
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")

    // Reads still-image EXIF orientation for the one-shot recognizer. Android-only utility (not a
    // recognition lib) — already transitive via CameraX; declared directly since it's used directly.
    implementation("androidx.exifinterface:exifinterface:1.4.2")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    // mockito-core also carries the inline mock-maker agent that testOptions points -javaagent at.
    testImplementation("org.mockito:mockito-core:5.23.0")
    // Real android.graphics.Rect (and friends) on the JVM, so the box-geometry helpers test
    // in place without extracting the arithmetic off Android types.
    testImplementation("org.robolectric:robolectric:4.16.1")
    // mockito-kotlin's whenever/mock DSL over the already-present mockito-core, for stubbing the
    // ML Kit Text/Text.Line value graph that the frame encoder reads.
    testImplementation("org.mockito.kotlin:mockito-kotlin:6.3.0")
    // Robolectric runs under its JUnit 4 runner; the vintage engine executes those tests on the
    // JUnit Platform configured above (useJUnitPlatform).
    testImplementation("junit:junit:4.13.2")
    testRuntimeOnly("org.junit.vintage:junit-vintage-engine:6.1.1")
    // JUnit Platform launcher — required on the test runtime classpath for useJUnitPlatform().
    // The legacy AGP DSL / kotlin-android setup provided it implicitly; AGP 9's new DSL does not.
    testRuntimeOnly("org.junit.platform:junit-platform-launcher:6.1.1")
}

// ── Standalone-only ──────────────────────────────────────────────────────────────────────────────
// Resolves io.flutter.* when this module is opened on its own in Android Studio. `project ==
// rootProject` is true ONLY when android/ is the Gradle root (standalone development); inside an app
// build the plugin is the `:text_sight` subproject and the Flutter Gradle plugin already puts the
// engine on the classpath, so this whole block is skipped — consumers never see it. The engine
// version is read from the pinned Flutter SDK (engine.version maps to Flutter's `1.0.0-<hash>` Maven
// coordinate), so it tracks the SDK automatically instead of being hardcoded.
if (project == rootProject) {
    val localProperties = file("local.properties")
    val flutterSdk: String? =
        if (localProperties.exists()) {
            Properties().apply { localProperties.inputStream().use { load(it) } }.getProperty("flutter.sdk")
        } else {
            null
        }
    val engineVersionFile = flutterSdk?.let { sdk -> file("$sdk/bin/internal/engine.version") }

    if (engineVersionFile != null && engineVersionFile.exists()) {
        val engineVersion = engineVersionFile.readText().trim()
        repositories {
            maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        }
        dependencies {
            compileOnly("io.flutter:flutter_embedding_debug:1.0.0-$engineVersion")
        }
    } else {
        logger.warn(
            "text_sight: set `flutter.sdk` in android/local.properties to resolve io.flutter.* when " +
                "developing this module standalone in Android Studio (not needed for app builds).",
        )
    }
}
