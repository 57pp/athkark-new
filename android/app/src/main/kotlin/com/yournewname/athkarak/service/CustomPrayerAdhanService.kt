package com.yournewname.athkarak.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import java.io.IOException

class CustomPrayerAdhanService : Service() {

    private val binder = LocalBinder()
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var currentPrayerId: String? = null
    private var currentPrayerName: String? = null
    private var isPlaying = false

    companion object {
        private const val CHANNEL_ID = "CUSTOM_PRAYER_ADHAN_CHANNEL"
        private const val CHANNEL_NAME = "أذان الصلاة المخصصة"
        private const val CHANNEL_DESCRIPTION = "تشغيل أذان الصلاة المخصصة في الخلفية"
        private const val NOTIFICATION_ID = 2001
        private const val SERVICE_CHANNEL = "custom_prayer_service_channel"

        private const val TAG = "CustomPrayerAdhanService"

        // Action constants for intent handling
        const val ACTION_START_CUSTOM_ADHAN = "START_CUSTOM_ADHAN"
        const val ACTION_STOP_CUSTOM_ADHAN = "STOP_CUSTOM_ADHAN"
        const val EXTRA_PRAYER_ID = "prayerId"
        const val EXTRA_PRAYER_NAME = "prayerName"
        const val EXTRA_ADHAN_FILE = "adhanFile"

        fun startCustomPrayerAdhanService(context: Context, prayerId: String, prayerName: String, adhanFile: String = "adhan.mp3") {
            val intent = Intent(context, CustomPrayerAdhanService::class.java).apply {
                action = ACTION_START_CUSTOM_ADHAN
                putExtra(EXTRA_PRAYER_ID, prayerId)
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_ADHAN_FILE, adhanFile)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopCustomPrayerAdhanService(context: Context) {
            val intent = Intent(context, CustomPrayerAdhanService::class.java).apply {
                action = ACTION_STOP_CUSTOM_ADHAN
            }
            context.stopService(intent)
        }
    }

    inner class LocalBinder : Binder() {
        fun getService(): CustomPrayerAdhanService = this@CustomPrayerAdhanService
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
        Log.d(TAG, "CustomPrayerAdhanService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CustomPrayerAdhanService onStartCommand called")

        val action = intent?.action
        val prayerId = intent?.getStringExtra(EXTRA_PRAYER_ID) ?: ""
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: ""
        val adhanFile = intent?.getStringExtra(EXTRA_ADHAN_FILE) ?: "adhan.mp3"

        when (action) {
            ACTION_START_CUSTOM_ADHAN -> {
                currentPrayerId = prayerId
                currentPrayerName = prayerName
                startForegroundWithNotification()
                playCustomPrayerAdhan(adhanFile)
            }
            ACTION_STOP_CUSTOM_ADHAN -> {
                stopCustomPrayerAdhanPlayback()
                stopSelf()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder = binder

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = CHANNEL_DESCRIPTION

                // Configure high priority notification channel for custom prayer alarms
                setSound(null, null) // Will be set on individual notifications
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)

                // Additional configuration for custom prayer alarms
                setBypassDnd(true) // Bypass Do Not Disturb mode
                setLockscreenVisibility(Notification.VISIBILITY_PUBLIC)

                Log.d(TAG, "Created notification channel with IMPORTANCE_MAX for custom prayer alarms")
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)

            Log.d(TAG, "Custom prayer notification channel created successfully")
        }
    }

    private fun startForegroundWithNotification() {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)

