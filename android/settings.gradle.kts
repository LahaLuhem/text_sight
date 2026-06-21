// This settings file is read ONLY when android/ is opened as its own Gradle build — i.e. developing
// the Android module directly in Android Studio (File > Open > android/). When an app consumes the
// plugin, Flutter pulls it in via `include(":text_sight")` (FlutterAppPluginLoaderPlugin) and a
// subproject's settings file is ignored: the host app supplies the AGP version. So the version below
// is the standalone-development baseline only — it never reaches a consumer. (AGP 9's built-in Kotlin
// handles Kotlin compilation, so no kotlin.android plugin is declared.)
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    plugins {
        id("com.android.library") version "9.2.1"
    }
}

rootProject.name = "text_sight"
