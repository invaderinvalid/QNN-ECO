package com.example.qnn_eco

import com.geniex.sdk.bean.ChatMessage
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Serializes every invocation of the one loaded native LLM. This prevents a
 * notification arriving during chat from competing for model memory or streams.
 */
class GenieXInferenceCoordinator(modelLoader: GenieXModelLoader) {
    private val gate = Mutex()
    private val chatService = GenieXChatService(modelLoader)

    suspend fun generate(
        modelName: String,
        messages: List<ChatMessage>,
        maxTokens: Int = 512,
        onReady: () -> Unit,
        emit: (type: String, text: String?) -> Unit,
    ) = gate.withLock {
        chatService.generate(modelName, messages, maxTokens, onReady, emit)
    }

    // Stop is intentionally not queued behind the active generation: it is the
    // cancellation path for that generation, while all new work remains gated.
    suspend fun stop() = chatService.stop()
}