        // Start as foreground service with appropriate service type
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, FlutterActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, CustomPrayerAdhanService::class.java).apply {
            action = ACTION_STOP_CUSTOM_ADHAN
        }

        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("أذان الصلاة المخصصة")
            .setContentText("جاري تشغيل أذان ${currentPrayerName ?: "الصلاة"}")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX) // Changed to MAX for alarm
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL) // Sound, vibration, lights
            .setFullScreenIntent(pendingIntent, true) // Full screen intent for alarm
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(android.R.drawable.ic_media_pause, "إيقاف", stopPendingIntent)
            .build()
    }

    private fun requestAudioFocus(): Boolean {
        if (audioManager == null) return false

        return try {
            val audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )
                .setOnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            // Resume playback
                            mediaPlayer?.start()
                            Log.d(TAG, "Audio focus gained, resuming custom prayer playback")
                        }
                        AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                            // Pause or duck playback
                            mediaPlayer?.pause()
                            Log.d(TAG, "Audio focus lost or ducking")
                        }
                    }
                }
                .setAcceptsDelayedFocusGain(true)
                .build()

            this.audioFocusRequest = audioFocusRequest

            val result = audioManager?.requestAudioFocus(audioFocusRequest)
            result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED

        } catch (e: Exception) {
            Log.e(TAG, "Error requesting audio focus for custom prayer", e)
            false
        }
    }

    private fun playCustomPrayerAdhan(adhanFile: String) {
        if (isPlaying) {
            Log.d(TAG, "Custom prayer adhan is already playing")
            return
        }

        // Start foreground service notification first
        startForegroundWithNotification()

        try {
            if (!requestAudioFocus()) {
                Log.e(TAG, "Failed to get audio focus for custom prayer adhan")
                return
            }

            val resourceName = getResourceFileName(adhanFile)

            val player = MediaPlayer()
            mediaPlayer = player.apply {
                val dataSource = getAdhanDataSource(resourceName)
                setDataSource(dataSource)

                setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .build()
                )

                setOnPreparedListener {
                    Log.d(TAG, "Custom prayer MediaPlayer prepared, starting playback for: $resourceName")
                    player.start()
                    this@CustomPrayerAdhanService.isPlaying = true
                    updateNotification()
                }

                setOnCompletionListener {
                    Log.d(TAG, "Custom prayer adhan playback completed for: $resourceName")
                    this@CustomPrayerAdhanService.isPlaying = false
                    this@CustomPrayerAdhanService.stopCustomPrayerAdhanPlayback()
                }

                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Custom prayer MediaPlayer error for $resourceName: what=$what, extra=$extra")
                    this@CustomPrayerAdhanService.isPlaying = false
                    this@CustomPrayerAdhanService.stopCustomPrayerAdhanPlayback()
                    true
                }

                prepareAsync()
            }

            Log.d(TAG, "Starting custom prayer adhan playback from: $resourceName")

        } catch (e: Exception) {
            Log.e(TAG, "Error with custom prayer adhan playback from file: $adhanFile", e)
            stopCustomPrayerAdhanPlayback()
        }
    }

    private fun getResourceFileName(adhanFile: String): String {
        return try {
            adhanFile.substringBeforeLast('.')
        } catch (e: Exception) {
            Log.w(TAG, "Could not parse custom prayer adhan file name: $adhanFile, using default")
            "adhan"
        }
    }

    private fun getAdhanDataSource(resourceName: String): String {
        return "android.resource://${packageName}/raw/$resourceName"
    }

    private fun stopCustomPrayerAdhanPlayback() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null

            audioFocusRequest?.let {
                audioManager?.abandonAudioFocusRequest(it)
            }
            audioFocusRequest = null

            isPlaying = false
            Log.d(TAG, "Custom prayer adhan playback stopped")

            // Update notification to show stopped state
            updateNotification()

        } catch (e: Exception) {
            Log.e(TAG, "Error stopping custom prayer adhan", e)
        }
    }

    private fun updateNotification() {
        val notification = if (isPlaying) {
            createNotification()
        } else {
            // Completed notification with sound confirmation
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("انتهى أذان الصلاة المخصصة")
                .setContentText("تم الانتهاء من تشغيل أذان ${currentPrayerName ?: "الصلاة"}")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setOngoing(false)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setDefaults(NotificationCompat.DEFAULT_SOUND) // Sound confirmation for completion
                .setAutoCancel(true)
                .build()
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)

        // Auto-stop service after 10 seconds of completion
        if (!isPlaying) {
            android.os.Handler(mainLooper).postDelayed({
                if (!isPlaying) {
                    stopSelf()
                }
            }, 10000)
        }
    }

    fun stopService() {
        stopCustomPrayerAdhanPlayback()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopCustomPrayerAdhanPlayback()
        Log.d(TAG, "CustomPrayerAdhanService destroyed")
    }
}