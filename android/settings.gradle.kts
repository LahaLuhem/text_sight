// Read ONLY when android/ is opened as its own Gradle build. In an app build Flutter includes the
// plugin as a subproject and this file is ignored, so the AGP version below is the standalone
// baseline and never reaches a consumer. APPENDIX.md#android-standalone-dev
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    plugins {
        id("com.android.library") version "9.4.0"
    }
}

rootProject.name = "text_sight"
