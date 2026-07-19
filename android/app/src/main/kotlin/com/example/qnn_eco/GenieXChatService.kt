package com.example.qnn_eco

import com.geniex.sdk.bean.ChatMessage
import com.geniex.sdk.bean.GenerationConfig
import com.geniex.sdk.bean.LlmStreamResult
import kotlinx.coroutines.flow.collect

/** Native chat workflow, independent from Flutter channels and screen state. */
class GenieXChatService(private val modelLoader: GenieXModelLoader) {
    suspend fun generate(
        modelName: String,
        messages: List<ChatMessage>,
        maxTokens: Int = 512,
        onReady: () -> Unit,
        emit: (type: String, text: String?) -> Unit,
    ) {
        emit("status", "Loading model…")
        val model = modelLoader.load(modelName)
        val template = model.applyChatTemplate(messages.toTypedArray(), null, false).getOrThrow()
        emit("status", "Generating…")
        onReady()
        model.generateStreamFlow(
            template.formattedText,
            GenerationConfig(maxTokens = maxTokens),
        ).collect { streamResult ->
            when (streamResult) {
                is LlmStreamResult.Token -> emit("token", streamResult.text)
                is LlmStreamResult.Completed -> emit("completed", null)
                is LlmStreamResult.Error -> emit(
                    "error",
                    streamResult.throwable.message ?: "Generation failed.",
                )
            }
        }
    }

    suspend fun stop() = modelLoader.stop()

    fun close() = modelLoader.close()
}
