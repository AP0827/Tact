package com.tact.app

import android.os.Bundle
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.Code
import androidx.compose.material.icons.rounded.Computer
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.DeveloperBoard
import androidx.compose.material.icons.rounded.DesktopWindows
import androidx.compose.material.icons.rounded.LaptopMac
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material.icons.rounded.TabletMac
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalTime

private val Cyan = Color(0xFF22D3EE)
private val Ink = Color(0xFF09090B)
private val Panel = Color(0xFF18181B)
private val Border = Color(0xFF2B2B30)

class MainActivity : ComponentActivity() {
    private val model: TactViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { TactApp(model) }
        handleAuthIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthIntent(intent)
    }

    private fun handleAuthIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "tact" && uri.host == "auth") {
            uri.getQueryParameter("code")?.let(model::completeWebSignIn)
            uri.getQueryParameter("error")?.let(model::showNotice)
        }
    }
}

@Composable
fun TactApp(model: TactViewModel = viewModel()) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val dark = isSystemInDarkTheme()
    val colors = when {
        android.os.Build.VERSION.SDK_INT >= 31 && dark -> dynamicDarkColorScheme(context)
        android.os.Build.VERSION.SDK_INT >= 31 -> dynamicLightColorScheme(context)
        dark -> darkColorScheme(primary = Cyan, secondary = Cyan, background = Ink, surface = Panel)
        else -> lightColorScheme(primary = Color(0xFF006874), secondary = Color(0xFF4A6267))
    }
    MaterialTheme(colorScheme = colors) {
        Surface(Modifier.fillMaxSize()) {
            when (state.phase) {
                AppPhase.AUTH -> AuthScreen(state, model)
                AppPhase.DEVICES -> DeviceSelectionScreen(state, model)
                AppPhase.DASHBOARD -> Dashboard(state, model)
            }
        }
    }
}

@Composable
private fun AuthScreen(state: TactUiState, model: TactViewModel) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var direct by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var host by remember { mutableStateOf("") }
    var otp by remember { mutableStateOf("") }
    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        LazyColumn(
            Modifier.fillMaxWidth().width(460.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(vertical = 32.dp),
        ) {
          item {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(56.dp).background(Cyan, RoundedCornerShape(18.dp)), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Bolt, null, tint = Ink, modifier = Modifier.size(30.dp))
            }
            Text("Tact", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
            Text(
                "Your computer, within reach.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.titleMedium,
            )
            }
          }
          item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(onClick = { direct = false }, modifier = Modifier.weight(1f)) { Text("Account") }
                OutlinedButton(onClick = { direct = true }, modifier = Modifier.weight(1f)) { Text("IP + OTP") }
            }
          }
          if (!direct) {
            item {
              Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password") },
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(
                    onClick = { model.signIn(email, password) },
                    enabled = email.isNotBlank() && password.isNotBlank() && !state.authenticating,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                ) {
                    if (state.authenticating) {
                        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(10.dp))
                    }
                    Text(if (state.authenticating) "Signing in" else "Sign in")
                }
              }
            }
            item { HorizontalDivider() }
            item {
              Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = {
                        if (BuildConfig.TACT_GOOGLE_CLIENT_ID.isBlank()) {
                            model.showConfigurationNotice("Google Sign-In")
                            return@OutlinedButton
                        }
                        scope.launch {
                            runCatching {
                                val manager = CredentialManager.create(context)
                                val option = GetGoogleIdOption.Builder()
                                    .setServerClientId(BuildConfig.TACT_GOOGLE_CLIENT_ID)
                                    .setFilterByAuthorizedAccounts(false)
                                    .setAutoSelectEnabled(false)
                                    .build()
                                val response = manager.getCredential(
                                    context,
                                    GetCredentialRequest.Builder()
                                        .addCredentialOption(option)
                                        .build(),
                                )
                                val credential = response.credential
                                require(
                                    credential is CustomCredential &&
                                        credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                                )
                                GoogleIdTokenCredential.createFrom(credential.data).idToken
                            }.onSuccess { token -> model.signInProvider("google", token) }
                                .onFailure { model.showNotice(it.message ?: "Google Sign-In failed") }
                        }
                    },
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                ) { Text("Continue with Google") }
                OutlinedButton(
                    onClick = {
                        val url = "${BuildConfig.TACT_ACCOUNT_SERVICE_URL.trimEnd('/')}/api/auth/apple/start?redirect_uri=tact://auth/apple"
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    },
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                ) { Text("Continue with Apple") }
              }
            }
          } else {
          item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(
                value = host,
                onValueChange = { host = it },
                label = { Text("Computer address") },
                placeholder = { Text("192.168.1.42") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = otp,
                onValueChange = { otp = it.filter(Char::isDigit).take(6) },
                label = { Text("6-digit pairing code") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = { model.pair(host, otp) },
                enabled = host.isNotBlank() && otp.length == 6 && !state.pairing,
                modifier = Modifier.fillMaxWidth().height(52.dp),
            ) {
                if (state.pairing) {
                    CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.width(10.dp))
                    Text("Waiting for approval")
                } else {
                    Text("Pair securely")
                }
            }
            Text(
                "Pairing stays on your local network. The desktop agent only exposes allowlisted actions.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
            )
            }
          }
          }
          state.notice?.let { notice ->
            item {
                Text(notice, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
          }
        }
    }
}

