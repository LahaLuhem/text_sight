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

// Unbundled ML Kit by default (~260 KB/script via Play Services). A consuming app opts into the
// bundled model (~4 MB/script/arch, in-APK, offline) from its own android/gradle.properties:
//
//     com.lahaluhem.text_sight.useBundled=true
//
// Also feeds BuildConfig.USE_BUNDLED. Trade-off: APPENDIX.md#model-readiness
val useBundled =
    (project.findProperty("com.lahaluhem.text_sight.useBundled") as? String)?.toBoolean() ?: false

android {
    namespace = "com.lahaluhem.text_sight"

    // Latest stable, matching flutter.compileSdkVersion. AGP bakes it into the AAR as every
    // consumer's minCompileSdk, so a preview level breaks stock Flutter apps (see APPENDIX).
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Off by default in AGP 9, and USE_BUNDLED below needs it.
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        minSdk = 24

        // Merged into every app's R8 config, so release builds keep the ML Kit classes it looks up
        // by name. Without them the plugin fails to attach.
        consumerProguardFiles("consumer-rules.pro")

        // Lets readiness answer "ready" straight away when the model ships inside the APK.
        buildConfigField("boolean", "USE_BUNDLED", useBundled.toString())
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all { testTask ->
                testTask.useJUnitPlatform()

                // Mockito loads as a Java agent, since JDK 21+ deprecates self-attach. In doFirst,
                // because the test classpath only resolves when the task runs.
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
    // Recognition and camera libs live only here, never in the Dart pubspec (no-bundling). Both ML
    // Kit artifacts share one Kotlin API.
    if (useBundled) {
        implementation("com.google.mlkit:text-recognition:16.0.1")
    } else {
        implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.2")
    }
    // ModuleInstallClient, behind TextSightModel.ensureReady(). Readiness code names it even when
    // bundled, so it stays on the classpath.
    implementation("com.google.android.gms:play-services-base:18.11.1")

    implementation("androidx.camera:camera-core:1.6.1")
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")

    // Cuts the box out of camera frames for ML Kit, which has no region setting.
    implementation("io.github.crow-misia.libyuv:libyuv-android:0.44.0")

    // EXIF orientation for one-shot stills. Comes with CameraX, declared since we use it.
    implementation("androidx.exifinterface:exifinterface:1.4.2")

    // Foreground/background signal for the session owner. An atomic group, so it lifts every
    // androidx.lifecycle artifact a consumer resolves to this version.
    implementation("androidx.lifecycle:lifecycle-process:2.11.0")

    // Await.kt's suspend bridges. Comes with CameraX, declared since we use it.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    // runTest and the cancellation checks for Await.kt.
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
    // ResolvableFuture, a ListenableFuture the Await.kt tests can settle by hand.
    testImplementation("androidx.concurrent:concurrent-futures:1.1.0")
    // Also the jar testOptions loads as the Java agent.
    testImplementation("org.mockito:mockito-core:5.24.0")
    // Real android.graphics types on the JVM, so the geometry tests use them as they are.
    testImplementation("org.robolectric:robolectric:4.18")
    // Kotlin-friendly mock/whenever, for ML Kit's Text graph and the camera's image planes.
    testImplementation("org.mockito.kotlin:mockito-kotlin:6.4.0")
    // Robolectric's runner is JUnit 4, and the vintage engine runs it on the JUnit Platform.
    testImplementation("junit:junit:4.13.2")
    testRuntimeOnly("org.junit.vintage:junit-vintage-engine:6.1.3")
    // useJUnitPlatform() needs the launcher, which AGP 9's DSL no longer brings along.
    testRuntimeOnly("org.junit.platform:junit-platform-launcher:6.1.3")
}

// ── Standalone-only ──────────────────────────────────────────────────────────────────────────────
// Resolves io.flutter.* when android/ is the Gradle root, which only happens in standalone
// development. An app build skips the whole block, so consumers never see it.
// APPENDIX.md#android-standalone-dev
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
        val engineDependency = "io.flutter:flutter_embedding_debug:1.0.0-$engineVersion"
        dependencies {
            compileOnly(engineDependency)
            // `compileOnly` covers the main source set only, so the unit tests need their own.
            testImplementation(engineDependency)
        }
    } else {
        logger.warn(
            "text_sight: set `flutter.sdk` in android/local.properties to resolve io.flutter.* when " +
                "developing this module standalone in Android Studio (not needed for app builds).",
        )
    }
}
