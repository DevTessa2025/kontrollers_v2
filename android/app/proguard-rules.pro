# Keep all classes from mssql_connection and related JDBC drivers
-keep class net.sourceforge.jtds.** { *; }
-keep class com.microsoft.sqlserver.** { *; }

# Keep JCIFS classes (for SMB/CIFS support)
-keep class jcifs.** { *; }

# Keep GSS-API classes (for authentication)
-keep class org.ietf.jgss.** { *; }

# Keep SQL Server driver classes
-keep class com.microsoft.** { *; }

# Keep JTDS driver classes
-keepclassmembers class * extends java.sql.Driver {
    *;
}

# Keep all SQL-related classes
-keep class java.sql.** { *; }
-keep class javax.sql.** { *; }

# Keep XA Transaction classes
-keep class javax.transaction.** { *; }
-keep class javax.sql.XAConnection { *; }
-keep class javax.sql.XADataSource { *; }

# Keep Play Core classes (Flutter uses these)
-keep class com.google.android.play.core.** { *; }

# Keep reflection-based access
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep database connection classes
-keep class * implements java.sql.Driver
-keep class * extends java.sql.Connection
-keep class * extends java.sql.Statement
-keep class * extends java.sql.PreparedStatement
-keep class * extends java.sql.ResultSet

# Suppress warnings for missing optional classes
-dontwarn jcifs.**
-dontwarn org.ietf.jgss.**
-dontwarn javax.naming.**
-dontwarn javax.security.auth.**
-dontwarn javax.transaction.**
-dontwarn com.google.android.play.core.**

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Additional Flutter engine rules
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**