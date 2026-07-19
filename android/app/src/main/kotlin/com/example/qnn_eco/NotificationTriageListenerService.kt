package com.example.qnn_eco

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * System-bound listener. Android keeps it eligible to receive posted notifications
 * after the user enables notification access in system settings.
 */
class NotificationTriageListenerService : NotificationListenerService() {
    private val workScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val recentNotifications = mutableMapOf<String, Long>()

    private lateinit var triageEngine: NotificationTriageEngine
    private lateinit var irBlaster: IrBlaster
    private lateinit var webhookDispatcher: NotificationSentimentWebhookDispatcher
    private lateinit var speechAnnouncer: NotificationSpeechAnnouncer
    private lateinit var temporaryStore: NotificationTemporaryStore

    override fun onCreate() {
        super.onCreate()
        val app = application as QnnEcoApplication
        triageEngine = NotificationTriageEngine(app.inferenceCoordinator)
        irBlaster = IrBlaster(applicationContext)
        webhookDispatcher = NotificationSentimentWebhookDispatcher()
        speechAnnouncer = NotificationSpeechAnnouncer(applicationContext)
        temporaryStore = NotificationTemporaryStore(applicationContext)
    }

    override fun onNotificationPosted(notification: StatusBarNotification) {
        if (notification.packageName == packageName || isGroupSummary(notification.notification)) return
        val title = notification.notification.extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val body = (
            notification.notification.extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: notification.notification.extras?.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString()?.trim().orEmpty()
        if (title.isBlank() && body.isBlank() || recentlyHandled(notification, title, body)) return

        // The read-status tool must retain the observation even if the model is
        // temporarily unavailable, out of memory, or returns malformed output.
        temporaryStore.save(notification.packageName, title, body)

        workScope.launch {
            runCatching { triageEngine.triage(title, body) }
                .onSuccess { result ->
                    temporaryStore.save(notification.packageName, title, body, result)
                    if (!result.isPromotional && result.sentiment != null) {
                        runCatching { irBlaster.signal(result.sentiment) }
                            .onFailure { error -> Log.w(TAG, "Could not send IR triage signal.", error) }
                        runCatching { webhookDispatcher.trigger(result.sentiment) }
                            .onFailure { error -> Log.w(TAG, "Could not trigger sentiment webhook.", error) }
                        speechAnnouncer.announce(result.spokenText)
                    }
                }
                .onFailure { error -> Log.e(TAG, "Could not triage notification.", error) }
        }
    }

    override fun onDestroy() {
        workScope.cancel()
        speechAnnouncer.close()
        super.onDestroy()
    }

    private fun isGroupSummary(notification: Notification): Boolean =
        notification.flags and Notification.FLAG_GROUP_SUMMARY != 0

    @Synchronized
    private fun recentlyHandled(notification: StatusBarNotification, title: String, body: String): Boolean {
        val now = System.currentTimeMillis()
        recentNotifications.entries.removeAll { now - it.value > DEDUPLICATION_WINDOW_MILLIS }
        val key = "${notification.packageName}|$title|$body"
        if (recentNotifications.containsKey(key)) return true
        recentNotifications[key] = now
        return false
    }

    private companion object {
        const val TAG = "NotificationTriage"
        const val DEDUPLICATION_WINDOW_MILLIS = 15_000L
    }
}
