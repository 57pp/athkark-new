package com.yournewname.athkarak.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import com.yournewname.athkarak.service.CustomPrayerAdhanService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class CustomPrayerAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val prayerId = intent.getStringExtra("prayerId") ?: ""
        val prayerName = intent.getStringExtra("prayerName") ?: ""
        val scheduledTime = intent.getLongExtra("scheduledTime", 0)

        Log.d(TAG, "Custom prayer alarm received: $prayerId for prayer: $prayerName at time: $scheduledTime")

        // Record execution time for monitoring
        val executionTime = System.currentTimeMillis()
        val timeDifference = executionTime - scheduledTime

        Log.d(TAG, "Custom prayer execution delay: ${timeDifference}ms")

        // Start coroutine for background processing
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Check if alarm is still valid
                if (!isCustomPrayerAlarmValid(context, prayerId, scheduledTime)) {
                    Log.w(TAG, "Custom prayer alarm $prayerId is no longer valid")
                    return@launch
                }

                // Update alarm status
                updateCustomPrayerAlarmStatus(context, prayerId, "fired", executionTime)

                // Log execution
                logCustomPrayerExecution(context, prayerId, prayerName, scheduledTime, executionTime, timeDifference)

                // Start Custom Prayer Adhan Service
                startCustomPrayerAdhanService(context, prayerId, prayerName)

                Log.i(TAG, "Successfully handled custom prayer alarm: $prayerId for prayer: $prayerName")

            } catch (e: Exception) {
                Log.e(TAG, "Error handling custom prayer alarm: $prayerId", e)
                updateCustomPrayerAlarmStatus(context, prayerId, "failed", System.currentTimeMillis(), e.message)
            }
        }
    }

    private suspend fun isCustomPrayerAlarmValid(context: Context, prayerId: String, scheduledTime: Long): Boolean {
        return try {
            val prefs = context.getSharedPreferences(CUSTOM_PRAYER_PREFS_NAME, Context.MODE_PRIVATE)
            val status = prefs.getString("$CUSTOM_ALARM_STATUS_KEY.$prayerId", null)

            if (status != "scheduled") {
                Log.w(TAG, "Custom prayer alarm $prayerId status is not 'scheduled': $status")
                return false
            }

            // Check time tolerance (within 10 minutes)
            val currentTime = System.currentTimeMillis()
            val timeDiff = Math.abs(currentTime - scheduledTime)
            val maxTolerance = 10 * 60 * 1000 // 10 minutes

            if (timeDiff > maxTolerance && currentTime > scheduledTime) {
                Log.w(TAG, "Custom prayer alarm $prayerId is too late: ${timeDiff}ms")
                return false
            }

            true
        } catch (e: Exception) {
            Log.e(TAG, "Error checking custom prayer alarm validity", e)
            false
        }
    }

    private suspend fun updateCustomPrayerAlarmStatus(
        context: Context,
        prayerId: String,
        status: String,
        timestamp: Long,
        errorMessage: String? = null
    ) {
        try {
            val prefs = context.getSharedPreferences(CUSTOM_PRAYER_PREFS_NAME, Context.MODE_PRIVATE)
            val editor = prefs.edit()

            editor.putString("$CUSTOM_ALARM_STATUS_KEY.$prayerId", status)
            editor.putLong("$CUSTOM_ALARM_STATUS_KEY.$prayerId.timestamp", timestamp)

            if (errorMessage != null) {
                editor.putString("$CUSTOM_ALARM_STATUS_KEY.$prayerId.error", errorMessage)
            }

            editor.apply()

            Log.d(TAG, "Updated custom prayer alarm $prayerId status to: $status")

        } catch (e: Exception) {
            Log.e(TAG, "Error updating custom prayer alarm status", e)
        }
    }

    private suspend fun logCustomPrayerExecution(
        context: Context,
        prayerId: String,
        prayerName: String,
        scheduledTime: Long,
        executionTime: Long,
        timeDifference: Long
    ) {
        try {
            val prefs = context.getSharedPreferences(CUSTOM_PRAYER_PREFS_NAME, Context.MODE_PRIVATE)
            val existingLog = prefs.getString(CUSTOM_EXECUTION_LOG_KEY, "[]")

            val logArray = JSONArray(existingLog)
            val logEntry = JSONObject().apply {
                put("prayerId", prayerId)
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
                prefs.edit().putString(CUSTOM_EXECUTION_LOG_KEY, newArray.toString()).apply()
            } else {
                prefs.edit().putString(CUSTOM_EXECUTION_LOG_KEY, logArray.toString()).apply()
            }

            Log.d(TAG, "Custom prayer execution logged: ${timeDifference}ms delay for $prayerName")

        } catch (e: Exception) {
            Log.e(TAG, "Error logging custom prayer execution", e)
        }
    }

    private suspend fun startCustomPrayerAdhanService(context: Context, prayerId: String, prayerName: String) {
        try {
            // Determine adhan file based on prayer
            val adhanFile = getAdhanFileForCustomPrayer(prayerName)

            // Start the custom prayer adhan service
            CustomPrayerAdhanService.startCustomPrayerAdhanService(context, prayerId, prayerName, adhanFile)

            Log.i(TAG, "Started CustomPrayerAdhanService for $prayerName with adhan file: $adhanFile")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting CustomPrayerAdhanService", e)
            throw e
        }
    }

    private fun getAdhanFileForCustomPrayer(prayerName: String): String {
        return when (prayerName.lowercase()) {
            "الفجر", "fajr" -> "adhan_fajr.mp3"
            "الظهر", "dhuhr" -> "adhan_dhuhr.mp3"
            "العصر", "asr" -> "adhan_asr.mp3"
            "المغرب", "maghrib" -> "adhan_maghrib.mp3"
            "العشاء", "isha" -> "adhan_isha.mp3"
            "الوتر", "witr" -> "adhan.mp3"
            else -> "adhan.mp3"
        }
    }

    companion object {
        private const val TAG = "CustomPrayerAlarmReceiver"
        private const val CUSTOM_PRAYER_PREFS_NAME = "custom_prayer_alarm_prefs"
        private const val CUSTOM_ALARM_STATUS_KEY = "custom_alarm_status"
        private const val CUSTOM_EXECUTION_LOG_KEY = "custom_execution_log"

        fun scheduleCustomPrayerAlarm(
            context: Context,
            prayerId: String,
            prayerName: String,
            scheduledTime: Long
        ): Boolean {
            return try {
                val intent = Intent(context, CustomPrayerAlarmReceiver::class.java).apply {
                    action = "com.yournewname.athkarak.SCHEDULE_CUSTOM_PRAYER_ALARM"
                    putExtra("prayerId", prayerId)
                    putExtra("prayerName", prayerName)
                    putExtra("scheduledTime", scheduledTime)
                }

                val pendingIntent = android.app.PendingIntent.getBroadcast(
                    context,
                    prayerId.hashCode(),
                    intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager

                // Check exact alarm permission
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    if (!alarmManager.canScheduleExactAlarms()) {
                        Log.e(TAG, "Cannot schedule exact custom prayer alarms - permission not granted")
                        return false
                    }
                }

                // Schedule with exact timing
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
                val prefs = context.getSharedPreferences(CUSTOM_PRAYER_PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("$CUSTOM_ALARM_STATUS_KEY.$prayerId", "scheduled")
                    .putLong("$CUSTOM_ALARM_STATUS_KEY.$prayerId.scheduledTime", scheduledTime)
                    .apply()

                Log.d(TAG, "Scheduled custom prayer alarm: $prayerId for $prayerName at ${Date(scheduledTime)}")
                true

            } catch (e: Exception) {
                Log.e(TAG, "Error scheduling custom prayer alarm: $prayerId", e)
                false
            }
        }

        fun cancelCustomPrayerAlarm(context: Context, prayerId: String): Boolean {
            return try {
                val intent = Intent(context, CustomPrayerAlarmReceiver::class.java)
                val pendingIntent = android.app.PendingIntent.getBroadcast(
                    context,
                    prayerId.hashCode(),
                    intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                alarmManager.cancel(pendingIntent)

                // Update status
                val prefs = context.getSharedPreferences(CUSTOM_PRAYER_PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("$CUSTOM_ALARM_STATUS_KEY.$prayerId", "cancelled")
                    .putLong("$CUSTOM_ALARM_STATUS_KEY.$prayerId.cancelledTime", System.currentTimeMillis())
                    .apply()

                Log.d(TAG, "Cancelled custom prayer alarm: $prayerId")
                true

            } catch (e: Exception) {
                Log.e(TAG, "Error cancelling custom prayer alarm: $prayerId", e)
                false
            }
        }

        fun getCustomPrayerAlarmStatus(context: Context, prayerId: String): Map<String, Any?> {
            val prefs = context.getSharedPreferences(CUSTOM_PRAYER_PREFS_NAME, Context.MODE_PRIVATE)
            return mapOf(
                "status" to prefs.getString("$CUSTOM_ALARM_STATUS_KEY.$prayerId", null),
                "scheduledTime" to prefs.getLong("$CUSTOM_ALARM_STATUS_KEY.$prayerId.scheduledTime", 0),
                "timestamp" to prefs.getLong("$CUSTOM_ALARM_STATUS_KEY.$prayerId.timestamp", 0),
                "error" to prefs.getString("$CUSTOM_ALARM_STATUS_KEY.$prayerId.error", null)
            )
        }

        fun getCustomPrayerExecutionLog(context: Context): List<Map<String, Any>> {
            return try {
                val prefs = context.getSharedPreferences(CUSTOM_PRAYER_PREFS_NAME, Context.MODE_PRIVATE)
                val logString = prefs.getString(CUSTOM_EXECUTION_LOG_KEY, "[]")
                val logArray = JSONArray(logString)

                val logList = mutableListOf<Map<String, Any>>()
                for (i in 0 until logArray.length()) {
                    val entry = logArray.getJSONObject(i)
                    logList.add(
                        mapOf(
                            "prayerId" to entry.getString("prayerId"),
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
                Log.e(TAG, "Error getting custom prayer execution log", e)
                emptyList()
            }
        }
    }
}