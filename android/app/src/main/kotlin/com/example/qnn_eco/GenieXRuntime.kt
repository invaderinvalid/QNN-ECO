package com.example.qnn_eco

import android.content.Context
import com.geniex.sdk.GenieXSdk

/**
 * Makes SDK/plugin initialization an explicit prerequisite. GenieX otherwise
 * reports only "invalid plugin" later, when an LLM is created.
 */
class GenieXRuntime {
    @Volatile
    private var initializationError: String? = null

    @Volatile
    private var initialized = false

    fun initialize(context: Context) {
        GenieXSdk.getInstance().init(
            context.applicationContext,
            object : GenieXSdk.InitCallback {
                override fun onSuccess() {
                    initialized = true
                    initializationError = null
                }

                override fun onFailure(reason: String) {
                    initialized = false
                    initializationError = reason
                }
            },
        )
    }

    fun requireReady() {
        initializationError?.let { error ->
            throw IllegalStateException("GenieX runtime initialization failed: $error")
        }
        check(initialized) {
            "GenieX runtime initialization did not complete. Restart the app and try again."
        }
    }
}
