group = "com.LahaLuhem.text_sight"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

// Mockito's inline mock-maker has to load as a Java agent: self-attaching is deprecated on JDK 21+
// and removed in a future JDK. This isolated configuration resolves to just the mockito-core jar,
// handed to the unit-test JVM via -javaagent in testOptions below.
val mockitoAgent: Configuration = configurations.create("mockitoAgent")

android {
    namespace = "com.LahaLuhem.text_sight"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24

        // Bundled into the AAR and merged into every consuming app's R8 config. Keeps ML
        // Kit's reflectively-resolved classes from being renamed in release builds.
        // without it the recognizer can't initialize and the plugin fails to attach.
        consumerProguardFiles("consumer-rules.pro")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()
                it.jvmArgs("-javaagent:${mockitoAgent.asPath}")

                it.outputs.upToDateWhen { false }

                it.testLogging {
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
    // Recognition + camera live ONLY here — never in the Dart pubspec (no-bundling).
    // Unbundled ML Kit: model downloads via Google Play Services on first use.
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
    implementation("androidx.camera:camera-core:1.6.1")
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")

    // Reads still-image EXIF orientation for the one-shot recognizer. Android-only utility (not a
    // recognition lib) — already transitive via CameraX; declared directly since it's used directly.
    implementation("androidx.exifinterface:exifinterface:1.4.2")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.18.0")
    // Real android.graphics.Rect (and friends) on the JVM, so the box-geometry helpers test
    // in place without extracting the arithmetic off Android types.
    testImplementation("org.robolectric:robolectric:4.15.1")
    // mockito-kotlin's whenever/mock DSL over the already-present mockito-core, for stubbing the
    // ML Kit Text/Text.Line value graph that the frame encoder reads.
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.4.0")
    // Robolectric runs under its JUnit 4 runner; the vintage engine executes those tests on the
    // JUnit Platform configured above (useJUnitPlatform).
    testImplementation("junit:junit:4.13.2")
    testRuntimeOnly("org.junit.vintage:junit-vintage-engine:5.12.2")
    "mockitoAgent"("org.mockito:mockito-core:5.18.0") { isTransitive = false }
}
