package com.example.mkamesh

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.android.volley.Request
import com.android.volley.Response
import com.android.volley.toolbox.JsonObjectRequest
import com.android.volley.toolbox.Volley
import org.json.JSONObject

class LocationWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        val location = getLastKnownLocation()
        val deviceInfo = getDeviceInfo()

        if (location != null) {
            val latitude = location.latitude
            val longitude = location.longitude

            // Prepare data to send to the API
            val payload = JSONObject().apply {
                put("latitude", latitude)
                put("longitude", longitude)
                put("device_info", deviceInfo)
            }

            // Make API call
            sendLocationToApi(payload)
        }

        return Result.success()
    }

    private fun getLastKnownLocation(): Location? {
        val locationManager = applicationContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
    }

    private fun getDeviceInfo(): JSONObject {
        val deviceInfo = JSONObject()
        deviceInfo.put("brand", Build.BRAND)
        deviceInfo.put("model", Build.MODEL)
        deviceInfo.put("sdk_version", Build.VERSION.SDK_INT)
        deviceInfo.put("battery_level", getBatteryLevel())
        return deviceInfo
    }

    private fun getBatteryLevel(): Int {
        // Placeholder for battery level retrieval logic
        return 100 // You can replace this with actual logic to get battery level
    }

    private fun sendLocationToApi(payload: JSONObject) {
        val queue = Volley.newRequestQueue(applicationContext)
        val url = "https://frappeschool.com/api/method/storelocation"

        val jsonObjectRequest = JsonObjectRequest(Request.Method.POST, url, payload,
            Response.Listener { response ->
                // Handle the response from the server
                println("Response: $response")
            },
            Response.ErrorListener { error ->
                // Handle any errors
                println("Error: ${error.message}")
            }
        )

        // Add the request to the RequestQueue
        queue.add(jsonObjectRequest)
    }
}
