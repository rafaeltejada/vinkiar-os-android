package com.vinkiar.sor

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.app.ActivityOptions
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat

// =========================================================================
// SECCIÓN 1: SERVICIO DE ACCESIBILIDAD PARA GATILLO HARDWARE SILENCIOSO
// =========================================================================
class VinkiarSosAccessibilityService : AccessibilityService() {
    private val TAG = "VinkiarSosA11y"
    private var volumeChangeReceiver: BroadcastReceiver? = null

    companion object {
        const val SILENT_CHANNEL_ID = "vinkiar_silent_decoy_v2"
        const val SILENT_NOTIFICATION_ID = 9999
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "🟢 Servicio de Accesibilidad Vinkiar conectado al SO.")
        registerVolumeChangeReceiver()
    }

    // =========================================================================
    // SECCIÓN 2: DETECCIÓN DE RÁFAGA DE VOLUMEN (PANTALLA BLOQUEADA Y PRIMER PLANO)
    // =========================================================================
    /// Escucha cambios de volumen del sistema incluso con el teléfono bloqueado
    private fun registerVolumeChangeReceiver() {
        if (volumeChangeReceiver != null) return
        volumeChangeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                    context?.let { ctx ->
                        val triggered = SosCoordinator.onVolumeKeyPressed(ctx)
                        if (triggered) {
                            wakeUpDeviceAndLaunchOverlay()
                        }
                    }
                }
            }
        }
        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(volumeChangeReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(volumeChangeReceiver, filter)
        }
    }

    override fun onDestroy() {
        volumeChangeReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    /// Intercepta directamente las pulsaciones físicas de subir/bajar volumen
    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_UP -> {
                    val triggered = SosCoordinator.onVolumeKeyPressed(this)
                    if (triggered) {
                        wakeUpDeviceAndLaunchOverlay()
                        return true
                    }
                }
            }
        }
        return false
    }

    // =========================================================================
    // SECCIÓN 3: DESPERTAR PANTALLA Y DESPLIEGUE 100 % SILENCIOSO DEL SEÑUELO
    // =========================================================================
    private fun wakeUpDeviceAndLaunchOverlay() {
        // 1. Encender la pantalla física si estaba apagada
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = pm?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "VinkiarOS:SosHardwareTrigger"
            )
            wakeLock?.acquire(4000L)
        } catch (_: Exception) {}

        // 2. Traer la tarea al frente si estaba minimizada
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            am?.appTasks?.firstOrNull()?.moveToFront()
        } catch (_: Exception) {}

        // 3. Preparar Intent hacia MainActivity para renderizar la pantalla señuelo
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            putExtra("TRIGGER_SOS_HARDWARE", true)
        }

        val optionsBundle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ActivityOptions.makeBasic().apply {
                pendingIntentBackgroundActivityStartMode =
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            }.toBundle()
        } else {
            null
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (optionsBundle != null) {
                startActivity(intent, optionsBundle)
            } else {
                startActivity(intent)
            }
        } catch (_: Exception) {
            try {
                pendingIntent.send()
            } catch (_: Exception) {}
        }

        // 4. Lanzar FullScreenIntent completamente mudo y camuflado (sin pitido ni texto de alerta)
        triggerSilentFullScreenIntent(pendingIntent)
    }

    private fun triggerSilentFullScreenIntent(pendingIntent: PendingIntent) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Eliminar el canal antiguo ruidoso si existía en el dispositivo
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                nm.deleteNotificationChannel("vinkiar_sos_channel")
            } catch (_: Exception) {}

            val channel = NotificationChannel(
                SILENT_CHANNEL_ID,
                "Sincronización del Sistema",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Canal silencioso de sistema"
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_SECRET
                setSound(null, null)         // SIN SONIDO / SIN PITIDO
                enableVibration(false)       // La vibración ya la ejecuta SosCoordinator
                enableLights(false)
            }
            nm.createNotificationChannel(channel)
        }

        val builder = NotificationCompat.Builder(this, SILENT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle("Calculadora")
            .setContentText("Lista")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SYSTEM)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setSilent(true)
            .setSound(null)
            .setAutoCancel(true)

        nm.notify(SILENT_NOTIFICATION_ID, builder.build())
    }
}