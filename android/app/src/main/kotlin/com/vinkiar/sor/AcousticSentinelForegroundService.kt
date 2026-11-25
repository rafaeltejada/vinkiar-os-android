package com.vinkiar.sor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * SERVICIO EN PRIMER PLANO PARA EL CENTINELA ACÚSTICO
 * Mantiene la CPU despierta y el canal de micrófono abierto en segundo plano o pantalla bloqueada.
 */
class AcousticSentinelForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val TAG = "AcousticSentinelService"
        const val ACTION_START = "com.vinkiar.sor.START_SENTINEL"
        const val ACTION_STOP = "com.vinkiar.sor.STOP_SENTINEL"
        private const val CHANNEL_ID = "vinkiar_acoustic_sentinel_channel"
        private const val NOTIFICATION_ID = 9922
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🛡️ [CENTINELA SERVICE] Servicio en primer plano creado.")
        createNotificationChannel()
        acquireCpuWakeLock()
    }

    private fun acquireCpuWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "vinkiar:sentinel_cpu_lock")?.apply {
                setReferenceCounted(false)
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire()
                Log.d(TAG, "⚡ WakeLock parcial adquirido para vigilancia en segundo plano.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Error adquiriendo WakeLock: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Centinela Acústico Vinkiar",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene la vigilancia acústica activa para protección en citas"
                setSound(null, null)
                enableVibration(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.i(TAG, "🛑 [CENTINELA SERVICE] Recibida orden de parada (ACTION_STOP).")
            stopSelf()
            return START_NOT_STICKY
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val appIcon = applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_btn_speak_now

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(appIcon)
            .setContentTitle("Centinela Acústico Activo")
            .setContentText("Vigilancia de palabra de seguridad operativa")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setContentIntent(pendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        }

        val notification: Notification = builder.build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.i(TAG, "🎙️ [CENTINELA SERVICE] startForeground ejecutado con tipo MICROPHONE.")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [CENTINELA SERVICE] Error al iniciar Foreground Service: ${e.message}")
        }

        return START_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "🛑 [CENTINELA SERVICE] Destruyendo servicio y liberando recursos...")
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "⚡ WakeLock liberado.")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Error liberando WakeLock: ${e.message}")
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Error en stopForeground: ${e.message}")
        }

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}