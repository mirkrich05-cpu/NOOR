# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Local Notifications & Gson reflection rules
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*

# HomeWidget & Workmanager Receivers
-keep class com.noor.islamic.app.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
-dontwarn com.google.errorprone.annotations.**
