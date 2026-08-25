package com.tact.app

import android.app.Application
import android.provider.Settings
import androidx.lifecycle.AndroidViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject

enum class AppPhase { PAIRING, DASHBOARD }
enum class TactScreen { SYSTEM, DEVELOPER, MEDIA, EVENTS, DECK, SETTINGS }

data class TactUiState(
    val phase: AppPhase = AppPhase.PAIRING,
    val screen: TactScreen = TactScreen.SYSTEM,
    val host: String = "",
    val connection: ConnectionState = ConnectionState.DISCONNECTED,
    val snapshot: JSONObject = JSONObject(),
    val events: List<TactEvent> = emptyList(),
    val pairing: Boolean = false,
    val notice: String? = null,
)

class TactViewModel(application: Application) : AndroidViewModel(application), TactClientListener {
    private val preferences = application.getSharedPreferences("tact.connection", 0)
    private val deviceId = preferences.getString("device_id", null)
        ?: Settings.Secure.getString(application.contentResolver, Settings.Secure.ANDROID_ID)
        ?: java.util.UUID.randomUUID().toString()
    private val client = TactClient(this)
    private val mutableState = MutableStateFlow(TactUiState())
    val state: StateFlow<TactUiState> = mutableState.asStateFlow()

    init {
        preferences.edit().putString("device_id", deviceId).apply()
        val host = preferences.getString("host", "").orEmpty()
        val token = preferences.getString("token", "").orEmpty()
        if (host.isNotBlank() && token.isNotBlank()) {
            mutableState.value = mutableState.value.copy(phase = AppPhase.DASHBOARD, host = host)
            client.connect(host, token = token)
        }
    }

    fun pair(host: String, otp: String) {
        if (host.isBlank() || otp.length != 6) {
            showNotice("Enter a host address and 6-digit OTP")
            return
        }
        mutableState.value = mutableState.value.copy(pairing = true, notice = "Waiting for approval on the host…")
        client.requestPairing(host, otp, deviceId) { result ->
            result.onSuccess { token ->
                preferences.edit().putString("host", host.trim()).putString("token", token).apply()
                mutableState.value = mutableState.value.copy(
                    phase = AppPhase.DASHBOARD,
                    host = host.trim(),
                    pairing = false,
                    notice = null,
                )
                client.connect(host, token = token)
            }.onFailure { error ->
                mutableState.value = mutableState.value.copy(pairing = false, notice = error.message)
            }
        }
    }

    fun demo() {
        mutableState.value = mutableState.value.copy(
            phase = AppPhase.DASHBOARD,
            host = "Demo host",
            connection = ConnectionState.CONNECTED,
            snapshot = demoSnapshot(),
            notice = "Demo mode uses sample data; controls are disabled",
        )
    }

    fun navigate(screen: TactScreen) {
        mutableState.value = mutableState.value.copy(screen = screen)
    }

    fun action(id: String, payload: JSONObject = JSONObject()) {
        if (mutableState.value.host == "Demo host") {
            showNotice("Connect a real host to run actions")
            return
        }
        client.action(id, payload)
    }

    fun disconnect() {
        client.disconnect()
        preferences.edit().remove("host").remove("token").apply()
        mutableState.value = TactUiState()
    }

    fun clearNotice() {
        mutableState.value = mutableState.value.copy(notice = null)
    }

    override fun onConnectionChanged(state: ConnectionState, message: String?) {
        mutableState.value = mutableState.value.copy(connection = state, notice = message ?: mutableState.value.notice)
    }

    override fun onSnapshot(snapshot: JSONObject) {
        mutableState.value = mutableState.value.copy(snapshot = snapshot)
    }

    override fun onEvent(event: TactEvent) {
        mutableState.value = mutableState.value.copy(events = (listOf(event) + mutableState.value.events).take(100))
    }

    override fun onActionResult(actionId: String, succeeded: Boolean, message: String?) {
        if (!succeeded) showNotice(message ?: "$actionId failed")
    }

    override fun onCleared() {
        client.disconnect()
        super.onCleared()
    }

    private fun showNotice(message: String) {
        mutableState.value = mutableState.value.copy(notice = message)
    }

    private fun demoSnapshot() = JSONObject(
        """{
          "system":{"cpu":18,"memory":62,"disk":41,"volume":54,"battery":{"percent":84,"charging":true}},
          "git":{"available":true,"branch":"main","changed_files":3,"ahead":2,"behind":0,"clean":false},
          "docker":{"available":true,"count":2,"containers":[{"name":"tact-api","state":"running","image":"tact/api:dev","status":"Up 28 minutes"},{"name":"postgres","state":"running","image":"postgres:16","status":"Up 2 hours"}]},
          "media":{"available":true,"active":{"player":"Spotify","title":"Midnight Static","artist":"The Neon Hours","album":"Frequencies","status":"Playing","length":224,"position":82}},
          "workspace":{"current_workspace":"~/Projects/Tact","terminal_available":true}
        }""".trimIndent()
    )
}
