package de.gummipunkt.crossy.ui.accounts

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.collectAsState
import de.gummipunkt.crossy.R
import de.gummipunkt.crossy.data.AppContainer
import de.gummipunkt.crossy.ui.common.rememberAppViewModel

@Composable
fun AccountsScreen() {
    val vm = rememberAppViewModel { container: AppContainer ->
        AccountsViewModel(container.providerAccountsRepository)
    }
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val container = (context.applicationContext as de.gummipunkt.crossy.CrossyApp).container
    val serverUrl by container.settingsStore.serverUrl.collectAsState(initial = null)

    var showAdd by remember { mutableStateOf(false) }

    Scaffold(
        floatingActionButton = {
            ExtendedFloatingActionButton(
                text = { Text(stringResource(R.string.accounts_add)) },
                icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                onClick = { showAdd = true }
            )
        }
    ) { inner ->
        Box(modifier = Modifier.fillMaxSize().padding(inner)) {
            when {
                state.loading ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                state.accounts.isEmpty() ->
                    Box(
                        Modifier.fillMaxSize().padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            stringResource(R.string.accounts_empty),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                else ->
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        items(state.accounts, key = { it.id }) { account ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = account.provider,
                                        style = MaterialTheme.typography.titleMedium
                                    )
                                    Text(
                                        text = account.handle.orEmpty() +
                                            (account.instance?.let { " @ $it" } ?: ""),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                IconButton(onClick = { vm.delete(account.id) }) {
                                    Icon(
                                        Icons.Filled.Delete,
                                        contentDescription = stringResource(R.string.accounts_delete)
                                    )
                                }
                            }
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        }
                    }
            }
        }
    }

    if (showAdd) {
        AddAccountDialog(
            saving = state.saving,
            error = state.error,
            onDismiss = { showAdd = false },
            onMastodon = { h, i, t -> vm.addMastodon(h, i, t) { showAdd = false } },
            onBluesky = { h, p, i -> vm.addBluesky(h, p, i) { showAdd = false } },
            onThreads = {
                val url = serverUrl ?: return@AddAccountDialog
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("$url/auth/threads"))
                context.startActivity(intent)
                showAdd = false
            }
        )
    }
}

@Composable
private fun AddAccountDialog(
    saving: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onMastodon: (handle: String, instance: String, token: String) -> Unit,
    onBluesky: (handle: String, appPassword: String, instance: String?) -> Unit,
    onThreads: () -> Unit
) {
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf(
        stringResource(R.string.provider_mastodon),
        stringResource(R.string.provider_bluesky),
        stringResource(R.string.provider_threads)
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Abbrechen") } },
        title = { Text(stringResource(R.string.accounts_pick_provider)) },
        text = {
            Column {
                TabRow(selectedTabIndex = tab) {
                    tabs.forEachIndexed { i, label ->
                        Tab(
                            selected = tab == i,
                            onClick = { tab = i },
                            text = { Text(label) }
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                when (tab) {
                    0 -> MastodonForm(saving, error, onMastodon)
                    1 -> BlueskyForm(saving, error, onBluesky)
                    2 -> ThreadsCta(onConnect = onThreads)
                }
            }
        }
    )
}

@Composable
private fun MastodonForm(
    saving: Boolean,
    error: String?,
    onSubmit: (String, String, String) -> Unit
) {
    var handle by remember { mutableStateOf("") }
    var instance by remember { mutableStateOf("") }
    var token by remember { mutableStateOf("") }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = instance, onValueChange = { instance = it },
            label = { Text(stringResource(R.string.mastodon_instance)) },
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = handle, onValueChange = { handle = it },
            label = { Text(stringResource(R.string.mastodon_handle)) },
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = token, onValueChange = { token = it },
            label = { Text(stringResource(R.string.mastodon_token)) },
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        if (error != null) Text(error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        Button(
            onClick = { onSubmit(handle.trim(), instance.trim(), token.trim()) },
            enabled = !saving && handle.isNotBlank() && instance.isNotBlank() && token.isNotBlank(),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(R.string.connect))
        }
    }
}

@Composable
private fun BlueskyForm(
    saving: Boolean,
    error: String?,
    onSubmit: (String, String, String?) -> Unit
) {
    var handle by remember { mutableStateOf("") }
    var pw by remember { mutableStateOf("") }
    var instance by remember { mutableStateOf("") }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = handle, onValueChange = { handle = it },
            label = { Text(stringResource(R.string.bluesky_handle)) },
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = pw, onValueChange = { pw = it },
            label = { Text(stringResource(R.string.bluesky_app_password)) },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = instance, onValueChange = { instance = it },
            label = { Text("PDS-URL (optional)") },
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        if (error != null) Text(error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        Button(
            onClick = { onSubmit(handle.trim(), pw, instance.trim().ifBlank { null }) },
            enabled = !saving && handle.isNotBlank() && pw.isNotBlank(),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(R.string.connect))
        }
    }
}

@Composable
private fun ThreadsCta(onConnect: () -> Unit) {
    Column {
        Text(
            stringResource(R.string.threads_via_browser),
            style = MaterialTheme.typography.bodyMedium
        )
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onConnect, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.open_in_browser))
        }
    }
}
