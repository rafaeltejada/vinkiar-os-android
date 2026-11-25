# Ignorar clases faltantes de Stripe y Google Play Services durante el minificado de R8
-dontwarn com.stripe.android.**
-dontwarn com.reactnativestripesdk.**
-dontwarn com.google.android.gms.**

-keep class com.stripe.android.** { *; }
-keep class com.reactnativestripesdk.** { *; }