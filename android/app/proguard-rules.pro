# GenieX's native library resolves SDK types and fields through JNI. R8 must
# retain their exact names; otherwise a model pull aborts the entire process.
-keep class com.geniex.sdk.** { *; }
