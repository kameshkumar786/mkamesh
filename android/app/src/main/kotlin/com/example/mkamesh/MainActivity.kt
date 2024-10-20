package com.example.mkamesh

import android.os.Bundle
import androidx.annotation.NonNull
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.mkamesh/location"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    startLocationTracking()
                    result.success(null)
                }
                "stopTracking" -> {
                    stopLocationTracking()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startLocationTracking() {
        val locationWorkRequest = PeriodicWorkRequestBuilder<LocationWorker>(15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(applicationContext).enqueue(locationWorkRequest)
    }

    private fun stopLocationTracking() {
        WorkManager.getInstance(applicationContext).cancelAllWorkByTag("LocationWorker")
    }
}
