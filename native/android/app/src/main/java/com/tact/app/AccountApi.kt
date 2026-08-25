package com.tact.app

import android.os.Handler
import android.os.Looper
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

data class AccountDevice(
    val id: String,
    val label: String,
    val platform: String,
    val deviceType: String,
    val model: String,
    val host: String?,
    val port: Int?,
    val lastSeen: String,
    val active: Boolean,
    val canConnect: Boolean,
)

data class AccountConnection(
    val host: String,
    val port: Int,
    val token: String,
    val targetLabel: String,
)

class AccountApi {
    private val main = Handler(Looper.getMainLooper())
    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()
    private val serviceURL = BuildConfig.TACT_ACCOUNT_SERVICE_URL.trimEnd('/')

    fun login(email: String, password: String, complete: (Result<String>) -> Unit) {
        post(
            "/api/auth/login",
            JSONObject().put("email", email).put("password", password),
            null,
        ) { result -> complete(result.map { it.getString("token") }) }
    }

    fun provider(
        provider: String,
        identityToken: String,
        complete: (Result<String>) -> Unit,
    ) {
        post(
            "/api/auth/provider",
            JSONObject()
                .put("provider", provider)
                .put("identity_token", identityToken),
            null,
        ) { result -> complete(result.map { it.getString("token") }) }
    }

    fun exchange(code: String, complete: (Result<String>) -> Unit) {
        post(
            "/api/auth/exchange",
            JSONObject().put("code", code),
            null,
        ) { result -> complete(result.map { it.getString("token") }) }
    }

    fun registerPhone(
        token: String,
        deviceId: String,
        label: String,
        model: String,
        complete: (Result<Unit>) -> Unit,
    ) {
        post(
            "/api/account/devices",
            JSONObject()
                .put("device_id", deviceId)
                .put("label", label)
                .put("platform", "android")
                .put("device_type", "phone")
                .put("model", model),
            token,
        ) { result -> complete(result.map { Unit }) }
    }

    fun devices(token: String, complete: (Result<List<AccountDevice>>) -> Unit) {
        request("GET", "/api/account/devices", null, token) { result ->
            complete(result.map { payload ->
                val array = payload.optJSONArray("devices")
                    ?: org.json.JSONArray()
                buildList {
                    for (index in 0 until array.length()) {
                        val device = array.getJSONObject(index)
                        add(
                            AccountDevice(
                                id = device.getString("device_id"),
                                label = device.getString("label"),
                                platform = device.optString("platform", "unknown"),
                                deviceType = device.optString("device_type", "desktop"),
                                model = device.optString("model"),
                                host = device.optString("host").takeIf(String::isNotBlank),
                                port = device.optInt("port").takeIf { it > 0 },
                                lastSeen = device.optString("last_seen"),
                                active = device.optBoolean("active"),
                                canConnect = device.optBoolean("can_connect"),
                            ),
                        )
                    }
                }
            })
        }
    }

    fun connect(
        token: String,
        targetDeviceId: String,
        clientDeviceId: String,
        clientLabel: String,
        complete: (Result<AccountConnection>) -> Unit,
    ) {
        post(
            "/api/account/devices/connect",
            JSONObject()
                .put("target_device_id", targetDeviceId)
                .put("client_device_id", clientDeviceId)
                .put("client_label", clientLabel),
            token,
        ) { result ->
            complete(result.map { payload ->
                val connection = payload.getJSONObject("connection")
                AccountConnection(
                    host = connection.getString("host"),
                    port = connection.getInt("port"),
                    token = connection.getString("token"),
                    targetLabel = connection.getString("target_label"),
                )
            })
        }
    }

    fun logout(token: String, complete: (Result<Unit>) -> Unit) {
        post("/api/auth/logout", JSONObject(), token) { result ->
            complete(result.map { Unit })
        }
    }

    private fun post(
        path: String,
        payload: JSONObject,
        token: String?,
        complete: (Result<JSONObject>) -> Unit,
    ) = request("POST", path, payload, token, complete)

    private fun request(
        method: String,
        path: String,
        payload: JSONObject?,
        token: String?,
        complete: (Result<JSONObject>) -> Unit,
    ) {
        val builder = Request.Builder()
            .url("$serviceURL$path")
            .header("Accept", "application/json")
        token?.let { builder.header("Authorization", "Bearer $it") }
        if (method == "POST") {
            builder.post(
                (payload ?: JSONObject()).toString()
                    .toRequestBody("application/json".toMediaType()),
            )
        } else {
            builder.get()
        }
        http.newCall(builder.build()).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                main.post { complete(Result.failure(e)) }
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val text = it.body.string()
                    val body = runCatching { JSONObject(text) }.getOrDefault(JSONObject())
                    if (it.isSuccessful) {
                        main.post { complete(Result.success(body)) }
                    } else {
                        val detail = body.optString("detail", "Request failed")
                            .replace('_', ' ')
                        main.post { complete(Result.failure(IOException(detail))) }
                    }
                }
            }
        })
    }
}
