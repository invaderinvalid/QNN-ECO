package com.example.qnn_eco

import io.flutter.app.FlutterApplication

/** Owns the single native inference pipeline shared by UI and background work. */
class QnnEcoApplication : FlutterApplication() {
    val runtime = GenieXRuntime()
    val capabilityProbe by lazy { GenieXDeviceCapabilityProbe(this) }
    val inferenceCoordinator by lazy {
        GenieXInferenceCoordinator(GenieXModelLoader(runtime, capabilityProbe))
    }

    override fun onCreate() {
        super.onCreate()
        runtime.initialize(this)
    }
}
