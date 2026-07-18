package com.example.qnn_eco

import com.geniex.sdk.LlmWrapper
import com.geniex.sdk.ModelManagerWrapper
import com.geniex.sdk.bean.LlmCreateInput

class IncompatibleDeviceException(message: String) : IllegalStateException(message)

/**
 * Creates exactly one native LLM at a time and chooses a compute unit only
 * after the device has been profiled.
 */
class GenieXModelLoader(
    private val runtime: GenieXRuntime,
    private val capabilityProbe: GenieXDeviceCapabilityProbe,
) {
    private var loadedModelName: String? = null
    private var llm: LlmWrapper? = null

    suspend fun load(modelName: String): LlmWrapper {
        if (loadedModelName == modelName && llm != null) return llm!!

        runtime.requireReady()
        val capabilities = capabilityProbe.get()
        if (!capabilities.isArm64) {
            throw IncompatibleDeviceException(
                "GenieX Android models require a 64-bit ARM Android device. This device is not arm64-v8a.",
            )
        }

        llm?.close()
        llm = null
        loadedModelName = null

        val paths = ModelManagerWrapper.getPaths(modelName)
            ?: error("This model has not been downloaded yet.")
        val isAiHubModel = paths.runtime_id == "qairt"
        if (isAiHubModel && !capabilities.supportsAiHub) {
            throw IncompatibleDeviceException(
                "This Qualcomm AI Hub model requires a Snapdragon 8 Elite (SM8750) or 8 Elite Gen 5 (SM8850). " +
                    "The current phone could not be verified as either chipset.",
            )
        }
        GenieXModelRequirementRegistry.unsupportedReason(modelName, capabilities, paths.runtime_id)?.let {
            throw IncompatibleDeviceException(it)
        }

        val plan = GenieXRuntimeConfigFactory.create(paths.runtime_id, capabilities)
        val loaded = LlmWrapper.builder()
            .llmCreateInput(
                LlmCreateInput(
                    model_name = paths.model_name,
                    model_path = paths.model_path,
                    tokenizer_path = paths.tokenizer_path,
                    config = plan.config,
                    runtime_id = paths.runtime_id,
                    compute_unit = plan.computeUnit,
                ),
            )
            .build()
            .getOrThrow()
        llm = loaded
        loadedModelName = modelName
        return loaded
    }

    suspend fun stop() {
        llm?.stopStream()
    }

    fun close() {
        llm?.close()
        llm = null
        loadedModelName = null
    }
}