@Composable
private fun DeviceSelectionScreen(state: TactUiState, model: TactViewModel) {
    Scaffold(
        topBar = {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Your devices", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
                    Text("Choose a computer to control", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                IconButton(onClick = model::refreshDevices) { Icon(Icons.Rounded.Refresh, "Refresh") }
                OutlinedButton(onClick = model::signOut) { Text("Sign out") }
            }
        },
    ) { padding ->
        LazyColumn(
            Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (state.devices.isEmpty()) {
                item { EmptyState("No computers are signed in to this account yet") }
            }
            items(state.devices, key = { it.id }) { device ->
                Card(
                    onClick = { model.connectDevice(device) },
                    enabled = device.canConnect,
                    shape = RoundedCornerShape(22.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                ) {
                    Row(Modifier.fillMaxWidth().padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            Modifier.size(52.dp).background(Cyan.copy(alpha = .12f), RoundedCornerShape(16.dp)),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(deviceIcon(device.platform), null, tint = Cyan, modifier = Modifier.size(27.dp))
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text(device.label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                listOf(device.model, device.platform).filter(String::isNotBlank).joinToString(" · "),
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                when {
                                    device.deviceType == "phone" || device.deviceType == "tablet" -> "This account device"
                                    device.active -> "Active now"
                                    else -> "Offline"
                                },
                                color = if (device.active) Color(0xFF34D399) else MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.labelMedium,
                            )
                        }
                        if (state.selectedDeviceId == device.id) CircularProgressIndicator(Modifier.size(24.dp))
                        else if (device.canConnect) Text("Connect", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
            state.notice?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
        }
    }
}

private fun deviceIcon(platform: String): ImageVector = when (platform.lowercase()) {
    "android" -> Icons.Rounded.PhoneAndroid
    "ios" -> Icons.Rounded.PhoneAndroid
    "ipados" -> Icons.Rounded.TabletMac
    "macos" -> Icons.Rounded.LaptopMac
    "windows" -> Icons.Rounded.DesktopWindows
    "linux" -> Icons.Rounded.Terminal
    else -> Icons.Rounded.Computer
}

private data class Destination(val screen: TactScreen, val label: String, val icon: ImageVector)

private val destinations = listOf(
    Destination(TactScreen.SYSTEM, "System", Icons.Rounded.Computer),
    Destination(TactScreen.DEVELOPER, "Developer", Icons.Rounded.Code),
    Destination(TactScreen.CONTROLS, "Controls", Icons.Rounded.Tune),
    Destination(TactScreen.MEDIA, "Media", Icons.Rounded.MusicNote),
    Destination(TactScreen.EVENTS, "Events", Icons.Rounded.Notifications),
    Destination(TactScreen.DECK, "Deck", Icons.Rounded.Dashboard),
)

@Composable
private fun Dashboard(state: TactUiState, model: TactViewModel) {
    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(state.notice) {
        state.notice?.let {
            snackbar.showSnackbar(it)
            model.clearNotice()
        }
    }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val expanded = maxWidth >= 720.dp
        Scaffold(
            snackbarHost = { SnackbarHost(snackbar) },
            bottomBar = {
                if (!expanded) {
                    NavigationBar {
                        destinations.forEach { destination ->
                            NavigationBarItem(
                                selected = state.screen == destination.screen,
                                onClick = { model.navigate(destination.screen) },
                                icon = { Icon(destination.icon, destination.label) },
                                label = { Text(destination.label) },
                            )
                        }
                    }
                }
            },
        ) { padding ->
            Row(Modifier.fillMaxSize().padding(padding)) {
                if (expanded) {
                    NavigationRail(modifier = Modifier.fillMaxHeight(), header = {
                        Box(Modifier.padding(12.dp).size(42.dp).background(Cyan, RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
                            Icon(Icons.Rounded.Bolt, "Tact", tint = Ink)
                        }
                    }) {
                        destinations.forEach { destination ->
                            NavigationRailItem(
                                selected = state.screen == destination.screen,
                                onClick = { model.navigate(destination.screen) },
                                icon = { Icon(destination.icon, destination.label) },
                                label = { Text(destination.label) },
                            )
                        }
                        Spacer(Modifier.weight(1f))
                        NavigationRailItem(
                            selected = state.screen == TactScreen.SETTINGS,
                            onClick = { model.navigate(TactScreen.SETTINGS) },
                            icon = { Icon(Icons.Rounded.Settings, "Settings") },
                            label = { Text("Settings") },
                        )
                    }
                }
                Column(Modifier.fillMaxSize()) {
                    AppHeader(state)
                    when (state.screen) {
                        TactScreen.SYSTEM -> SystemScreen(state, model::action)
                        TactScreen.DEVELOPER -> DeveloperScreen(state.snapshot, model::action)
                        TactScreen.CONTROLS -> ActionCatalogScreen(state.snapshot, model::action)
                        TactScreen.MEDIA -> MediaScreen(state.snapshot, model::action)
                        TactScreen.EVENTS -> EventsScreen(state.events)
                        TactScreen.DECK -> DeckScreen(model::action)
                        TactScreen.SETTINGS -> SettingsScreen(state, model::disconnect)
                    }
                }
            }
        }
    }
}

@Composable
private fun AppHeader(state: TactUiState) {
    val hour = LocalTime.now().hour
    val greeting = when (hour) { in 5..11 -> "Good morning"; in 12..16 -> "Good afternoon"; else -> "Good evening" }
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 18.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(greeting, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
            Text(
                if (state.connection == ConnectionState.CONNECTED) "${state.host} is connected and ready"
                else state.connection.name.lowercase().replaceFirstChar(Char::uppercase),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        ConnectionPill(state.connection)
    }
}

@Composable
private fun ConnectionPill(state: ConnectionState) {
    val color = when (state) {
        ConnectionState.CONNECTED -> Color(0xFF34D399)
        ConnectionState.ERROR -> Color(0xFFFB7185)
        else -> Color(0xFFFBBF24)
    }
    Surface(color = color.copy(alpha = .12f), shape = CircleShape) {
        Row(Modifier.padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(7.dp).background(color, CircleShape))
            Spacer(Modifier.width(7.dp))
            Text(state.name.lowercase().replaceFirstChar(Char::uppercase), color = color, style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
private fun SystemScreen(state: TactUiState, action: (String, JSONObject) -> Unit) {
    val system = state.snapshot.optJSONObject("system") ?: JSONObject()
    val battery = system.optJSONObject("battery")
    val metrics = listOf(
        "CPU" to system.number("cpu"),
        "Memory" to system.number("memory"),
        "Disk" to system.number("disk"),
        "Battery" to (battery?.number("percent") ?: system.number("battery")),
    )
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer), shape = RoundedCornerShape(24.dp)) {
                Row(Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(46.dp).background(Cyan.copy(alpha = .14f), RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.DeveloperBoard, null, tint = Cyan)
                    }
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text(state.host, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Text("Developer host · live telemetry", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Icon(Icons.Rounded.Bolt, "Live", tint = Cyan)
                }
            }
        }
        item {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(150.dp),
                modifier = Modifier.height(if (metrics.size > 2) 280.dp else 140.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                userScrollEnabled = false,
            ) {
                items(metrics) { (label, value) -> MetricCard(label, value) }
            }
        }
        item { SectionLabel("Quick controls") }
        item {
            val controls = listOf(
                Triple("Lock", "system.lock_screen", Icons.Rounded.Lock),
                Triple("Terminal", "system.open_terminal", Icons.Rounded.Terminal),
                Triple("Mute", "system.mute", Icons.AutoMirrored.Rounded.VolumeOff),
                Triple("Screenshot", "system.screenshot", Icons.Rounded.CameraAlt),
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                controls.forEach { (label, id, icon) ->
                    OutlinedButton(onClick = { action(id, JSONObject()) }, modifier = Modifier.weight(1f), contentPadding = PaddingValues(vertical = 14.dp)) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(icon, null)
                            Spacer(Modifier.height(5.dp))
                            Text(label, maxLines = 1, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(12.dp)) }
    }
}

@Composable
private fun MetricCard(label: String, value: Double?) {
    Card(shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)) {
        Column(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelLarge)
            Text(value?.let { "${it.toInt()}%" } ?: "—", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
            LinearProgressIndicator(
                progress = { ((value ?: 0.0) / 100.0).coerceIn(0.0, 1.0).toFloat() },
                modifier = Modifier.fillMaxWidth(),
                color = Cyan,
                trackColor = Border,
            )
        }
    }
}

@Composable
private fun DeveloperScreen(snapshot: JSONObject, action: (String, JSONObject) -> Unit) {
    val git = snapshot.optJSONObject("git") ?: snapshot.optJSONObject("workspace")?.optJSONObject("git") ?: JSONObject()
    val docker = snapshot.optJSONObject("docker") ?: JSONObject()
    val containers = docker.optJSONArray("containers") ?: JSONArray()
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item { SectionLabel("Repository") }
        item {
            NativeCard {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column {
                        Text(git.optString("branch", "No repository"), fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.titleLarge)
                        Text(
                            if (git.optBoolean("clean")) "Working tree clean" else "${git.optInt("changed_files")} changed files",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    AssistChip(onClick = {}, label = { Text("↑${git.optInt("ahead")} ↓${git.optInt("behind")}") })
                }
                Spacer(Modifier.height(16.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("Stage all" to "git.add", "Pull" to "git.pull", "Push" to "git.push").forEach { (label, id) ->
                        Button(onClick = { action(id, JSONObject()) }, modifier = Modifier.weight(1f)) { Text(label) }
                    }
                }
            }
        }
        item { SectionLabel("Docker · ${docker.optInt("count", containers.length())}") }
        if (containers.length() == 0) {
            item { EmptyState("No containers reported by the host") }
        } else {
            items(containers.toObjects()) { container ->
                NativeCard {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(9.dp).background(if (container.optString("state") == "running") Color(0xFF34D399) else Color(0xFFFBBF24), CircleShape))
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(container.optString("name"), fontWeight = FontWeight.Medium)
                            Text(container.optString("image"), color = MaterialTheme.colorScheme.onSurfaceVariant, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
                        }
                        IconButton(onClick = {
                            action("docker.restart", JSONObject().put("name", container.optString("name")))
                        }) { Icon(Icons.Rounded.Refresh, "Restart") }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(12.dp)) }
    }
}

@Composable
private fun MediaScreen(snapshot: JSONObject, action: (String, JSONObject) -> Unit) {
    val active = snapshot.optJSONObject("media")?.optJSONObject("active")
    Column(Modifier.fillMaxSize().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(.2f))
        Box(Modifier.size(220.dp).background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(32.dp)), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.MusicNote, null, tint = Cyan, modifier = Modifier.size(72.dp))
        }
        Spacer(Modifier.height(28.dp))
        Text(active?.optString("title")?.ifBlank { "Nothing playing" } ?: "Nothing playing", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
        Text(active?.optString("artist").orEmpty(), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(24.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            IconButton(onClick = { action("media.previous", JSONObject()) }) { Icon(Icons.Rounded.SkipPrevious, "Previous", modifier = Modifier.size(34.dp)) }
            FilledIconButton(onClick = { action("media.play_pause", JSONObject()) }, modifier = Modifier.size(64.dp)) {
                Icon(Icons.Rounded.PlayArrow, "Play or pause", modifier = Modifier.size(36.dp))
            }
            IconButton(onClick = { action("media.next", JSONObject()) }) { Icon(Icons.Rounded.SkipNext, "Next", modifier = Modifier.size(34.dp)) }
        }
        Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun EventsScreen(events: List<TactEvent>) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { SectionLabel("Live event feed") }
        if (events.isEmpty()) item { EmptyState("Events from Git, Docker, VS Code, and the host will appear here") }
        items(events, key = { it.id }) { event ->
            NativeCard {
                Row(verticalAlignment = Alignment.Top) {
                    Box(Modifier.size(36.dp).background(Cyan.copy(alpha = .12f), RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Notifications, null, tint = Cyan, modifier = Modifier.size(19.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(event.title, fontWeight = FontWeight.Medium)
                        Text(event.description, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (event.timestamp.isNotBlank()) Text(event.timestamp, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
private fun DeckScreen(action: (String, JSONObject) -> Unit) {
    val tiles = listOf(
        Triple("VS Code", "vscode.open_workspace", Icons.Rounded.Code),
        Triple("Terminal", "system.open_terminal", Icons.Rounded.Terminal),
        Triple("Stage all", "git.add", Icons.Rounded.DeveloperBoard),
        Triple("Screenshot", "system.screenshot", Icons.Rounded.CameraAlt),
        Triple("Pull", "git.pull", Icons.Rounded.Refresh),
        Triple("Push", "git.push", Icons.Rounded.Bolt),
        Triple("Play / pause", "media.play_pause", Icons.Rounded.PlayArrow),
        Triple("Mute", "system.mute", Icons.AutoMirrored.Rounded.VolumeOff),
    )
    LazyVerticalGrid(
        columns = GridCells.Adaptive(150.dp),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(tiles) { (label, id, icon) ->
            Card(
                onClick = { action(id, JSONObject()) },
                modifier = Modifier.height(140.dp),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            ) {
                Column(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.SpaceBetween) {
                    Icon(icon, null, tint = Cyan, modifier = Modifier.size(28.dp))
                    Text(label, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun SettingsScreen(state: TactUiState, disconnect: () -> Unit) {
    var diagnostics by remember { mutableStateOf(false) }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item { SectionLabel("Connection") }
        item {
            NativeCard {
                Text(state.host, style = MaterialTheme.typography.titleMedium, fontFamily = FontFamily.Monospace)
                Text(state.connection.name.lowercase().replaceFirstChar(Char::uppercase), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(14.dp))
                OutlinedButton(onClick = disconnect) { Text("Disconnect and forget host") }
            }
        }
        item { SectionLabel("Preferences") }
        item {
            NativeCard {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Extended diagnostics")
                        Text("Show protocol and latency details", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    }
                    Switch(checked = diagnostics, onCheckedChange = { diagnostics = it })
                }
                HorizontalDivider(Modifier.padding(vertical = 14.dp))
                Text("Tact Android 2.0", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun NativeCard(content: @Composable ColumnScope.() -> Unit) {
    Card(shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)) {
        Column(Modifier.fillMaxWidth().padding(18.dp), content = content)
    }
}

@Composable
private fun SectionLabel(label: String) {
    Text(label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun EmptyState(message: String) {
    Box(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(20.dp)).padding(28.dp), contentAlignment = Alignment.Center) {
        Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun JSONObject.number(key: String): Double? = if (has(key) && !isNull(key)) optDouble(key) else null

private fun JSONArray.toObjects(): List<JSONObject> = buildList {
    for (index in 0 until length()) optJSONObject(index)?.let(::add)
}
