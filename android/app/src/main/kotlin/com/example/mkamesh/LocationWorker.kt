package com.example.mkamesh

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.work.*
import com.android.volley.Request
import com.android.volley.Response
import com.android.volley.toolbox.JsonObjectRequest
import com.android.volley.toolbox.Volley
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import android.provider.Settings
import android.app.PendingIntent
import android.content.Intent
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager



class LocationWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(ctx)

    override fun doWork(): Result {
        getLastLocation { location ->
            location?.let {
                sendLocationData(it)
            } ?: run {
                println("Location is null, cannot send to API.")
            }
        }
        scheduleNextWork()
        return Result.success() // Return success immediately; actual work is done in the callback
    }

     private fun scheduleNextWork() {
        val nextWorkRequest = OneTimeWorkRequestBuilder<LocationWorker>()
            .setInitialDelay(10, TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(applicationContext).enqueue(nextWorkRequest)
    }

    private fun startForegroundService() {
        val notification = createNotification()
        // Start the service in the foreground
        val serviceIntent = Intent(applicationContext, ForegroundService::class.java)
        applicationContext.startService(serviceIntent)
    }

    private fun createNotification(): Notification {
        val intent = Intent(applicationContext, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(applicationContext, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)

        return Notification.Builder(applicationContext, "location_channel")
            .setContentTitle("Location Service")
            .setContentText("Tracking your location...")
            .setSmallIcon(R.mipmap.ic_launcher) // Replace with your app's icon
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun getLastLocation(callback: (Location?) -> Unit) {
        fusedLocationClient.lastLocation
            .addOnSuccessListener { location: Location? ->
                callback(location)
            }
            .addOnFailureListener { e ->
                println("Failed to retrieve location: ${e.message}")
                callback(null)
            }
    }

    private fun sendLocationData(location: Location) {
        val deviceInfo = getDeviceInfo()

        val payload = JSONObject().apply {
            put("latitude", location.latitude)
            put("longitude", location.longitude)
            put("device_info", deviceInfo)
        }

        sendLocationToApi(applicationContext, payload)
    }

    private fun getDeviceInfo(): JSONObject {
        val deviceInfo = JSONObject()
        deviceInfo.put("brand", Build.BRAND)
        deviceInfo.put("model", Build.MODEL)
        deviceInfo.put("sdk_version", Build.VERSION.SDK_INT)
        deviceInfo.put("battery_level", getBatteryLevel())
        return deviceInfo
    }

    private fun requestBatteryOptimizationPermission(context: Context) {
        val intent = Intent()
        intent.action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
        context.startActivity(intent)
    }

    private fun getBatteryLevel(): Int {
        val batteryManager = applicationContext.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            // Fallback for older versions
            100 // Return a default value
        }
    }

    private fun sendLocationToApi(context: Context, payload: JSONObject) {
        val queue = Volley.newRequestQueue(applicationContext)
        val url = "https://uatss.erpdesks.com/api/method/storelocation"

        val sharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cookies = sharedPreferences.getString("flutter.cookies", null) // The key will be 'flutter.cookies'


        val jsonObjectRequest = object : JsonObjectRequest(
        Request.Method.POST, url, payload,
        Response.Listener { response ->
            // Handle the response from the server
            println("Response: $response")
        },
        Response.ErrorListener { error ->
            // Handle any errors
            println("Error: ${error.message}")
        }
        ) {
            // Override getHeaders() to add cookies to the request headers
            override fun getHeaders(): Map<String, String> {
                val headers = HashMap<String, String>()
                headers["Content-Type"] = "application/json"
                if (cookies != null) {
                    headers["Cookie"] = cookies // Attach the cookies
                }
                return headers
            }
        }

        // Add the request to the RequestQueue
        queue.add(jsonObjectRequest)
    }

    companion object {
        fun startBackgroundJob(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<LocationWorker>(15, TimeUnit.MINUTES)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiresBatteryNotLow(true)
                        .setRequiresDeviceIdle(false)
                        .build()
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "LocationWorker",
                ExistingPeriodicWorkPolicy.REPLACE,
                workRequest
            )
        }

        fun checkBackgroundJobStatus(context: Context) {
            WorkManager.getInstance(context).getWorkInfosByTagLiveData("LocationWorker").observeForever { workInfos ->
                if (workInfos != null && workInfos.isNotEmpty()) {
                    val workInfo = workInfos[0]
                    when (workInfo.state) {
                        WorkInfo.State.ENQUEUED -> println("Job is enqueued.")
                        WorkInfo.State.RUNNING -> println("Job is running.")
                        WorkInfo.State.SUCCEEDED -> println("Job has succeeded.")
                        WorkInfo.State.FAILED -> println("Job has failed.")
                        WorkInfo.State.CANCELLED -> println("Job has been cancelled.")
                        else -> println("Job is in an unknown state.")
                    }
                } else {
                    println("No job found.")
                }
            }
        }
    }
}
