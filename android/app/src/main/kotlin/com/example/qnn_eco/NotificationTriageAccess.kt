package com.example.qnn_eco

import android.content.Context
import androidx.core.app.NotificationManagerCompat

/** Access to notification content is granted and revoked only by the user. */
object NotificationTriageAccess {
    fun isListenerEnabled(context: Context): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)
}
