package ai.nobox.android

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.microsoft.signalr.HubConnection
import com.microsoft.signalr.HubConnectionBuilder
import com.microsoft.signalr.HubConnectionState
import io.reactivex.rxjava3.core.Single
import org.json.JSONObject

class SignalRBackgroundService : Service() {

    companion object {
        private const val TAG = "NOBOX_BG_SIGNALR"
        private const val CHANNEL_ID = "signalr_service_channel"
        private const val CHAT_CHANNEL_ID = "chat_notifications"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "START_SIGNALR_SERVICE"
        private const val ACTION_STOP = "STOP_SIGNALR_SERVICE"
        private const val EXTRA_TOKEN = "EXTRA_JWT_TOKEN"
        private const val EXTRA_USERID = "EXTRA_USERID"
        private const val EXTRA_TENANTID = "EXTRA_TENANTID"

        fun startService(context: Context, token: String, userId: String, tenantId: String) {
            val intent = Intent(context, SignalRBackgroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_USERID, userId)
                putExtra(EXTRA_TENANTID, tenantId)
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
    private var userId: String = "1"
    private var tenantId: String = ""
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        acquireWakeLock()
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "nobox:signalr_bg")
        wakeLock?.acquire(60 * 60 * 1000L) // 1 jam max
        Log.d(TAG, "WakeLock acquired")
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        Log.d(TAG, "WakeLock released")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                token = intent.getStringExtra(EXTRA_TOKEN)
                userId = intent.getStringExtra(EXTRA_USERID) ?: "1"
                tenantId = intent.getStringExtra(EXTRA_TENANTID) ?: ""
                Log.d(TAG, "START received. Token length=${token?.length ?: 0}, User=$userId, Tenant=$tenantId")
                startForeground(NOTIFICATION_ID, createServiceNotification("Menghubungkan..."))
                startSignalRListener()
            }
            ACTION_STOP -> {
                Log.d(TAG, "STOP received.")
                stopSignalRListener()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startSignalRListener() {
        if (hubConnection?.connectionState == HubConnectionState.CONNECTED) {
            Log.d(TAG, "Already connected, skip.")
            return
        }

        try {
            hubConnection = HubConnectionBuilder.create("https://id.nobox.ai/messagehub")
                .withAccessTokenProvider(Single.defer { Single.just(token ?: "") })
                .build()

            // Register handler with 4 arguments (Action4) since the backend sends up to 4 parameters.
            // Using multiple on() handlers for the same event crashes the Java SignalR client if argument counts mismatch.
            hubConnection?.on("TerimaPesan", { rawRoom: Any, rawMsg: Any, arg3: Any, arg4: Any ->
                Log.d(TAG, ">>> TerimaPesan (4 args)! room=${rawRoom}")
                handleIncomingMessage(rawRoom.toString(), rawMsg.toString())
            }, Object::class.java, Object::class.java, Object::class.java, Object::class.java)

            // Retry mechanism dengan exponential backoff
            val maxRetries = 3
            val retryDelays = longArrayOf(5000, 10000, 20000) // 5s, 10s, 20s
            
            for (attempt in 0..maxRetries) {
                try {
                    Log.d(TAG, "Starting connection... (attempt ${attempt + 1}/${maxRetries + 1})")
                    hubConnection?.start()?.blockingAwait()
                    Log.d(TAG, "CONNECTED! id=${hubConnection?.connectionId}")
                    updateServiceNotification("Tersambung / Aktif")
                    
                    // Wajib Subscribe User agar backend mengirimkan event TerimaPesan
                    if (userId.isNotEmpty() && tenantId.isNotEmpty()) {
                        Log.d(TAG, "Subscribing user: userId=$userId, tenantId=$tenantId")
                        hubConnection?.send("SubscribeUser", userId, tenantId)
                    }
                    
                    return // Berhasil, keluar dari loop
                } catch (e: Exception) {
                    Log.e(TAG, "Connection attempt ${attempt + 1} FAILED: ${e.message}")
                    if (attempt < maxRetries) {
                        val delay = retryDelays[attempt]
                        Log.d(TAG, "Retrying in ${delay / 1000}s...")
                        updateServiceNotification("Retry ${attempt + 2}...")
                        Thread.sleep(delay)
                    } else {
                        Log.e(TAG, "All connection attempts failed!")
                        updateServiceNotification("Gagal: ${e.message?.take(40)}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Connection setup FAILED: ${e.message}")
            updateServiceNotification("Gagal: ${e.message?.take(40)}")
        }
    }

    private fun handleIncomingMessage(roomIdRaw: String, rawMsg: String) {
        var msgText = "Anda mendapat pesan baru"
        try {
            val json = JSONObject(rawMsg)
            val m = json.optString("Msg", "")
            if (m.isNotEmpty()) msgText = m
        } catch (e: Exception) {
            Log.w(TAG, "JSON parse: ${e.message}")
        }
        showChatNotification(msgText)
    }

    private fun showChatNotification(messageText: String) {
        Log.d(TAG, "Showing notif: $messageText")
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pi = PendingIntent.getActivity(
            this, System.currentTimeMillis().toInt(),
            intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notif = NotificationCompat.Builder(this, CHAT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("Pesan Baru")
            .setContentText(messageText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setDefaults(Notification.DEFAULT_ALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setFullScreenIntent(pi, true) // Tembus MIUI lock screen
            .build()

        val uniqueId = (System.currentTimeMillis() % 100000).toInt() + 2000
        mgr.notify(uniqueId, notif)
        Log.d(TAG, "Notif posted id=$uniqueId")
    }

    private fun stopSignalRListener() {
        hubConnection?.stop()
        hubConnection = null
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NotificationManager::class.java)
            // Low-priority service channel
            mgr.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "SignalR Background", NotificationManager.IMPORTANCE_LOW
            ))
            // High-priority chat channel
            mgr.createNotificationChannel(NotificationChannel(
                CHAT_CHANNEL_ID, "Notifikasi Chat", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                enableLights(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            })
        }
    }

    private fun createServiceNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nobox Chat")
            .setContentText(text)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setOngoing(true)
            .build()
    }

    private fun updateServiceNotification(text: String) {
        val mgr = getSystemService(NotificationManager::class.java)
        mgr.notify(NOTIFICATION_ID, createServiceNotification(text))
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
