package com.vinkiar.sor

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.telephony.SmsManager
import android.util.Base64
import android.view.KeyEvent
import android.view.WindowManager
import androidx.activity.OnBackPressedCallback
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

// =========================================================================
// SECCIÓN 1: ACTIVIDAD PRINCIPAL Y CANALES NATIVOS FLUTTER <-> ANDROID
// =========================================================================
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.vinkiar.os/hardware_sos"
    private val GSM_CHANNEL = "com.vinkiar/gsm"
    private val ZKP_AUTH_CHANNEL = "com.vinkiar.os/zkp_auth"
    private val KEYSTORE_ALIAS = "vnk_zkp_device_vault_key_v1"

    private var sosChannel: MethodChannel? = null
    private var audioManager: AudioManager? = null
    private var pendingSosTrigger = false
    private var isZkpPromptActive = false

    // =========================================================================
    // SECCIÓN 2: CICLO DE VIDA, PANTALLA SEGURA Y DESPLIEGUE SOBRE BLOQUEO
    // =========================================================================
    override fun onCreate(savedInstanceState: Bundle?) {
        // Bloquea capturas de pantalla y vistas previas en multitarea (Seguridad ZKA)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        audioManager?.mode = AudioManager.MODE_NORMAL

        enableLockScreenDisplay()
        setupBackPressHandling()
        checkHardwareSosIntent(intent)
    }

    /// Evita cerrar el motor de Flutter al pulsar atrás; minimiza al escritorio
    private fun setupBackPressHandling() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                moveTaskToBack(true)
            }
        })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enableLockScreenDisplay()
        checkHardwareSosIntent(intent)
    }

    /// Permite que la pantalla señuelo se muestre encima de la pantalla bloqueada
    private fun enableLockScreenDisplay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            if (!isZkpPromptActive) {
                val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                km?.requestDismissKeyguard(this, null)
            }
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun checkHardwareSosIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("TRIGGER_SOS_HARDWARE", false) == true) {
            clearSilentSosNotification()
            if (sosChannel != null) {
                SosCoordinator.dispatchSosToFlutter()
            } else {
                pendingSosTrigger = true
            }
        }
    }

    override fun onResume() {
        super.onResume()
        audioManager?.mode = AudioManager.MODE_NORMAL
        enableLockScreenDisplay()
    }

    // =========================================================================
    // SECCIÓN 3: INTERCEPTOR DE BOTONES FÍSICOS DE VOLUMEN (GATILLO SOS)
    // =========================================================================
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_UP -> {
                    val triggered = SosCoordinator.onVolumeKeyPressed(this)
                    if (triggered) {
                        return true
                    }
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    // =========================================================================
    // SECCIÓN 4: CONFIGURACIÓN DE METHOD CHANNELS (SOS, SMS GSM Y ZKP AUTH)
    // =========================================================================
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal 1: Control de hardware SOS, servicios en primer plano y silenciado
        sosChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        SosCoordinator.methodChannel = sosChannel

        if (pendingSosTrigger) {
            pendingSosTrigger = false
            window.decorView.postDelayed({
                SosCoordinator.dispatchSosToFlutter()
            }, 300)
        }

        sosChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "dismissKeyguard" -> {
                    enableLockScreenDisplay()
                    result.success(true)
                }
                "startSentinelForegroundService" -> {
                    try {
                        val serviceIntent = Intent(this, AcousticSentinelForegroundService::class.java).apply {
                            action = AcousticSentinelForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stopSentinelForegroundService" -> {
                    try {
                        val serviceIntent = Intent(this, AcousticSentinelForegroundService::class.java).apply {
                            action = AcousticSentinelForegroundService.ACTION_STOP
                        }
                        startService(serviceIntent)
                        stopService(Intent(this, AcousticSentinelForegroundService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stopHardwareSosService" -> {
                    clearSilentSosNotification()
                    result.success(true)
                }
                "muteSystemAudio" -> {
                    try {
                        audioManager?.let { am ->
                            am.mode = AudioManager.MODE_NORMAL
                            am.adjustStreamVolume(AudioManager.STREAM_SYSTEM, AudioManager.ADJUST_MUTE, 0)
                            am.adjustStreamVolume(AudioManager.STREAM_NOTIFICATION, AudioManager.ADJUST_MUTE, 0)
                            am.adjustStreamVolume(AudioManager.STREAM_RING, AudioManager.ADJUST_MUTE, 0)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "unmuteSystemAudio" -> {
                    try {
                        audioManager?.let { am ->
                            am.mode = AudioManager.MODE_NORMAL
                            am.adjustStreamVolume(AudioManager.STREAM_SYSTEM, AudioManager.ADJUST_UNMUTE, 0)
                            am.adjustStreamVolume(AudioManager.STREAM_NOTIFICATION, AudioManager.ADJUST_UNMUTE, 0)
                            am.adjustStreamVolume(AudioManager.STREAM_RING, AudioManager.ADJUST_UNMUTE, 0)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "vibrateEmergencyPattern" -> {
                    SosCoordinator.vibrateImmediate(this)
                    result.success(true)
                }
                "exitToHome" -> {
                    try {
                        moveTaskToBack(true)
                        result.success(true)
                    } catch (e: Exception) {
                        finishAffinity()
                        result.success(true)
                    }
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Canal 2: Envío nativo de SMS GSM cuando no hay conexión de datos
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GSM_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")

                if (!phone.isNullOrBlank() && !message.isNullOrBlank()) {
                    try {
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }

                        val parts = smsManager.divideMessage(message)
                        if (parts.size > 1) {
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        } else {
                            smsManager.sendTextMessage(phone, null, message, null, null)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.localizedMessage, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Teléfono o mensaje vacíos", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Canal 3: Autenticación ZKP sin biometría (Android Keystore + DEVICE_CREDENTIAL)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ZKP_AUTH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkCredentialCapabilities" -> {
                    val bm = BiometricManager.from(this)
                    val canDevicePin = bm.canAuthenticate(BiometricManager.Authenticators.DEVICE_CREDENTIAL) == BiometricManager.BIOMETRIC_SUCCESS
                    val canBiometric = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
                    result.success(
                        mapOf(
                            "deviceCredentialAvailable" to canDevicePin,
                            "biometricStrongAvailable" to canBiometric
                        )
                    )
                }

                "wrapVaultKeyWithDeviceCredential" -> {
                    val secretB64 = call.argument<String>("secretB64")
                    val pinOnly = call.argument<Boolean>("pinOnly") ?: true
                    if (secretB64.isNullOrBlank()) {
                        result.error("INVALID_SECRET", "Secreto vacío", null)
                        return@setMethodCallHandler
                    }
                    wrapVaultKeyHardware(secretB64, pinOnly, result)
                }

                "unwrapVaultKeyWithDeviceCredential" -> {
                    val ivB64 = call.argument<String>("ivB64")
                    val cipherB64 = call.argument<String>("cipherB64")
                    val pinOnly = call.argument<Boolean>("pinOnly") ?: true
                    if (ivB64.isNullOrBlank() || cipherB64.isNullOrBlank()) {
                        result.error("INVALID_CIPHERTEXT", "Faltan IV o ciphertext", null)
                        return@setMethodCallHandler
                    }
                    unwrapVaultKeyHardware(ivB64, cipherB64, pinOnly, result)
                }

                "authenticateBiometricStep" -> {
                    val title = call.argument<String>("title") ?: "Verificación Biométrica (2FA)"
                    val subtitle = call.argument<String>("subtitle") ?: "Confirma tu huella dactilar para abrir la Bóveda"
                    authenticateBiometricOnly(title, subtitle, result)
                }

                "deleteHardwareVaultKey" -> {
                    try {
                        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                        if (ks.containsAlias(KEYSTORE_ALIAS)) {
                            ks.deleteEntry(KEYSTORE_ALIAS)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // =========================================================================
    // SECCIÓN 5: ANDROID KEYSTORE + BIOMETRICPROMPT (PIN DEL DISPOSITIVO)
    // =========================================================================
    private fun getOrCreateHardwareKey(forceRecreate: Boolean = false): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (forceRecreate && ks.containsAlias(KEYSTORE_ALIAS)) {
            ks.deleteEntry(KEYSTORE_ALIAS)
        }
        if (ks.containsAlias(KEYSTORE_ALIAS)) {
            val existing = ks.getKey(KEYSTORE_ALIAS, null) as? SecretKey
            if (existing != null) return existing
        }

        val keyGen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val builder = KeyGenParameterSpec.Builder(
            KEYSTORE_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_DEVICE_CREDENTIAL or KeyProperties.AUTH_BIOMETRIC_STRONG
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(15)
        }

        keyGen.init(builder.build())
        return keyGen.generateKey()
    }

    private fun buildAuthenticators(pinOnly: Boolean): Int {
        return if (pinOnly) {
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        } else {
            BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL
        }
    }

    private fun authenticateBiometricOnly(title: String, subtitle: String, result: MethodChannel.Result) {
        try {
            val executor = ContextCompat.getMainExecutor(this)
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle(title)
                .setSubtitle(subtitle)
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("Cancelar")
                .build()

            isZkpPromptActive = true
            val prompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    isZkpPromptActive = false
                    result.success(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    isZkpPromptActive = false
                    result.error("BIO_ERROR_$errorCode", errString.toString(), null)
                }
            })
            prompt.authenticate(promptInfo)
        } catch (e: Exception) {
            isZkpPromptActive = false
            result.error("BIO_UNAVAILABLE", e.localizedMessage, null)
        }
    }

    private fun wrapVaultKeyHardware(secretB64: String, pinOnly: Boolean, result: MethodChannel.Result) {
        try {
            val secretKey = getOrCreateHardwareKey(forceRecreate = true)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)

            val executor = ContextCompat.getMainExecutor(this)
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Sellar Bóveda ZKP")
                .setSubtitle(
                    if (pinOnly) "Introduce el PIN, patrón o contraseña de tu dispositivo"
                    else "Verifica tu identidad o PIN del dispositivo"
                )
                .setAllowedAuthenticators(buildAuthenticators(pinOnly))
                .build()

            isZkpPromptActive = true
            val prompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    isZkpPromptActive = false
                    try {
                        val activeCipher = authResult.cryptoObject?.cipher ?: cipher
                        val rawBytes = Base64.decode(secretB64, Base64.NO_WRAP)
                        val encrypted = activeCipher.doFinal(rawBytes)
                        val ivB64 = Base64.encodeToString(activeCipher.iv, Base64.NO_WRAP)
                        val cipherB64 = Base64.encodeToString(encrypted, Base64.NO_WRAP)
                        rawBytes.fill(0)
                        result.success(mapOf("ivB64" to ivB64, "cipherB64" to cipherB64))
                    } catch (e: Exception) {
                        result.error("KEYSTORE_ENCRYPT_FAIL", e.localizedMessage, null)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    isZkpPromptActive = false
                    result.error("AUTH_ERROR_$errorCode", errString.toString(), null)
                }
            })

            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
        } catch (e: Exception) {
            isZkpPromptActive = false
            result.error("KEYSTORE_SETUP_ERROR", e.localizedMessage, null)
        }
    }

    private fun unwrapVaultKeyHardware(
        ivB64: String,
        cipherB64: String,
        pinOnly: Boolean,
        result: MethodChannel.Result
    ) {
        try {
            val secretKey = getOrCreateHardwareKey(forceRecreate = false)
            val iv = Base64.decode(ivB64, Base64.NO_WRAP)
            val cipherBytes = Base64.decode(cipherB64, Base64.NO_WRAP)

            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(128, iv))

            val executor = ContextCompat.getMainExecutor(this)
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Desbloquear Bóveda ZKP")
                .setSubtitle(
                    if (pinOnly) "Introduce el PIN o patrón de tu dispositivo (sin biometría)"
                    else "Autentícate con biometría o PIN del dispositivo"
                )
                .setAllowedAuthenticators(buildAuthenticators(pinOnly))
                .build()

            isZkpPromptActive = true
            val prompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    isZkpPromptActive = false
                    try {
                        val activeCipher = authResult.cryptoObject?.cipher ?: cipher
                        val decrypted = activeCipher.doFinal(cipherBytes)
                        val outB64 = Base64.encodeToString(decrypted, Base64.NO_WRAP)
                        decrypted.fill(0)
                        result.success(outB64)
                    } catch (e: Exception) {
                        result.error("KEYSTORE_DECRYPT_FAIL", e.localizedMessage, null)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    isZkpPromptActive = false
                    result.error("AUTH_ERROR_$errorCode", errString.toString(), null)
                }
            })

            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
        } catch (e: Exception) {
            isZkpPromptActive = false
            result.error("KEYSTORE_UNLOCK_ERROR", e.localizedMessage, null)
        }
    }

    // =========================================================================
    // SECCIÓN 6: UTILIDADES DE LIMPIEZA Y VERIFICACIÓN DE ACCESIBILIDAD
    // =========================================================================
    private fun clearSilentSosNotification() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(VinkiarSosAccessibilityService.SILENT_NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "${packageName}/${VinkiarSosAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.split(":").any { it.equals(expectedService, ignoreCase = true) }
    }
}