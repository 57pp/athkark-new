package com.yournewname.athkarak.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import com.yournewname.athkarak.service.PrayerAdhanService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class PrayerAlarmReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra("alarmId") ?: ""
        val prayerName = intent.getStringExtra("prayerName") ?: ""
        val scheduledTime = intent.getLongExtra("scheduledTime", 0)
        
        Log.d(TAG, "Received alarm: $alarmId for prayer: $prayerName at time: $scheduledTime")
        
        // Record execution time for monitoring
        val executionTime = System.currentTimeMillis()
        val timeDifference = executionTime - scheduledTime
        
        Log.d(TAG, "Execution delay: ${timeDifference}ms (scheduled: $scheduledTime, executed: $executionTime)")
        
        // Start coroutine for background processing
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Check if alarm is still valid and not already executed
                if (!isAlarmValid(context, alarmId, scheduledTime)) {
                    Log.w(TAG, "Alarm $alarmId is no longer valid or already executed")
                    return@launch
                }
                
                // Update alarm status to "fired"
                updateAlarmStatus(context, alarmId, "fired", executionTime)
                
                // Log execution for monitoring
                logExecution(context, alarmId, prayerName, scheduledTime, executionTime, timeDifference)
                
                // Start ForegroundService to play adhan
                startPrayerAdhanService(context, alarmId, prayerName)
                
                Log.i(TAG, "Successfully handled alarm: $alarmId for prayer: $prayerName")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error handling alarm: $alarmId", e)
                
                // Mark alarm as failed
                updateAlarmStatus(context, alarmId, "failed", System.currentTimeMillis(), e.message)
            }
        }
    }
    
    private suspend fun isAlarmValid(context: Context, alarmId: String, scheduledTime: Long): Boolean {
        return try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val status = prefs.getString("$ALARM_STATUS_KEY.$alarmId", null)
            
            // Check if alarm exists and is scheduled
            if (status != "scheduled") {
                Log.w(TAG, "Alarm $alarmId status is not 'scheduled': $status")
                return false
            }
            
            // Check if alarm time has not passed too much (within 10 minutes tolerance)
            val currentTime = System.currentTimeMillis()
            val timeDiff = Math.abs(currentTime - scheduledTime)
            val maxTolerance = 10 * 60 * 1000 // 10 minutes in milliseconds
            
            if (timeDiff > maxTolerance && currentTime > scheduledTime) {
                Log.w(TAG, "Alarm $alarmId is too late: ${timeDiff}ms")
                return false
            }
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error checking alarm validity", e)
            false
        }
    }
    
    private suspend fun updateAlarmStatus(
        context: Context, 
        alarmId: String, 
        status: String, 
        timestamp: Long,
        errorMessage: String? = null
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val editor = prefs.edit()
            
            editor.putString("$ALARM_STATUS_KEY.$alarmId", status)
            editor.putLong("$ALARM_STATUS_KEY.$alarmId.timestamp", timestamp)
            
            if (errorMessage != null) {
                editor.putString("$ALARM_STATUS_KEY.$alarmId.error", errorMessage)
            }
            
            editor.apply()
            
            Log.d(TAG, "Updated alarm $alarmId status to: $status")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error updating alarm status", e)
        }
    }
    
    private suspend fun logExecution(
        context: Context,
        alarmId: String,
        prayerName: String,
        scheduledTime: Long,
        executionTime: Long,
        timeDifference: Long
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingLog = prefs.getString(EXECUTION_LOG_KEY, "[]")
            
            val logArray = JSONArray(existingLog)
            val logEntry = JSONObject().apply {
                put("alarmId", alarmId)
                put("prayerName", prayerName)
                put("scheduledTime", scheduledTime)
                put("executionTime", executionTime)
                put("timeDifference", timeDifference)
                put("timestamp", System.currentTimeMillis())
            }
            
            logArray.put(logEntry)
            
            // Keep only last 100 entries
            if (logArray.length() > 100) {
                val newArray = JSONArray()
                for (i in logArray.length() - 100 until logArray.length()) {
                    newArray.put(logArray.getJSONObject(i))
                }
                prefs.edit().putString(EXECUTION_LOG_KEY, newArray.toString()).apply()
            } else {
                prefs.edit().putString(EXECUTION_LOG_KEY, logArray.toString()).apply()
            }
            
            Log.d(TAG, "Execution logged: ${timeDifference}ms delay for $prayerName")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error logging execution", e)
        }
    }
    
    private suspend fun startPrayerAdhanService(context: Context, alarmId: String, prayerName: String) {
        try {
            // Determine adhan file based on prayer
            val adhanFile = getAdhanFileForPrayer(prayerName)
            
            // Start the foreground service
            PrayerAdhanService.startAdhanService(context, alarmId, adhanFile)
            
            Log.i(TAG, "Started PrayerAdhanService for $prayerName with adhan file: $adhanFile")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting PrayerAdhanService", e)
            throw e
        }
    }
    
    private fun getAdhanFileForPrayer(prayerName: String): String {
        return when (prayerName.lowercase()) {
            "fajr", "الفجر" -> "adhan_fajr.mp3"
            "dhuhr", "الظهر" -> "adhan_dhuhr.mp3"
            "asr", "العصر" -> "adhan_asr.mp3"
            "maghrib", "المغرب" -> "adhan_maghrib.mp3"
            "isha", "العشاء" -> "adhan_isha.mp3"
            else -> "adhan.mp3"
        }
    }
    
    companion object {
        private const val TAG = "PrayerAlarmReceiver"
        private const val PREFS_NAME = "prayer_alarm_prefs"
        private const val SCHEDULED_ALARMS_KEY = "scheduled_alarms"
        private const val ALARM_STATUS_KEY = "alarm_status"
        private const val EXECUTION_LOG_KEY = "execution_log"
        
        fun scheduleAlarm(
            context: Context,
            alarmId: String,
            prayerName: String,
            scheduledTime: Long
        ): Boolean {
            return try {
                val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                    action = "com.yournewname.athkarak.SCHEDULE_PRAYER_ALARM"
                    putExtra("alarmId", alarmId)
                    putExtra("prayerName", prayerName)
                    putExtra("scheduledTime", scheduledTime)
                }
                
                val pendingIntent = android.app.PendingIntent.getBroadcast(
                    context,
                    alarmId.hashCode(),
                    intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                
                // Check if exact alarm permission is granted
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    if (!alarmManager.canScheduleExactAlarms()) {
                        Log.e(TAG, "Cannot schedule exact alarms - permission not granted")
                        return false
                    }
                }
                
                // Schedule with exact timing and allow while idle for Android 6.0+
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        android.app.AlarmManager.RTC_WAKEUP,
                        scheduledTime,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        android.app.AlarmManager.RTC_WAKEUP,
                        scheduledTime,
                        pendingIntent
                    )
                }
                
                // Update status in SharedPreferences
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("$ALARM_STATUS_KEY.$alarmId", "scheduled")
                    .putLong("$ALARM_STATUS_KEY.$alarmId.scheduledTime", scheduledTime)
                    .apply()
                
                Log.d(TAG, "Scheduled alarm: $alarmId for $prayerName at ${Date(scheduledTime)}")
                true
                
            } catch (e: Exception) {
                Log.e(TAG, "Error scheduling alarm: $alarmId", e)
                false
            }
        }
        
        fun cancelAlarm(context: Context, alarmId: String): Boolean {
            return try {
                val intent = Intent(context, PrayerAlarmReceiver::class.java)
                val pendingIntent = android.app.PendingIntent.getBroadcast(
                    context,
                    alarmId.hashCode(),
                    intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                alarmManager.cancel(pendingIntent)
                
                // Update status
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("$ALARM_STATUS_KEY.$alarmId", "cancelled")
                    .putLong("$ALARM_STATUS_KEY.$alarmId.cancelledTime", System.currentTimeMillis())
                    .apply()
                
                Log.d(TAG, "Cancelled alarm: $alarmId")
                true
                
            } catch (e: Exception) {
                Log.e(TAG, "Error cancelling alarm: $alarmId", e)
                false
            }
        }
        
        fun getAlarmStatus(context: Context, alarmId: String): Map<String, Any?> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return mapOf(
                "status" to prefs.getString("$ALARM_STATUS_KEY.$alarmId", null),
                "scheduledTime" to prefs.getLong("$ALARM_STATUS_KEY.$alarmId.scheduledTime", 0),
                "timestamp" to prefs.getLong("$ALARM_STATUS_KEY.$alarmId.timestamp", 0),
                "error" to prefs.getString("$ALARM_STATUS_KEY.$alarmId.error", null)
            )
        }
        
        fun getExecutionLog(context: Context): List<Map<String, Any>> {
            return try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val logString = prefs.getString(EXECUTION_LOG_KEY, "[]")
                val logArray = JSONArray(logString)
                
                val logList = mutableListOf<Map<String, Any>>()
                for (i in 0 until logArray.length()) {
                    val entry = logArray.getJSONObject(i)
                    logList.add(
                        mapOf(
                            "alarmId" to entry.getString("alarmId"),
                            "prayerName" to entry.getString("prayerName"),
                            "scheduledTime" to entry.getLong("scheduledTime"),
                            "executionTime" to entry.getLong("executionTime"),
                            "timeDifference" to entry.getLong("timeDifference"),
                            "timestamp" to entry.getLong("timestamp")
                        )
                    )
                }
                logList
            } catch (e: Exception) {
                Log.e(TAG, "Error getting execution log", e)
                emptyList()
            }
        }
    }
}