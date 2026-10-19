# Scheduled notifications are stored as JSON with Gson and read back after a
# restart or an app update, so the plugin's classes keep their names and
# fields, and generic signatures stay for Gson's type tokens.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
