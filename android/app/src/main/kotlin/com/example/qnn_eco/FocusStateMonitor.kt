package com.example.qnn_eco

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.Display
import android.view.Surface

data class FocusState(val charging: Boolean, val rotated180: Boolean) {
    val active: Boolean get() = charging && rotated180

    fun asMap(): Map<String, Boolean> = mapOf(
        "charging" to charging,
        "rotated180" to rotated180,
        "active" to active,
    )
}

/**
 * Monitors the two deliberate focus-lock conditions while the Flutter activity
 * is visible: external power and an upright 180° / reverse-portrait rotation.
 */
class FocusStateMonitor(
    private val context: Context,
    private val publish: (FocusState) -> Unit,
) : SensorEventListener {
    private val sensorManager = context.getSystemService(SensorManager::class.java)
    private val displayManager = context.getSystemService(DisplayManager::class.java)
    private var charging = false
    private var rotated180 = false
    private var started = false

    private val powerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            charging = intent.action == Intent.ACTION_POWER_CONNECTED ||
                (intent.action != Intent.ACTION_POWER_DISCONNECTED && isPluggedIn(intent))
            emit()
        }
    }

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit

        override fun onDisplayRemoved(displayId: Int) = Unit

        override fun onDisplayChanged(displayId: Int) {
            if (displayId == Display.DEFAULT_DISPLAY) updateDisplayRotation()
        }
    }

    fun start() {
        if (started) return
        started = true
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
            addAction(Intent.ACTION_BATTERY_CHANGED)
        }
        val battery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(powerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(powerReceiver, filter)
        }
        charging = battery?.let(::isPluggedIn) ?: false
        displayManager?.registerDisplayListener(displayListener, null)
        sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sensor ->
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
        updateDisplayRotation()
        emit()
    }

    fun stop() {
        if (!started) return
        started = false
        sensorManager?.unregisterListener(this)
        displayManager?.unregisterDisplayListener(displayListener)
        runCatching { context.unregisterReceiver(powerReceiver) }
    }

    override fun onSensorChanged(event: SensorEvent) {
        // Fallback when auto-rotate is disabled: in portrait, gravity along
        // the device's positive Y axis means the phone is vertically inverted.
        val x = event.values.getOrNull(0) ?: 0f
        val y = event.values.getOrNull(1) ?: 0f
        val z = event.values.getOrNull(2) ?: 0f
        val nowRotated180 = y > 7.0f && x in -5.0f..5.0f && z in -5.0f..5.0f
        if (rotated180 != nowRotated180) {
            rotated180 = nowRotated180
            emit()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun isPluggedIn(intent: Intent): Boolean =
        intent.getIntExtra("plugged", 0) != 0

    private fun updateDisplayRotation() {
        val displayRotation = displayManager?.getDisplay(Display.DEFAULT_DISPLAY)?.rotation
        val nowRotated180 = displayRotation == Surface.ROTATION_180
        if (rotated180 != nowRotated180) {
            rotated180 = nowRotated180
            emit()
        }
    }

    private fun emit() = publish(FocusState(charging, rotated180))
}
