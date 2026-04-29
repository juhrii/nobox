package ai.nobox.android

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.microsoft.signalr.HubConnection
import com.microsoft.signalr.HubConnectionBuilder
import com.microsoft.signalr.HubConnectionState
import io.reactivex.rxjava3.core.Single

class SignalRBackgroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "signalr_service_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "START_SIGNALR_SERVICE"
        private const val ACTION_STOP = "STOP_SIGNALR_SERVICE"
        private const val EXTRA_TOKEN = "EXTRA_JWT_TOKEN"

        // Fungsi yang bisa dipanggil dari MainActivity
        fun startService(context: Context, token: String) {
            val intent = Intent(context, SignalRBackgroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TOKEN, token)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, SignalRBackgroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var hubConnection: HubConnection? = null
    private var token: String? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                token = intent.getStringExtra(EXTRA_TOKEN)
                startForeground(NOTIFICATION_ID, createNotification("Service Running", "Menghubungkan ke Nobox.ai..."))
                startSignalRListener()
            }
            ACTION_STOP -> {
                stopSignalRListener()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_STICKY // Service ditarik lagi sistem
    }

    private fun startSignalRListener() {
        if (hubConnection?.connectionState == HubConnectionState.CONNECTED) return

        try {
            // Setup Koneksi ke Nobox API
            hubConnection = HubConnectionBuilder.create("https://id.nobox.ai/messagehub")
                .withAccessTokenProvider(Single.defer { Single.just(token ?: "") })
                .build()

            // Trigger Notifikasi Saat ada pesan masuk
            hubConnection?.on("ReceiveMessage", { messageBody: String ->
                triggerHeadsUpNotification("Pesan Baru", messageBody)
            }, String::class.java)

            // Memulai koneksi background
            hubConnection?.start()?.blockingAwait()
            updateNotification("Tersambung / Aktif")
        } catch (e: Exception) {
            e.printStackTrace()
            updateNotification("Koneksi terputus")
        }
    }

    private fun stopSignalRListener() {
        hubConnection?.stop()
        hubConnection = null
    }

    private fun triggerHeadsUpNotification(title: String, messageText: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Channel ID sama persis dengan FCM
        val highPriorityChannelId = "chat_notifications" 
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                highPriorityChannelId, 
                "Notifikasi Chat Baru", 
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, highPriorityChannelId)
            .setSmallIcon(R.mipmap.launcher_icon) 
            .setContentTitle(title)
            .setContentText(messageText)
            .setPriority(NotificationCompat.PRIORITY_HIGH) 
            .setDefaults(Notification.DEFAULT_ALL)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
            
        notificationManager.notify((System.currentTimeMillis() % 10000).toInt(), notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, 
                "SignalR Foreground Tracker", 
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setOngoing(true) 
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, createNotification("Nobox Chat Background", text))
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
