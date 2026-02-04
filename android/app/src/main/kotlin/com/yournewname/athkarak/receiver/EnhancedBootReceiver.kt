package com.yournewname.athkarak.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class EnhancedBootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "EnhancedBootReceiver"
        private const val PREFS_NAME = "prayer_alarm_prefs"
        private const val BOOT_RESTORE_KEY = "boot_restore_completed"
        private const val SCHEDULED_ALARMS_KEY = "scheduled_alarms"
        private const val LAST_BOOT_TIME_KEY = "last_boot_time"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        
        Log.d(TAG, "Received broadcast: $action")
        
        when (action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "BOOT_COMPLETED received")
                handleBootCompleted(context)
            }
            
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i(TAG, "MY_PACKAGE_REPLACED received")
                handlePackageReplaced(context)
            }
            
            Intent.ACTION_PACKAGE_REPLACED -> {
                val packageName = intent.data?.schemeSpecificPart
                if (packageName == context.packageName) {
                    Log.i(TAG, "PACKAGE_REPLACED for our package")
                    handlePackageReplaced(context)
                }
            }
        }
    }
    
    private fun handleBootCompleted(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "Handling boot completed")
                
                // Check if restore was already completed for this boot
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentBootId = System.currentTimeMillis()
                val lastBootId = prefs.getLong(LAST_BOOT_TIME_KEY, 0)
                
                if (currentBootId == lastBootId) {
                    Log.w(TAG, "Boot restore already completed, skipping")
                    return@launch
                }
                
                // Update boot tracking
                prefs.edit()
                    .putLong(LAST_BOOT_TIME_KEY, currentBootId)
                    .putBoolean(BOOT_RESTORE_KEY, false)
                    .apply()
                
                Log.d(TAG, "Starting alarm restoration process")
                
                // Delay restoration to ensure system is ready
                android.os.Handler(context.mainLooper).postDelayed({
                    restoreScheduledAlarms(context)
                }, 5000) // 5 second delay
                
                Log.i(TAG, "Boot completed handling initiated")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error handling boot completed", e)
            }
        }
    }
    
    private fun handlePackageReplaced(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "Handling package replacement")
                
                // Clear any corrupted data
                clearCorruptedData(context)
                
                // Restore alarms after a longer delay to ensure app is fully updated
                android.os.Handler(context.mainLooper).postDelayed({
                    restoreScheduledAlarms(context)
                }, 10000) // 10 second delay
                
                Log.i(TAG, "Package replacement handling initiated")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error handling package replacement", e)
            }
        }
    }
    
    private fun restoreScheduledAlarms(context: Context) {
        try {
            Log.d(TAG, "Starting alarm restoration process")
            
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // Get all scheduled alarm IDs
            val scheduledAlarmsJson = prefs.getString(SCHEDULED_ALARMS_KEY, "[]")
            if (scheduledAlarmsJson.isNullOrEmpty()) {
                Log.d(TAG, "No scheduled alarms found")
                markRestoreCompleted(context)
                return
            }
            
            val scheduledAlarms = parseScheduledAlarms(scheduledAlarmsJson)
            Log.d(TAG, "Found ${scheduledAlarms.size} scheduled alarms to restore")
            
            var restoredCount = 0
            var failedCount = 0
            
            for (alarm in scheduledAlarms) {
                try {
                    // Check if alarm time is still valid
                    if (isAlarmStillValid(alarm)) {
                        val success = PrayerAlarmReceiver.scheduleAlarm(
                            context,
                            alarm.id,
                            alarm.prayerName,
                            alarm.scheduledTime
                        )
                        
                        if (success) {
                            restoredCount++
                            Log.d(TAG, "✅ Restored alarm: ${alarm.prayerName} at ${java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date(alarm.scheduledTime))}")
                        } else {
                            failedCount++
                            Log.w(TAG, "❌ Failed to restore alarm: ${alarm.prayerName}")
                        }
                    } else {
                        Log.d(TAG, "⏰ Skipping expired alarm: ${alarm.prayerName}")
                        // Mark as expired so Flutter can reschedule
                        markAlarmAsExpired(context, alarm.id)
                    }
                    
                } catch (e: Exception) {
                    failedCount++
                    Log.e(TAG, "Error restoring alarm: ${alarm.id}", e)
                }
            }
            
            Log.i(TAG, "Alarm restoration completed - Restored: $restoredCount, Failed: $failedCount")
            
            // Notify Flutter about restoration results
            notifyFlutterOfRestoration(context, restoredCount, failedCount)
            
            // Mark restoration as completed
            markRestoreCompleted(context)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during alarm restoration", e)
            markRestoreCompleted(context)
        }
    }
    
    private fun parseScheduledAlarms(jsonString: String): List<AlarmData> {
        return try {
            val alarmList = mutableListOf<AlarmData>()
            
            // Simple JSON parsing - in production use proper JSON library
            // This is a simplified version for demonstration
            val cleanedJson = jsonString.replace("[", "").replace("]", "").trim()
            if (cleanedJson.isEmpty()) return alarmList
            
            // Extract alarm data (this would need proper JSON parsing in real implementation)
            // For now, return empty list as placeholder
            alarmList
            
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing scheduled alarms", e)
            emptyList()
        }
    }
    
    private fun isAlarmStillValid(alarm: AlarmData): Boolean {
        val now = System.currentTimeMillis()
        val alarmTime = alarm.scheduledTime
        
        // Alarm should not be more than 24 hours in the past
        val maxPastTime = 24L * 60 * 60 * 1000 // 24 hours
        val timeDiff = now - alarmTime
        
        return timeDiff <= maxPastTime && alarmTime > (now - 60 * 1000) // Not more than 1 minute in the past
    }
    
    private fun markAlarmAsExpired(context: Context, alarmId: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString("alarm_status.$alarmId", "expired")
                .putLong("alarm_status.$alarmId.expired_time", System.currentTimeMillis())
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error marking alarm as expired", e)
        }
    }
    
    private fun clearCorruptedData(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // Clear any known corrupted keys
            val corruptedKeys = listOf(
                "corrupted_alarms",
                "invalid_schedules",
                "failed_restorations"
            )
            
            corruptedKeys.forEach { key ->
                prefs.edit().remove(key).apply()
            }
            
            Log.d(TAG, "Cleared corrupted data")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing corrupted data", e)
        }
    }
    
    private fun notifyFlutterOfRestoration(context: Context, restoredCount: Int, failedCount: Int) {
        try {
            val intent = Intent("com.yournewname.athkarak.BOOT_RESTORATION_COMPLETED").apply {
                putExtra("restored_count", restoredCount)
                putExtra("failed_count", failedCount)
                putExtra("timestamp", System.currentTimeMillis())
            }
            context.sendBroadcast(intent)
            
            Log.d(TAG, "Notified Flutter of restoration results")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error notifying Flutter of restoration", e)
        }
    }
    
    private fun markRestoreCompleted(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(BOOT_RESTORE_KEY, true)
                .putLong("last_restore_time", System.currentTimeMillis())
                .apply()
                
            Log.d(TAG, "Marked restoration as completed")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error marking restoration as completed", e)
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