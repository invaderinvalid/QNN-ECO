package com.example.qnn_eco

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import com.geniex.sdk.ModelManagerWrapper

data class DeviceCapabilities(
    val isArm64: Boolean,
    val chipset: String?,
    val supportsNpu: Boolean,
    val totalMemoryBytes: Long,
    val availableMemoryBytes: Long,
) {
    val supportsAiHub: Boolean get() = supportsNpu
    val recommendedComputeUnit: String get() = if (supportsNpu) "npu" else "cpu"

    fun asMap() = mapOf(
        "isArm64" to isArm64,
        "chipset" to chipset,
        "supportsNpu" to supportsNpu,
        "supportsAiHub" to supportsAiHub,
        "recommendedComputeUnit" to recommendedComputeUnit,
        "totalMemoryBytes" to totalMemoryBytes,
        "availableMemoryBytes" to availableMemoryBytes,
    )
}

/**
 * Owns hardware discovery. Keeping this separate prevents UI or model code from
 * guessing an NPU configuration from a downloaded model alone.
 */
class GenieXDeviceCapabilityProbe(private val context: Context) {
    private var cached: DeviceCapabilities? = null

    suspend fun get(): DeviceCapabilities {
        cached?.let { capabilities ->
            val memory = readMemoryInfo()
            return capabilities.copy(
                totalMemoryBytes = memory.totalMem,
                availableMemoryBytes = memory.availMem,
            )
        }

        val isArm64 = Build.SUPPORTED_ABIS.any { it.equals("arm64-v8a", ignoreCase = true) }
        val sdkChipset = runCatching { ModelManagerWrapper.detectChipset() }.getOrNull()
        val chipset = detectSupportedChipset(
            listOfNotNull(
                sdkChipset,
                Build.HARDWARE,
                Build.BOARD,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else null,
            ),
        )
        val memoryInfo = readMemoryInfo()
        return DeviceCapabilities(
            isArm64 = isArm64,
            chipset = chipset,
            supportsNpu = isArm64 && chipset in supportedNpuChipsets,
            totalMemoryBytes = memoryInfo.totalMem,
            availableMemoryBytes = memoryInfo.availMem,
        ).also { cached = it }
    }

    private fun readMemoryInfo(): ActivityManager.MemoryInfo {
        return ActivityManager.MemoryInfo().also { memoryInfo ->
            context.getSystemService(ActivityManager::class.java)?.getMemoryInfo(memoryInfo)
        }
    }

    private fun detectSupportedChipset(hints: List<String>): String? {
        val joined = hints.joinToString(" ")
        val match = chipsetPattern.find(joined) ?: return null
        return "SM${match.groupValues[1]}"
    }

    private companion object {
        val supportedNpuChipsets = setOf("SM8750", "SM8850")
        val chipsetPattern = Regex("SM\\s*[-_]?\\s*(8750|8850)", RegexOption.IGNORE_CASE)
    }
}
