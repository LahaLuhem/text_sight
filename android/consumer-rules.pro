# Applied to every app that depends on text_sight, so release builds work with no setup.
# Unbundled ML Kit looks its classes up by their original names. R8 renames them, so
# TextRecognition.getClient throws and the plugin never attaches ("detached"). Debug builds don't
# shrink, so only release builds hit it.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.**
