# Keep kotlinx.serialization @Serializable classes and companion serializers.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

-keep,includedescriptorclasses class de.gummipunkt.crossy.**$$serializer { *; }
-keepclassmembers class de.gummipunkt.crossy.** {
    *** Companion;
}
-keepclasseswithmembers class de.gummipunkt.crossy.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# OkHttp / Retrofit boilerplate
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
