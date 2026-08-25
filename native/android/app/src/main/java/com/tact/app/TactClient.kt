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
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.io.IOException
import java.util.UUID
import java.util.concurrent.TimeUnit

enum class ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, RECONNECTING, ERROR }

data class TactEvent(
    val id: String,
    val title: String,
    val description: String,
    val category: String,
    val severity: String,
    val timestamp: String,
)

interface TactClientListener {
    fun onConnectionChanged(state: ConnectionState, message: String? = null)
    fun onSnapshot(snapshot: JSONObject)
    fun onEvent(event: TactEvent)
    fun onActionResult(actionId: String, succeeded: Boolean, message: String?)
}

class TactClient(private val listener: TactClientListener) {
    private val main = Handler(Looper.getMainLooper())
    private val http = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    private var socket: WebSocket? = null
    private var host = ""
    private var port = 8000
    private var token = ""
    private var reconnectAttempts = 0
    private var manuallyClosed = true

    fun connect(host: String, port: Int = 8000, token: String) {
        this.host = cleanHost(host)
        this.port = port
        this.token = token.trim()
        reconnectAttempts = 0
        manuallyClosed = false
        openSocket(ConnectionState.CONNECTING)
    }

    private fun openSocket(state: ConnectionState) {
        if (manuallyClosed || host.isBlank() || token.isBlank()) return
        emitConnection(state)
        socket?.cancel()
        val request = Request.Builder().url("ws://$host:$port/ws").build()
        socket = http.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                reconnectAttempts = 0
                webSocket.send(JSONObject().apply {
                    put("type", "auth")
                    put("token", token)
                    put("label", "Tact Android")
                }.toString())
            }

            override fun onMessage(webSocket: WebSocket, text: String) = handleMessage(text)

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                if (!manuallyClosed) scheduleReconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                if (!manuallyClosed) scheduleReconnect(t.message)
            }
        })
    }

    private fun handleMessage(text: String) {
        runCatching {
            val message = JSONObject(text)
            when (message.optString("type")) {
                "init", "telemetry" -> {
                    emitConnection(ConnectionState.CONNECTED)
                    val payload = message.optJSONObject("payload") ?: JSONObject()
                    main.post { listener.onSnapshot(payload) }
                }
                "event" -> {
                    val payload = message.optJSONObject("payload") ?: return
                    val event = TactEvent(
                        id = payload.optString("id", UUID.randomUUID().toString()),
                        title = payload.optString("title", "Tact event"),
                        description = payload.optString("description"),
                        category = payload.optString("source", payload.optString("category", "system")),
                        severity = payload.optString("severity", "info"),
                        timestamp = payload.optString("timestamp"),
                    )
                    main.post { listener.onEvent(event) }
                }
                "action_result" -> {
                    val result = message.optJSONObject("result")
                    val succeeded = result?.optBoolean("ok", true) ?: true
                    val detail = result?.optString("error")?.takeIf(String::isNotBlank)
                    main.post {
                        listener.onActionResult(message.optString("action_id"), succeeded, detail)
                    }
                }
                "error" -> emitConnection(
                    ConnectionState.ERROR,
                    message.optString("message", "Connection rejected"),
                )
            }
        }.onFailure { emitConnection(ConnectionState.ERROR, "The host sent an invalid response") }
    }

    fun action(id: String, payload: JSONObject = JSONObject()) {
        val sent = socket?.send(JSONObject().apply {
            put("type", "action")
            put("action_id", id)
            put("request_id", UUID.randomUUID().toString())
            put("payload", payload)
        }.toString()) == true
        if (!sent) emitConnection(ConnectionState.ERROR, "Connect to a host before using controls")
    }

    fun requestPairing(
        host: String,
        otp: String,
        deviceId: String,
        onComplete: (Result<String>) -> Unit,
    ) {
        val cleanHost = cleanHost(host)
        val body = JSONObject().apply {
            put("token", otp)
            put("device_id", deviceId)
            put("label", "Tact Android")
        }.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url("http://$cleanHost:$port/api/pair/request").post(body).build()
        http.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                main.post { onComplete(Result.failure(e)) }
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (!it.isSuccessful) {
                        main.post { onComplete(Result.failure(IOException("OTP is invalid or expired"))) }
                        return
                    }
                }
                pollForApproval(cleanHost, deviceId, 0, onComplete)
            }
        })
    }

    private fun pollForApproval(
        host: String,
        deviceId: String,
        attempt: Int,
        onComplete: (Result<String>) -> Unit,
    ) {
        if (attempt >= 60) {
            main.post { onComplete(Result.failure(IOException("Pairing approval timed out"))) }
            return
        }
        val request = Request.Builder()
            .url("http://$host:$port/api/pair/me?device_id=$deviceId")
            .get()
            .build()
        http.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                retryApproval(host, deviceId, attempt, onComplete)
            }

            override fun onResponse(call: Call, response: Response) {
                val approved = response.use {
                    it.isSuccessful && runCatching {
                        JSONObject(it.body.string()).optBoolean("paired")
                    }.getOrDefault(false)
                }
                if (approved) {
                    main.post { onComplete(Result.success(deviceId)) }
                } else {
                    retryApproval(host, deviceId, attempt, onComplete)
                }
            }
        })
    }

    private fun retryApproval(
        host: String,
        deviceId: String,
        attempt: Int,
        onComplete: (Result<String>) -> Unit,
    ) = main.postDelayed({ pollForApproval(host, deviceId, attempt + 1, onComplete) }, 1_000)

    private fun scheduleReconnect(message: String? = null) {
        reconnectAttempts += 1
        emitConnection(ConnectionState.RECONNECTING, message)
        val delay = (500L * (1 shl reconnectAttempts.coerceAtMost(4))).coerceAtMost(8_000L)
        main.postDelayed({ openSocket(ConnectionState.RECONNECTING) }, delay)
    }

    fun disconnect() {
        manuallyClosed = true
        main.removeCallbacksAndMessages(null)
        socket?.close(1000, "user")
        socket = null
        emitConnection(ConnectionState.DISCONNECTED)
    }

    private fun emitConnection(state: ConnectionState, message: String? = null) {
        main.post { listener.onConnectionChanged(state, message) }
    }

    private fun cleanHost(value: String) = value.trim()
        .removePrefix("http://")
        .removePrefix("https://")
        .substringBefore('/')
        .substringBefore(':')
}
