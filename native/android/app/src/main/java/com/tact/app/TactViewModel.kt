package com.tact.app

import android.app.Application
import android.os.Build
import android.provider.Settings
import androidx.lifecycle.AndroidViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject

enum class AppPhase { AUTH, DEVICES, DASHBOARD }
enum class TactScreen { SYSTEM, DEVELOPER, MEDIA, EVENTS, DECK, SETTINGS }

data class TactUiState(
    val phase: AppPhase = AppPhase.AUTH,
    val screen: TactScreen = TactScreen.SYSTEM,
    val host: String = "",
    val connection: ConnectionState = ConnectionState.DISCONNECTED,
    val snapshot: JSONObject = JSONObject(),
    val events: List<TactEvent> = emptyList(),
    val pairing: Boolean = false,
    val authenticating: Boolean = false,
    val devices: List<AccountDevice> = emptyList(),
    val selectedDeviceId: String? = null,
    val notice: String? = null,
)

class TactViewModel(application: Application) : AndroidViewModel(application), TactClientListener {
    private val preferences = application.getSharedPreferences("tact.connection", 0)
    private val deviceId = preferences.getString("device_id", null)
        ?: Settings.Secure.getString(application.contentResolver, Settings.Secure.ANDROID_ID)
        ?: java.util.UUID.randomUUID().toString()
    private val client = TactClient(this)
    private val accounts = AccountApi()
    private val mutableState = MutableStateFlow(TactUiState())
    val state: StateFlow<TactUiState> = mutableState.asStateFlow()

    init {
        preferences.edit().putString("device_id", deviceId).apply()
        val accountToken = preferences.getString("account_token", "").orEmpty()
        val host = preferences.getString("host", "").orEmpty()
        val token = preferences.getString("token", "").orEmpty()
        if (host.isNotBlank() && token.isNotBlank()) {
            mutableState.value = mutableState.value.copy(phase = AppPhase.DASHBOARD, host = host)
            client.connect(host, token = token)
        } else if (accountToken.isNotBlank()) {
            mutableState.value = mutableState.value.copy(phase = AppPhase.DEVICES)
            refreshDevices()
        }
    }

    fun signIn(email: String, password: String) {
        if (!android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches()) {
            showNotice("Enter a valid email address")
            return
        }
        if (password.isBlank()) {
            showNotice("Enter your password")
            return
        }
        mutableState.value = mutableState.value.copy(authenticating = true, notice = null)
        accounts.login(email.trim(), password) { result ->
            result.onSuccess(::completeAccountSignIn).onFailure { error ->
                mutableState.value = mutableState.value.copy(
                    authenticating = false,
                    notice = error.message,
                )
            }
        }
    }

    fun signInProvider(provider: String, identityToken: String) {
        mutableState.value = mutableState.value.copy(authenticating = true, notice = null)
        accounts.provider(provider, identityToken) { result ->
            result.onSuccess(::completeAccountSignIn).onFailure { error ->
                mutableState.value = mutableState.value.copy(
                    authenticating = false,
                    notice = error.message,
                )
            }
        }
    }

    fun completeWebSignIn(code: String) {
        mutableState.value = mutableState.value.copy(authenticating = true, notice = null)
        accounts.exchange(code) { result ->
            result.onSuccess(::completeAccountSignIn).onFailure { error ->
                mutableState.value = mutableState.value.copy(
                    authenticating = false,
                    notice = error.message,
                )
            }
        }
    }

    private fun completeAccountSignIn(token: String) {
        preferences.edit().putString("account_token", token).apply()
        accounts.registerPhone(
            token = token,
            deviceId = deviceId,
            label = Build.MODEL,
            model = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
        ) { result ->
            result.onSuccess {
                mutableState.value = mutableState.value.copy(
                    phase = AppPhase.DEVICES,
                    authenticating = false,
                )
                refreshDevices()
            }.onFailure { error ->
                mutableState.value = mutableState.value.copy(
                    authenticating = false,
                    notice = error.message,
                )
            }
        }
    }

    fun refreshDevices() {
        val token = preferences.getString("account_token", "").orEmpty()
        if (token.isBlank()) {
            mutableState.value = TactUiState()
            return
        }
        accounts.devices(token) { result ->
            result.onSuccess { devices ->
                mutableState.value = mutableState.value.copy(
                    phase = AppPhase.DEVICES,
                    devices = devices,
                    notice = null,
                )
            }.onFailure { error -> showNotice(error.message ?: "Could not load devices") }
        }
    }

    fun connectDevice(device: AccountDevice) {
        if (!device.canConnect) return
        val accountToken = preferences.getString("account_token", "").orEmpty()
        mutableState.value = mutableState.value.copy(
            selectedDeviceId = device.id,
            notice = null,
        )
        accounts.connect(
            token = accountToken,
            targetDeviceId = device.id,
            clientDeviceId = deviceId,
            clientLabel = Build.MODEL,
        ) { result ->
            result.onSuccess { connection ->
                preferences.edit()
                    .putString("host", connection.host)
                    .putString("token", connection.token)
                    .apply()
                mutableState.value = mutableState.value.copy(
                    phase = AppPhase.DASHBOARD,
                    host = connection.targetLabel,
                    selectedDeviceId = null,
                )
                client.connect(connection.host, connection.port, connection.token)
            }.onFailure { error ->
                mutableState.value = mutableState.value.copy(
                    selectedDeviceId = null,
                    notice = error.message,
                )
            }
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

    fun navigate(screen: TactScreen) {
        mutableState.value = mutableState.value.copy(screen = screen)
    }

    fun action(id: String, payload: JSONObject = JSONObject()) {
        client.action(id, payload)
    }

    fun disconnect() {
        client.disconnect()
        preferences.edit().remove("host").remove("token").apply()
        mutableState.value = if (preferences.contains("account_token")) {
            TactUiState(phase = AppPhase.DEVICES)
        } else {
            TactUiState()
        }
        if (preferences.contains("account_token")) refreshDevices()
    }

    fun signOut() {
        val token = preferences.getString("account_token", "").orEmpty()
        client.disconnect()
        preferences.edit().clear().putString("device_id", deviceId).apply()
        mutableState.value = TactUiState()
        if (token.isNotBlank()) accounts.logout(token) {}
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

    fun showNotice(message: String) {
        mutableState.value = mutableState.value.copy(notice = message)
    }

    fun showConfigurationNotice(provider: String) {
        showNotice("$provider is not configured for this build")
    }

}
