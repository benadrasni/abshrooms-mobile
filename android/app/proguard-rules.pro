-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# WorkManager / Room (pulled in by AdMob). R8 otherwise drops WorkDatabase_Impl.
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.work.**
