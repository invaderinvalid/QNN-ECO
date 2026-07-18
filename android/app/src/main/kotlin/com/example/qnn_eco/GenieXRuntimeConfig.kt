package com.example.qnn_eco

import com.geniex.sdk.bean.ModelConfig

data class ModelLoadPlan(
    val config: ModelConfig,
    val computeUnit: String?,
)

/**
 * Encodes the non-interchangeable configuration contracts for GenieX runtimes.
 * AI Hub bundles reject llama.cpp's context and GPU-layer defaults.
 */
object GenieXRuntimeConfigFactory {
    fun create(runtimeId: String, capabilities: DeviceCapabilities): ModelLoadPlan {
        return when (runtimeId) {
            "qairt" -> ModelLoadPlan(
                // Both values are owned by the compiled AI Hub bundle.
                config = ModelConfig(
                    nCtx = 0,
                    nGpuLayers = 0,
                    max_tokens = 512,
                    enable_thinking = false,
                ),
                computeUnit = null,
            )

            "llama_cpp" -> ModelLoadPlan(
                config = ModelConfig(nCtx = 4096, max_tokens = 512),
                computeUnit = capabilities.recommendedComputeUnit,
            )

            else -> throw IllegalArgumentException("Unsupported GenieX runtime: $runtimeId")
        }
    }
}
