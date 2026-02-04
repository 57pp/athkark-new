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
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class PrayerAdhanService : Service() {
    
    private val binder = LocalBinder()
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var currentPrayerId: String? = null
    private var isPlaying = false
    
    companion object {
        private const val CHANNEL_ID = "PRAYER_ADHAN_CHANNEL"
        private const val CHANNEL_NAME = "تشغيل الأذان"
        private const val CHANNEL_DESCRIPTION = "تشغيل أوقات الصلاة في الخلفية"
        private const val NOTIFICATION_ID = 1001
        private const val SERVICE_CHANNEL = "prayer_service_channel"
        
        private const val METHOD_CHANNEL = "prayer_adan_service"
        private const val START_SERVICE = "startService"
        private const val STOP_SERVICE = "stopService"
        private const val IS_PLAYING = "isPlaying"
        
        private const val TAG = "PrayerAdhanService"
        
        // Action constants for intent handling
        const val ACTION_START_ADHAN = "START_ADHAN"
        const val ACTION_STOP_ADHAN = "STOP_ADHAN"
        const val EXTRA_PRAYER_ID = "prayerId"
        const val EXTRA_ADHAN_FILE = "adhanFile"
        
        // Delegate to Flutter for adhan audio files
        private var flutterEngine: FlutterEngine? = null
        private var methodChannel: MethodChannel? = null
        
        fun initializeFlutterChannel(flutterEngine: FlutterEngine) {
            this.flutterEngine = flutterEngine
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    START_SERVICE -> {
                        val prayerId = call.argument<String>("prayerId") ?: ""
                        val adhanFile = call.argument<String>("adhanFile") ?: ""
                        result.success(startServiceInternal(prayerId, adhanFile))
                    }
                    STOP_SERVICE -> {
                        result.success(stopServiceInternal())
                    }
                    IS_PLAYING -> {
                        result.success(isCurrentlyPlaying())
                    }
                    "playAdhan" -> {
                        val prayerId = call.argument<String>("prayerId") ?: ""
                        val adhanFile = call.argument<String>("adhanFile") ?: ""
                        val isScheduled = call.argument<Boolean>("isScheduled") ?: false
                        result.success(handlePlayAdhan(prayerId, adhanFile, isScheduled))
                    }
                    "stopAdhan" -> {
                        result.success(handleStopAdhan())
                    }
                    else -> result.notImplemented()
                }
            }
        }
        
        private fun startServiceInternal(prayerId: String, adhanFile: String): Boolean {
            // This will be called from Flutter native code
            return try {
                Log.d(TAG, "Starting adhan service for prayer: $prayerId, file: $adhanFile")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start service", e)
                false
            }
        }
        
        private fun stopServiceInternal(): Boolean {
            return true
        }
        
        private fun handlePlayAdhan(prayerId: String, adhanFile: String, isScheduled: Boolean): Boolean {
            return try {
                Log.d(TAG, "Handling adhan play request for: $prayerId, file: $adhanFile, scheduled: $isScheduled")
                // This will be handled by the Flutter service
                true
            } catch (e: Exception) {
                Log.e(TAG, "Error handling adhan play", e)
                false
            }
        }
        
        private fun handleStopAdhan(): Boolean {
            return try {
                Log.d(TAG, "Handling adhan stop request")
                // This will be handled by the Flutter service
                true
            } catch (e: Exception) {
                Log.e(TAG, "Error handling adhan stop", e)
                false
            }
        }
        
        private fun isCurrentlyPlaying(): Boolean {
            return false
        }
        
        fun startAdhanService(context: Context, prayerId: String, adhanFile: String = "adhan.mp3") {
            val intent = Intent(context, PrayerAdhanService::class.java).apply {
                action = ACTION_START_ADHAN
                putExtra(EXTRA_PRAYER_ID, prayerId)
                putExtra(EXTRA_ADHAN_FILE, adhanFile)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopAdhanService(context: Context) {
            val intent = Intent(context, PrayerAdhanService::class.java).apply {
                action = ACTION_STOP_ADHAN
            }
            context.stopService(intent)
        }
    }
    
    inner class LocalBinder : Binder() {
        fun getService(): PrayerAdhanService = this@PrayerAdhanService
    }
    
    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
        Log.d(TAG, "PrayerAdhanService created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called")
        
        val action = intent?.action
        val prayerId = intent?.getStringExtra("prayerId") ?: ""
        val adhanFile = intent?.getStringExtra("adhanFile") ?: "adhan.mp3"
        
        when (action) {
            ACTION_START_ADHAN -> {
                currentPrayerId = prayerId
                startForegroundWithNotification()
                playAdhan(adhanFile)
            }
            ACTION_STOP_ADHAN -> {
                stopAdhanPlayback()
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
                
                // Configure high priority notification channel for alarms
                setSound(null, null) // Will be set on individual notifications
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                
                // Additional configuration for prayer alarms
                setBypassDnd(true) // Bypass Do Not Disturb mode
                setLockscreenVisibility(Notification.VISIBILITY_PUBLIC)
                
                Log.d(TAG, "Created notification channel with IMPORTANCE_MAX for prayer alarms")
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "Prayer notification channel created successfully")
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
        
        val stopIntent = Intent(this, PrayerAdhanService::class.java).apply {
            action = ACTION_STOP_ADHAN
        }
        
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("تشغيل الأذان")
            .setContentText("جاري تشغيل أذان الصلاة")
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
                            Log.d(TAG, "Audio focus gained, resuming playback")
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
            Log.e(TAG, "Error requesting audio focus", e)
            false
        }
    }
    
    private fun playAdhan(adhanFile: String) {
        if (isPlaying) {
            Log.d(TAG, "Adhan is already playing")
            return
        }
        
        // Start foreground service notification first
        startForegroundWithNotification()
        
        try {
            // Delegate to Flutter through method channel instead of direct MediaPlayer
            if (methodChannel != null && flutterEngine != null) {
                Log.d(TAG, "Delegating adhan playback to Flutter: $adhanFile")
                
                // Notify Flutter to start playing
                methodChannel?.invokeMethod("playAdhan", mapOf(
                    "prayerId" to currentPrayerId,
                    "adhanFile" to adhanFile,
                    "isScheduled" to true
                ), object : io.flutter.plugin.common.MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (result == true) {
                            Log.d(TAG, "Flutter successfully started adhan playback")
                            isPlaying = true
                            updateNotification()
                        } else {
                            Log.w(TAG, "Flutter failed to start adhan playback, falling back to direct playback")
                            playAdhanDirectly(adhanFile)
                        }
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e(TAG, "Flutter method call error: $errorCode - $errorMessage")
                        playAdhanDirectly(adhanFile)
                    }

                    override fun notImplemented() {
                        Log.w(TAG, "Flutter method not implemented, falling back to direct playback")
                        playAdhanDirectly(adhanFile)
                    }
                })
            } else {
                Log.w(TAG, "Method channel not available, using direct playback fallback")
                playAdhanDirectly(adhanFile)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error delegating adhan to Flutter: $e")
            playAdhanDirectly(adhanFile)
        }
    }
    
    private fun playAdhanDirectly(adhanFile: String) {
        if (!requestAudioFocus()) {
            Log.e(TAG, "Failed to get audio focus")
            return
        }
        
        try {
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
                    Log.d(TAG, "Direct MediaPlayer prepared, starting playback for: $resourceName")
                    player.start()
                    this@PrayerAdhanService.isPlaying = true
                    this@PrayerAdhanService.updateNotification()
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "Direct adhan playback completed for: $resourceName")
                    this@PrayerAdhanService.isPlaying = false
                    this@PrayerAdhanService.stopAdhanPlayback()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Direct MediaPlayer error for $resourceName: what=$what, extra=$extra")
                    this@PrayerAdhanService.isPlaying = false
                    this@PrayerAdhanService.stopAdhanPlayback()
                    true
                }
                
                prepareAsync()
            }
            
            Log.d(TAG, "Starting direct adhan playback from: $resourceName")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error with direct adhan playback from file: $adhanFile", e)
            stopAdhanPlayback()
        }
    }
    
    private fun getResourceFileName(adhanFile: String): String {
        return try {
            adhanFile.substringBeforeLast('.')
        } catch (e: Exception) {
            Log.w(TAG, "Could not parse adhan file name: $adhanFile, using default")
            "adhan"
        }
    }
    
    private fun getAdhanDataSource(resourceName: String): String {
        return "android.resource://${packageName}/raw/$resourceName"
    }
    
    private fun stopAdhanPlayback() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
            
            audioFocusRequest?.let {
                audioManager?.abandonAudioFocusRequest(it)
            }
            audioFocusRequest = null
            
            isPlaying = false
            Log.d(TAG, "Adhan playback stopped")
            
            // Update notification to show stopped state
            updateNotification()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping adhan", e)
        }
    }
    
    private fun updateNotification() {
        val notification = if (isPlaying) {
            createNotification()
        } else {
            // Completed notification with sound confirmation
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("انتهى الأذان")
                .setContentText("تم الانتهاء من تشغيل أذان الصلاة")
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
        stopAdhanPlayback()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopAdhanPlayback()
        Log.d(TAG, "PrayerAdhanService destroyed")
    }
}