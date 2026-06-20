// This settings file is read ONLY when android/ is opened as its own Gradle build — i.e. developing
// the Android module directly in Android Studio (File > Open > android/). When an app consumes the
// plugin, Flutter pulls it in via `include(":text_sight")` (FlutterAppPluginLoaderPlugin) and a
// subproject's settings file is ignored: the host app supplies the AGP/Kotlin plugin versions. So
// the versions below are the standalone-development baseline only — they never reach a consumer.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    plugins {
        id("com.android.library") version "9.0.1"
        id("org.jetbrains.kotlin.android") version "2.3.20"
    }
}

rootProject.name = "text_sight"
