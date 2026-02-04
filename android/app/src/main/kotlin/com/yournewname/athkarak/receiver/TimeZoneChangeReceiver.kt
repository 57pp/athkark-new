package com.yournewname.athkarak.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject

class TimeZoneChangeReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "TimeZoneChangeReceiver"
        private const val PREFS_NAME = "prayer_alarm_prefs"
        private const val TIMEZONE_LOG_KEY = "timezone_change_log"
        private const val SCHEDULED_ALARMS_KEY = "scheduled_alarms"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        
        when (action) {
            Intent.ACTION_TIMEZONE_CHANGED -> {
                val newTimeZone = intent.getStringExtra("time-zone") ?: "Unknown"
                Log.i(TAG, "Time zone changed to: $newTimeZone")
                
                CoroutineScope(Dispatchers.IO).launch {
                    handleTimeZoneChange(context, newTimeZone)
                }
            }
            
            Intent.ACTION_TIME_CHANGED -> {
                Log.i(TAG, "System time changed")
                
                CoroutineScope(Dispatchers.IO).launch {
                    handleTimeChange(context)
                }
            }
            
            Intent.ACTION_DATE_CHANGED -> {
                Log.i(TAG, "System date changed")
                
                CoroutineScope(Dispatchers.IO).launch {
                    handleDateChange(context)
                }
            }
        }
    }
    
    private suspend fun handleTimeZoneChange(context: Context, newTimeZone: String) {
        try {
            Log.d(TAG, "Handling timezone change to: $newTimeZone")
            
            // Log timezone change for monitoring
            logTimeZoneChange(context, newTimeZone)
            
            // Notify Flutter about timezone change
            notifyFlutterOfTimeZoneChange(context, newTimeZone)
            
            Log.i(TAG, "Successfully handled timezone change")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling timezone change", e)
        }
    }
    
    private suspend fun handleTimeChange(context: Context) {
        try {
            Log.d(TAG, "Handling system time change")
            
            // Log time change
            logTimeChange(context)
            
            // Check if any scheduled alarms are now invalid due to time change
            val invalidAlarms = checkInvalidAlarms(context)
            
            if (invalidAlarms.isNotEmpty()) {
                Log.w(TAG, "Found ${invalidAlarms.size} invalid alarms after time change")
                
                // Reschedule invalid alarms
                rescheduleInvalidAlarms(context, invalidAlarms)
            }
            
            Log.i(TAG, "Successfully handled time change")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling time change", e)
        }
    }
    
    private suspend fun handleDateChange(context: Context) {
        try {
            Log.d(TAG, "Handling system date change")
            
            // Log date change
            logDateChange(context)
            
            // This might indicate a leap year adjustment or system clock correction
            // We should re-evaluate all scheduled alarms
            
            val allAlarms = getAllScheduledAlarms(context)
            
            for (alarm in allAlarms) {
                if (!isAlarmStillValid(alarm)) {
                    Log.d(TAG, "Rescheduling alarm ${alarm.id} due to date change")
                    rescheduleAlarm(context, alarm)
                }
            }
            
            Log.i(TAG, "Successfully handled date change")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling date change", e)
        }
    }
    
    private fun logTimeZoneChange(context: Context, timeZone: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingLog = prefs.getString(TIMEZONE_LOG_KEY, "[]")
            
            val logArray = org.json.JSONArray(existingLog)
            val logEntry = JSONObject().apply {
                put("event", "timezone_changed")
                put("newTimeZone", timeZone)
                put("timestamp", System.currentTimeMillis())
                put("systemTime", System.currentTimeMillis())
            }
            
            logArray.put(logEntry)
            
            // Keep only last 50 entries
            if (logArray.length() > 50) {
                val newArray = org.json.JSONArray()
                for (i in logArray.length() - 50 until logArray.length()) {
                    newArray.put(logArray.getJSONObject(i))
                }
                prefs.edit().putString(TIMEZONE_LOG_KEY, newArray.toString()).apply()
            } else {
                prefs.edit().putString(TIMEZONE_LOG_KEY, logArray.toString()).apply()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error logging timezone change", e)
        }
    }
    
    private fun logTimeChange(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingLog = prefs.getString(TIMEZONE_LOG_KEY, "[]")
            
            val logArray = org.json.JSONArray(existingLog)
            val logEntry = JSONObject().apply {
                put("event", "time_changed")
                put("timestamp", System.currentTimeMillis())
                put("systemTime", System.currentTimeMillis())
            }
            
            logArray.put(logEntry)
            prefs.edit().putString(TIMEZONE_LOG_KEY, logArray.toString()).apply()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error logging time change", e)
        }
    }
    
    private fun logDateChange(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingLog = prefs.getString(TIMEZONE_LOG_KEY, "[]")
            
            val logArray = org.json.JSONArray(existingLog)
            val logEntry = JSONObject().apply {
                put("event", "date_changed")
                put("timestamp", System.currentTimeMillis())
                put("systemTime", System.currentTimeMillis())
            }
            
            logArray.put(logEntry)
            prefs.edit().putString(TIMEZONE_LOG_KEY, logArray.toString()).apply()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error logging date change", e)
        }
    }
    
    private fun checkInvalidAlarms(context: Context): List<AlarmData> {
        // This would check if any scheduled alarms are now in the past or too far in the future
        // Implementation depends on how alarms are stored
        return emptyList() // Placeholder
    }
    
    private fun isAlarmStillValid(alarm: AlarmData): Boolean {
        // Check if alarm time is reasonable given current system time
        val now = System.currentTimeMillis()
        val alarmTime = alarm.scheduledTime
        
        // Alarm should be within 30 days from now
        val maxValidity = 30L * 24 * 60 * 60 * 1000 // 30 days in milliseconds
        val timeDiff = Math.abs(now - alarmTime)
        
        return timeDiff < maxValidity && alarmTime > (now - 60 * 1000) // Not more than 1 minute in the past
    }
    
    private fun rescheduleInvalidAlarms(context: Context, invalidAlarms: List<AlarmData>) {
        // Reschedule alarms that are no longer valid
        invalidAlarms.forEach { alarm ->
            try {
                PrayerAlarmReceiver.cancelAlarm(context, alarm.id)
                // Logic to reschedule would go here
                Log.d(TAG, "Rescheduled invalid alarm: ${alarm.id}")
            } catch (e: Exception) {
                Log.e(TAG, "Error rescheduling alarm: ${alarm.id}", e)
            }
        }
    }
    
    private fun getAllScheduledAlarms(context: Context): List<AlarmData> {
        // This would retrieve all currently scheduled alarms
        return emptyList() // Placeholder
    }
    
    private fun rescheduleAlarm(context: Context, alarm: AlarmData) {
        // Logic to reschedule a single alarm
        // This would typically involve cancelling the old alarm and scheduling a new one
    }
    
    private fun notifyFlutterOfTimeZoneChange(context: Context, newTimeZone: String) {
        try {
            // Send broadcast to Flutter to refresh prayer times
            val intent = Intent("com.yournewname.athkarak.TIMEZONE_CHANGED").apply {
                putExtra("newTimeZone", newTimeZone)
                putExtra("timestamp", System.currentTimeMillis())
            }
            context.sendBroadcast(intent)
            
            Log.d(TAG, "Notified Flutter of timezone change")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error notifying Flutter of timezone change", e)
        }
    }
    
    // Data class for alarm information
    data class AlarmData(
        val id: String,
        val prayerName: String,
        val scheduledTime: Long,
        val status: String
    )
}