package com.tact.app

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import org.json.JSONObject

@Composable
fun ActionCatalogScreen(snapshot: JSONObject, action: (String, JSONObject) -> Unit) {
    val array = snapshot.optJSONArray("actions")
    val actions = remember(array?.toString()) {
        buildList {
            if (array != null) for (index in 0 until array.length()) add(array.optString(index))
        }.filter(String::isNotBlank).sorted()
    }
    var selected by remember { mutableStateOf<String?>(null) }
    val groups = actions.groupBy { it.substringBefore('.') }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            Text("All host controls", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
            Text("Every capability advertised by the connected backend", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (actions.isEmpty()) item { Text("Waiting for the host capability catalog…") }
        groups.forEach { (group, entries) ->
            item { Text(group.replaceFirstChar(Char::uppercase), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 10.dp)) }
            items(entries, key = { it }) { id ->
                Card(
                    onClick = {
                        if (actionFields(id).isEmpty()) action(id, JSONObject()) else selected = id
                    },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                ) {
                    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Tune, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text(actionTitle(id), fontWeight = FontWeight.Medium)
                            Text(id, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Icon(Icons.Rounded.PlayArrow, "Run")
                    }
                }
            }
        }
    }

    selected?.let { id ->
        ActionPayloadDialog(id, onDismiss = { selected = null }) { payload ->
            action(id, payload)
            selected = null
        }
    }
}

@Composable
private fun ActionPayloadDialog(id: String, onDismiss: () -> Unit, onRun: (JSONObject) -> Unit) {
    val values = remember(id) { mutableStateMapOf<String, String>() }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(actionTitle(id)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                actionFields(id).forEach { field ->
                    OutlinedTextField(
                        value = values[field].orEmpty(),
                        onValueChange = { values[field] = it },
                        label = { Text(field.replace('_', ' ').replaceFirstChar(Char::uppercase)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                Text(id, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
            }
        },
        confirmButton = {
            Button(onClick = {
                onRun(JSONObject().also { payload -> values.filterValues(String::isNotBlank).forEach(payload::put) })
            }) { Text("Run") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

private fun actionTitle(id: String) = id.substringAfterLast('.').replace('_', ' ').replaceFirstChar(Char::uppercase)

private fun actionFields(id: String): List<String> = when {
    id == "clipboard.set" -> listOf("text")
    id == "context.override" -> listOf("app", "project")
    id.startsWith("docker.") && id != "docker.status" -> if (id == "docker.logs") listOf("name", "tail") else listOf("name")
    id == "git.commit" -> listOf("message", "path")
    id in listOf("git.switch_branch", "git.pull", "git.push") -> listOf("branch", "path")
    id in listOf("git.status", "git.branches", "git.add") -> listOf("path")
    id == "git.tree" -> listOf("path", "max_depth")
    id == "git.log" -> listOf("path", "limit")
    id == "media.volume" -> listOf("player", "value")
    id == "media.seek" -> listOf("player", "position")
    id in listOf("media.play_pause", "media.next", "media.previous") -> listOf("player")
    id.startsWith("project.") -> listOf("path")
    id == "system.open_url" -> listOf("url")
    id in listOf("system.open_terminal", "system.open_project", "system.set_workspace") -> listOf("path")
    id in listOf("system.volume", "system.brightness") -> listOf("value")
    id in listOf("system.open_app", "system.focus_app") -> listOf("app")
    id == "system.set_sink" -> listOf("sink")
    id == "system.set_source" -> listOf("source")
    id in listOf("vscode.open_workspace", "vscode.status") -> listOf("path")
    id == "vscode.run_task" -> listOf("task")
    id == "vscode.open_file" -> listOf("path", "line")
    id in listOf("window.focus", "window.minimize", "window.maximize", "window.close") -> listOf("title")
    id == "window.move" -> listOf("title", "desktop", "x", "y", "width", "height")
    id == "window.apply_layout" -> listOf("name")
    else -> emptyList()
}
