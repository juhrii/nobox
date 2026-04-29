package ai.nobox.android

import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    private val CHANNEL = "ai.nobox.android/background_service"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startBackgroundService" -> {
                        val token = call.argument<String>("token") ?: ""
                        SignalRBackgroundService.startService(this, token)
                        result.success(true)
                    }
                    "stopBackgroundService" -> {
                        SignalRBackgroundService.stopService(this)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                result.error("ERROR", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Sengaja tidak stopBackgroundService agar chat tetap jalan walau aplikasi ditutup.
    }
    
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
}
