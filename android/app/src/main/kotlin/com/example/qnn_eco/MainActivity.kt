package com.example.qnn_eco

import android.content.Intent
import android.provider.Settings
import com.geniex.sdk.ModelManagerWrapper
import com.geniex.sdk.bean.ChatMessage
import com.geniex.sdk.bean.HubSource
import com.geniex.sdk.bean.ModelPullInput
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val app: QnnEcoApplication get() = application as QnnEcoApplication
    private val runtime: GenieXRuntime get() = app.runtime
    private val capabilityProbe: GenieXDeviceCapabilityProbe get() = app.capabilityProbe
    private val inferenceCoordinator: GenieXInferenceCoordinator get() = app.inferenceCoordinator
    private var progressSink: EventChannel.EventSink? = null
    private var chatSink: EventChannel.EventSink? = null
    private var focusStateMonitor: FocusStateMonitor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethod(call, result) }
        configureProgressChannel(flutterEngine)
        configureChatChannel(flutterEngine)
        configureFocusStateChannel(flutterEngine)
    }

    private fun configureProgressChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            })
    }

    private fun configureChatChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHAT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    chatSink = events
                }

                override fun onCancel(arguments: Any?) {
                    chatSink = null
                }
            })
    }

    private fun configureFocusStateChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_STATE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    focusStateMonitor?.stop()
                    focusStateMonitor = FocusStateMonitor(applicationContext) { state ->
                        runOnUiThread { events?.success(state.asMap()) }
                    }.also { it.start() }
                }

                override fun onCancel(arguments: Any?) {
                    focusStateMonitor?.stop()
                    focusStateMonitor = null
                }
            })
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceCapabilities" -> getDeviceCapabilities(result)
            "listDownloadedModels" -> listDownloadedModels(result)
            "isModelDownloaded" -> isModelDownloaded(call, result)
            "downloadModel" -> downloadModel(call, result)
            "generateReply" -> generateReply(call, result)
            "stopGeneration" -> stopGeneration(result)
            "getNotificationTriageStatus" -> getNotificationTriageStatus(result)
            "getRecentNotificationStatus" -> getRecentNotificationStatus(result)
            "openNotificationListenerSettings" -> openNotificationListenerSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun getDeviceCapabilities(result: MethodChannel.Result) {
        ioScope.launch {
            try {
                runtime.requireReady()
                val capabilities = capabilityProbe.get()
                respond { result.success(capabilities.asMap()) }
            } catch (error: Throwable) {
                respond { result.error("CAPABILITY_CHECK_FAILED", error.message, null) }
            }
        }
    }

    private fun listDownloadedModels(result: MethodChannel.Result) {
        ioScope.launch {
            try {
                runtime.requireReady()
                val models = ModelManagerWrapper.list()
                respond { result.success(models) }
            } catch (error: Throwable) {
                respond { result.error("MODEL_LIST_FAILED", error.message, null) }
            }
        }
    }

    /** Resolves aliases through GenieX instead of comparing its cache labels. */
    private fun isModelDownloaded(call: MethodCall, result: MethodChannel.Result) {
        val modelName = call.argument<String>("modelName")
        if (modelName.isNullOrBlank()) {
            result.error("INVALID_MODEL", "A model name is required.", null)
            return
        }
        ioScope.launch {
            try {
                runtime.requireReady()
                val paths = ModelManagerWrapper.getPaths(modelName)
                respond { result.success(paths != null) }
            } catch (error: Throwable) {
                respond { result.error("MODEL_STATUS_FAILED", error.message, null) }
            }
        }
    }

    private fun downloadModel(call: MethodCall, result: MethodChannel.Result) {
        val modelName = call.argument<String>("modelName")
        if (modelName.isNullOrBlank()) {
            result.error("INVALID_MODEL", "A model name is required.", null)
            return
        }

        val precision = call.argument<String>("precision")
        val chipset = call.argument<String>("chipset")
        val hub = when (call.argument<String>("hub")) {
            "huggingface" -> HubSource.HUGGINGFACE
            "aihub" -> HubSource.AIHUB
            else -> HubSource.AUTO
        }

        ioScope.launch {
            var delivered = false
            try {
                runtime.requireReady()
                if (hub == HubSource.AIHUB) {
                    val capabilities = capabilityProbe.get()
                    if (!capabilities.supportsAiHub) {
                        throw IncompatibleDeviceException(
                            "Qualcomm AI Hub models require a verified SM8750 or SM8850 device.",
                        )
                    }
                    if (chipset != capabilities.chipset) {
                        throw IncompatibleDeviceException(
                            "The selected bundle ($chipset) does not match this phone (${capabilities.chipset}).",
                        )
                    }
                    GenieXModelRequirementRegistry.unsupportedReason(modelName, capabilities)?.let {
                        throw IncompatibleDeviceException(it)
                    }
                }

                val input = ModelPullInput(
                    model_name = modelName,
                    precision = precision,
                    hub = hub,
                    chipset = chipset,
                )
                ModelManagerWrapper.pullFlow(input).collect { event ->
                    if (delivered) return@collect
                    when (event) {
                        is ModelManagerWrapper.PullEvent.Progress -> {
                            val total = event.files.sumOf { it.total_bytes }
                            val downloaded = event.files.sumOf { it.downloaded_bytes }
                            val fraction = if (total > 0) downloaded.toDouble() / total else 0.0
                            emitProgress(modelName, fraction, downloaded, total)
                        }

                        ModelManagerWrapper.PullEvent.Completed -> {
                            delivered = true
                            respond { result.success(null) }
                        }

                        is ModelManagerWrapper.PullEvent.Error -> {
                            delivered = true
                            respond {
                                result.error(
                                    "MODEL_PULL_FAILED",
                                    event.message,
                                    mapOf("code" to event.code),
                                )
                            }
                        }
                    }
                }
            } catch (error: Throwable) {
                if (!delivered) {
                    respond { result.error("MODEL_PULL_FAILED", error.message, null) }
                }
            }
        }
    }

    private fun generateReply(call: MethodCall, result: MethodChannel.Result) {
        val modelName = call.argument<String>("modelName")
        val messages = readMessages(call.arguments)
        if (modelName.isNullOrBlank() || messages.isEmpty()) {
            result.error("INVALID_CHAT", "A model and at least one message are required.", null)
            return
        }

        ioScope.launch {
            var methodResultSent = false
            try {
                inferenceCoordinator.generate(
                    modelName = modelName,
                    messages = messages,
                    onReady = {
                        methodResultSent = true
                        respond { result.success(null) }
                    },
                    emit = { type, text -> emitChat(modelName, type, text) },
                )
            } catch (error: Throwable) {
                emitChat(modelName, "error", error.message ?: "Could not start generation.")
                if (!methodResultSent) respond { result.success(null) }
            }
        }
    }

    private fun stopGeneration(result: MethodChannel.Result) {
        ioScope.launch {
            try {
                inferenceCoordinator.stop()
                respond { result.success(null) }
            } catch (error: Throwable) {
                respond { result.error("STOP_FAILED", error.message, null) }
            }
        }
    }

    private fun getNotificationTriageStatus(result: MethodChannel.Result) {
        result.success(
            mapOf(
                "listenerEnabled" to NotificationTriageAccess.isListenerEnabled(applicationContext),
                "irAvailable" to IrBlaster(applicationContext).isAvailable,
            ),
        )
    }

    private fun getRecentNotificationStatus(result: MethodChannel.Result) {
        ioScope.launch {
            try {
                val summary = NotificationTemporaryStore(applicationContext).summaryForTool()
                respond { result.success(summary) }
            } catch (error: Throwable) {
                respond { result.error("NOTIFICATION_STATUS_FAILED", error.message, null) }
            }
        }
    }

    private fun openNotificationListenerSettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            result.success(null)
        } catch (error: Throwable) {
            result.error("NOTIFICATION_SETTINGS_FAILED", error.message, null)
        }
    }

    private fun readMessages(arguments: Any?): List<ChatMessage> {
        val rawMessages = (arguments as? Map<*, *>)?.get("messages") as? List<*> ?: return emptyList()
        return rawMessages.mapNotNull { raw ->
            val message = raw as? Map<*, *> ?: return@mapNotNull null
            val role = message["role"] as? String ?: return@mapNotNull null
            val content = message["content"] as? String ?: return@mapNotNull null
            ChatMessage(role, content)
        }
    }

    private fun emitProgress(modelName: String, fraction: Double, downloaded: Long, total: Long) {
        runOnUiThread {
            progressSink?.success(
                mapOf(
                    "modelName" to modelName,
                    "fraction" to fraction,
                    "downloadedBytes" to downloaded,
                    "totalBytes" to total,
                ),
            )
        }
    }

    private fun emitChat(modelName: String, type: String, text: String? = null) {
        runOnUiThread {
            chatSink?.success(
                mapOf("modelName" to modelName, "type" to type, "text" to text),
            )
        }
    }

    private fun respond(action: () -> Unit) = runOnUiThread(action)

    override fun onDestroy() {
        focusStateMonitor?.stop()
        ioScope.cancel()
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "com.example.qnn_eco/geniex"
        const val PROGRESS_CHANNEL = "com.example.qnn_eco/geniex_progress"
        const val CHAT_CHANNEL = "com.example.qnn_eco/geniex_chat"
        const val FOCUS_STATE_CHANNEL = "com.example.qnn_eco/focus_state"
    }
}
