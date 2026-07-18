package com.example.qnn_eco

/**
 * Model requirements live beside the native loader so every entry point uses
 * the same safety checks: catalogue download, test chat, and future screens.
 */
data class GenieXModelRequirements(
    val minimumUsableMemoryBytes: Long = 0,
)

object GenieXModelRequirementRegistry {
    // QAIRT keeps model/runtime buffers outside the Dart heap. A 4B bundle
    // needs more than its 3.1 GB weights file, so reject devices without 12 GiB
    // of usable RAM before it can trigger Android's low-memory killer.
    private const val QWEN3_4B_MINIMUM_MEMORY_BYTES = 12L * 1024 * 1024 * 1024

    fun forModel(modelName: String, runtimeId: String? = null): GenieXModelRequirements {
        return when {
            modelName == "ai-hub-models/Qwen3-4B-Instruct-2507" ||
                modelName == "qualcomm/Qwen3-4B-Instruct-2507" ||
                runtimeId == "qairt" && modelName.contains("Qwen3-4B-Instruct-2507", ignoreCase = true) ->
                GenieXModelRequirements(QWEN3_4B_MINIMUM_MEMORY_BYTES)

            else -> GenieXModelRequirements()
        }
    }

    fun unsupportedReason(modelName: String, capabilities: DeviceCapabilities, runtimeId: String? = null): String? {
        val requirements = forModel(modelName, runtimeId)
        if (capabilities.totalMemoryBytes < requirements.minimumUsableMemoryBytes) {
            return "This model requires at least 12 GiB of usable RAM. " +
                "This device reports ${formatGiB(capabilities.totalMemoryBytes)} GiB. " +
                "Use Qwen3 0.6B instead."
        }
        return null
    }

    private fun formatGiB(bytes: Long): String = "%.1f".format(java.util.Locale.US, bytes.toDouble() / GIB)

    private const val GIB = 1024.0 * 1024.0 * 1024.0
}
