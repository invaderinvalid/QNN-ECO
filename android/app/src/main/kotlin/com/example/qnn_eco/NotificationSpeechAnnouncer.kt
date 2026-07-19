package com.example.qnn_eco

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

/** Small lifecycle-owned TTS adapter for notification summaries. */
class NotificationSpeechAnnouncer(context: Context) : TextToSpeech.OnInitListener {
    private val textToSpeech = TextToSpeech(context.applicationContext, this)
    private var ready = false
    private var pendingText: String? = null

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
        if (ready) {
            textToSpeech.language = Locale.getDefault()
            pendingText?.let(::announce)
            pendingText = null
        }
    }

    fun announce(text: String) {
        if (!ready) {
            pendingText = text
            return
        }
        textToSpeech.speak(text, TextToSpeech.QUEUE_FLUSH, null, "notification-triage")
    }

    fun close() = textToSpeech.shutdown()
}
