package com.vinkiar.sor

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

object SosCoordinator {
    private const val TAG = "SosCoordinator"
    private val pressTimestamps = mutableListOf<Long>()
    private const val REQUIRED_PRESSES = 4
    private const val TIME_WINDOW_MS = 2500L
    private var lastSinglePressTime = 0L
    private var lastTriggerTimestamp = 0L

    var methodChannel: MethodChannel? = null

    @Synchronized
    fun onVolumeKeyPressed(context: Context): Boolean {
        val now = System.currentTimeMillis()
        // Debounce de 180ms para evitar doble conteo cuando MainActivity y AccessibilityService reportan el mismo botón físico
        if (now - lastSinglePressTime < 180L) {
            return false
        }
        lastSinglePressTime = now

        vibrateTick(context)

        pressTimestamps.add(now)
        pressTimestamps.removeAll { now - it > TIME_WINDOW_MS }

        Log.i(TAG, "📊 Ráfaga de Volumen: ${pressTimestamps.size} / $REQUIRED_PRESSES en $TIME_WINDOW_MS ms")

        if (pressTimestamps.size >= REQUIRED_PRESSES) {
            pressTimestamps.clear()
            if (tryAcquireTrigger()) {
                Log.w(TAG, "🚨 ¡GATILLO HARDWARE ACTIVADO! Detonando emergencia...")
                vibrateImmediate(context)
                dispatchSosToFlutter()
                return true
            }
        }
        return false
    }

    @Synchronized
    fun tryAcquireTrigger(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastTriggerTimestamp < 2200L) {
            return false
        }
        lastTriggerTimestamp = now
        return true
    }

    fun dispatchSosToFlutter() {
        Log.w(TAG, "📢 [SOS COORDINATOR] Invocando onSosTriggered hacia Flutter...")
        Handler(Looper.getMainLooper()).post {
            methodChannel?.invokeMethod("onSosTriggered", mapOf("source" to "HARDWARE_TRIGGER"))
        }
    }

    fun vibrateImmediate(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val attrs = AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                    val timings = longArrayOf(0, 250, 120, 350)
                    val effect = if (vibrator.hasAmplitudeControl()) {
                        VibrationEffect.createWaveform(timings, intArrayOf(0, 255, 0, 255), -1)
                    } else {
                        VibrationEffect.createWaveform(timings, -1)
                    }
                    vibrator.vibrate(effect, attrs)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(longArrayOf(0, 250, 120, 350), -1)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error vibrando: ${e.message}")
        }
    }

    fun vibrateTick(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val attrs = AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                    val effect = VibrationEffect.createOneShot(50L, 255)
                    vibrator.vibrate(effect, attrs)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(50L)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error vibrateTick: ${e.message}")
        }
    }
}