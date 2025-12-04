# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Biometric Authentication - COMPREHENSIVE
-keep class androidx.biometric.** { *; }
-keep interface androidx.biometric.** { *; }
-keep class androidx.biometric.BiometricPrompt { *; }
-keep class androidx.biometric.BiometricPrompt$* { *; }
-keep class androidx.biometric.BiometricManager { *; }
-keep class androidx.fragment.app.** { *; }
-keep class androidx.core.hardware.fingerprint.** { *; }

# Local Auth Plugin - COMPLETE
-keep class io.flutter.plugins.localauth.** { *; }
-keep interface io.flutter.plugins.localauth.** { *; }
-keepclassmembers class io.flutter.plugins.localauth.** { *; }
-dontwarn io.flutter.plugins.localauth.**

# Android Biometric API
-keep class android.hardware.biometrics.** { *; }
-dontwarn android.hardware.biometrics.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# AndroidX Security
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Fingerprint Manager
-keep class android.hardware.fingerprint.** { *; }
-dontwarn android.hardware.fingerprint.**

# Keep Kotlin Metadata
-keep class kotlin.Metadata { *; }

# Don't obfuscate biometric classes
-keepnames class * extends androidx.biometric.BiometricPrompt
-keepnames class * extends androidx.biometric.BiometricPrompt$AuthenticationCallback
-keepnames class * implements androidx.biometric.BiometricPrompt$AuthenticationCallback

# Keep all callback methods
-keepclassmembers class * extends androidx.biometric.BiometricPrompt$AuthenticationCallback {
    *;
}

# Keep FragmentActivity for BiometricPrompt
-keep class androidx.fragment.app.FragmentActivity { *; }
-keep class androidx.appcompat.app.AppCompatActivity { *; }

# Preserve line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# Keep generic signature of Call, Response (R8 full mode strips signatures from non-kept items)
-keepattributes Signature

# Keep Annotations
-keepattributes *Annotation*

# Encryption
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Google Play Core (for Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep Google Play Core classes
-keep class com.google.android.play.core.** { *; }

# Keep all deferred component related classes
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Method Channels (for plugin communication)
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.MethodChannel$* { *; }
-keep class io.flutter.plugin.common.** { *; }

# Platform Views
-keep class io.flutter.plugin.platform.** { *; }

# Keep all native methods (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep plugin registrants
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Disable optimization that might break biometric
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify
