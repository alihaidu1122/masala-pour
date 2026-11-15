# Keep rules for release builds (R8 shrinking).

# WorkManager (used by Google Mobile Ads) creates its Room database by
# reflection; R8 removed WorkDatabase_Impl and the app crashed at startup.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Google Mobile Ads / Play services.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Billing (in_app_purchase).
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }
