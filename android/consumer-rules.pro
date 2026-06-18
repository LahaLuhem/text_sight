# Consumer R8/ProGuard rules — bundled into the AAR and applied automatically to any
# app that depends on text_sight, so its release builds work with no setup downstream.
#
# Why: the unbundled ML Kit Text Recognition (play-services) resolves its internal
# components reflectively by their *original* class names (via the ML Kit component
# registry / manifest meta-data). In a release build R8 renames those classes, the
# reflective lookup returns null, and TextRecognition.getClient(...) throws a
# NullPointerException inside the recognizer internals
# (com.google.mlkit.vision.text.internal.zz*) — which surfaces as the plugin failing to
# attach to the engine ("detached"). Keeping the ML Kit classes by their original names
# fixes it. (Debug builds don't shrink, so this only bites in release.)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.**
