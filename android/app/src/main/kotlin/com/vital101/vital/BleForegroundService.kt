package com.vital101.vital

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Holds the app's process at foreground priority while a band is connected.
 *
 * It deliberately does no Bluetooth work of its own — flutter_blue_plus keeps
 * running on the main Dart isolate. This service exists only so Android won't
 * reclaim that process under memory pressure or throttle it in Doze, either of
 * which drops the GATT link and stops readings arriving.
 */
class BleForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "ble_connection_channel"
        const val NOTIFICATION_ID = 1337

        const val ACTION_START = "com.vital101.vital.BLE_START"
        const val ACTION_UPDATE = "com.vital101.vital.BLE_UPDATE"
        const val ACTION_STOP = "com.vital101.vital.BLE_STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_MESSAGE = "message"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Vitals 101"
        val message = intent?.getStringExtra(EXTRA_MESSAGE) ?: "Connected to your device"
        val notification = buildNotification(title, message)

        if (intent?.action == ACTION_UPDATE) {
            // Already in the foreground; just refresh the text in place so we
            // don't restart the service on every status change.
            getSystemService(NotificationManager::class.java)
                ?.notify(NOTIFICATION_ID, notification)
        } else {
            startForegroundCompat(notification)
        }

        // START_STICKY so Android restarts us if it does reclaim the service.
        return START_STICKY
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14 requires the type to be declared at start time and to
            // match the manifest's foregroundServiceType.
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(title: String, message: String): Notification {
        // Tapping the notification brings the app back rather than launching a
        // second task.
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            // Swap in a monochrome drawable of your own when you have one —
            // notification small icons are tinted, so coloured art renders as
            // a solid blob.
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Device connection",
            // IMPORTANCE_LOW keeps it silent and collapsed in the shade; the
            // notification is a requirement of the foreground service, not
            // something the user needs to act on.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while Vitals 101 is reading from your device"
            setShowBadge(false)
        }

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }
}
