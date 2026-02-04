######## Flutter core ########
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.plugin.common.** { *; }

######## Main Activity ########
# استبدل com.example.app بالـ package name الفعلي من AndroidManifest.xml
-keep class com.yournewname.athkarak.MainActivity { *; }

######## Reflection-sensitive libs (حسب شيوعها) ########
# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.ads.formats.** { *; }
-keep class com.google.android.gms.ads.mediation.** { *; }
-keep class com.google.android.gms.ads.nativead.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google Fonts
-keep class com.google.android.gms.fonts.** { *; }
-dontwarn com.google.android.gms.fonts.**

# Hive Database
-keep class io.flutter.plugins.hive.** { *; }
-keep class io.fluttercommunity.plus.hive.** { *; }
-keep class com.github.fondue.game.** { *; }
-dontwarn com.github.fondue.game.**

# Audio Service and Players
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.schedules.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Android Alarm Manager Plus
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }
-dontwarn dev.fluttercommunity.plus.androidalarmmanager.**

# Location Services (Geolocator & Geocoding)
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }
-dontwarn com.baseflow.geolocator.**
-dontwarn com.baseflow.geocoding.**

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Connectivity Plus
-keep class com.fluttercommunity.plus.connectivity.** { *; }
-dontwarn com.fluttercommunity.plus.connectivity.**

# Share Plus
-keep class com.fluttercommunity.plus.share.** { *; }
-dontwarn com.fluttercommunity.plus.share.**

# URL Launcher
-keep class com.fluttercommunity.plus.url_launcher.** { *; }
-dontwarn com.fluttercommunity.plus.url_launcher.**

# Permission Handler
-dontwarn android.app.NotificationManager
-dontwarn android.app.NotificationChannel

# Google Play Services (تحذيرات عامة)
-dontwarn com.google.android.gms.**

# Gson (إذا وُجد)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.stream.** { *; }
-keepattributes *Annotation*, Signature
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Retrofit/OkHttp (إذا وُجد)
-dontwarn okio.**
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }
-keepattributes Exceptions

# Kotlin coroutines (تحذيرات فقط)
-dontwarn kotlinx.coroutines.**

# Play Services (تحذيرات عامة)
-dontwarn com.google.android.gms.**

######## موارد XML keep لأسماء الموارد المستخدمة عبر انعكاس ########
# أضف keep للأسماء التي تُستدعى بالاسم إن وُجدت.

######## Additional Rules for Common Issues ########
# Keep Firebase Analytics
-keep class com.google.firebase.analytics.** { *; }
-dontwarn com.google.firebase.analytics.**

# Keep Firebase Messaging (if used)
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

# Keep Firebase Remote Config (if used)
-keep class com.google.firebase.remoteconfig.** { *; }
-dontwarn com.google.firebase.remoteconfig.**

# Keep Firebase Crashlytics (if used)
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

######## TensorFlow Lite (إذا وُجد) ########
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-dontwarn org.tensorflow.lite.**

######## Universal Image Loader (إذا وُجد) ########
-keep class com.nostra13.universalimageloader.** { *; }
-dontwarn com.nostra13.universalimageloader.**

######## Bugsnag (إذا وُجد) ########
-keep class com.bugsnag.** { *; }
-dontwarn com.bugsnag.**

######## Sentry (إذا وُجد) ########
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

######## إزالة التحذيرات الشائعة ########
-dontwarn java.lang.instrument.ClassFileTransformer
-dontwarn sun.misc.SignalHandler
-dontwarn java.lang.instrument.Instrumentation
-dontwarn sun.misc.Signal
-dontwarn java.lang.ClassValue
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement

######## Keep classes that are accessed via reflection ########
-keep class * implements java.io.Serializable { *; }
-keep class * implements android.os.Parcelable { *; }
-keepnames class * implements java.io.Serializable
-keepnames class * implements android.os.Parcelable

######## Keep annotation and enum classes ########
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Signature
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeVisibleTypeAnnotations

######## Keep Kotlin Coroutines (إذا وُجد) ########
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

######## Google Play Core (Split Install) ########
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**