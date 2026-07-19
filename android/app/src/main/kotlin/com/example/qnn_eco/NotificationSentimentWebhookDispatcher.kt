package com.example.qnn_eco

import java.net.HttpURLConnection
import java.net.URI

/**
 * Triggers the matching MacroDroid automation after local notification triage.
 * Only the already-derived sentiment leaves the phone; notification content,
 * package name, and model output are never included in the request.
 */
class NotificationSentimentWebhookDispatcher {
    fun trigger(sentiment: NotificationSentiment) {
        val connection = (URI(WEBHOOKS.getValue(sentiment)).toURL().openConnection() as HttpURLConnection)
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = CONNECT_TIMEOUT_MILLIS
            connection.readTimeout = READ_TIMEOUT_MILLIS
            connection.instanceFollowRedirects = true

            val statusCode = connection.responseCode
            check(statusCode in 200..299) {
                "MacroDroid webhook for ${sentiment.name} returned HTTP $statusCode."
            }
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val CONNECT_TIMEOUT_MILLIS = 5_000
        const val READ_TIMEOUT_MILLIS = 5_000

        val WEBHOOKS = mapOf(
            NotificationSentiment.CRISIS to
                "https://trigger.macrodroid.com/31cfe87b-90fa-4260-bedf-eed5bc64743e/crisis",
            NotificationSentiment.DISTRESSED to
                "https://trigger.macrodroid.com/31cfe87b-90fa-4260-bedf-eed5bc64743e/distressed",
            NotificationSentiment.MILD_NEGATIVE to
                "https://trigger.macrodroid.com/31cfe87b-90fa-4260-bedf-eed5bc64743e/mild_negative",
            NotificationSentiment.NEUTRAL to
                "https://trigger.macrodroid.com/31cfe87b-90fa-4260-bedf-eed5bc64743e/neutral",
            NotificationSentiment.POSITIVE to
                "https://trigger.macrodroid.com/31cfe87b-90fa-4260-bedf-eed5bc64743e/positive",
        )
    }
}
