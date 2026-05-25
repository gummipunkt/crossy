package de.gummipunkt.crossy.ui.composer

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import de.gummipunkt.crossy.R
import de.gummipunkt.crossy.data.AppContainer
import de.gummipunkt.crossy.ui.common.SharedContentHolder
import de.gummipunkt.crossy.ui.common.rememberAppViewModel

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ComposerScreen() {
    val vm = rememberAppViewModel { container: AppContainer ->
        ComposerViewModel(container.postsRepository, container.providerAccountsRepository)
    }
    val state by vm.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        SharedContentHolder.pending?.let { shared ->
            vm.applyShared(shared.text, shared.images)
            SharedContentHolder.pending = null
        }
    }

    // Nach dem erfolgreichen Senden Fokus + Tastatur wegblenden,
    // damit man die Delivery-Badges und „Veröffentlicht" sieht.
    val keyboardController = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current
    LaunchedEffect(state.published) {
        if (state.published) {
            keyboardController?.hide()
            focusManager.clearFocus(force = true)
        }
    }

    val pickMedia = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 4)
    ) { uris ->
        if (uris.isNotEmpty()) vm.addMedia(uris)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .imePadding()
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 16.dp)
        ) {
        OutlinedTextField(
            value = state.text,
            onValueChange = vm::updateText,
            label = { Text(stringResource(R.string.composer_hint)) },
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
        )

        Spacer(Modifier.height(12.dp))
        OutlinedButton(
            onClick = {
                pickMedia.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
        ) {
            Icon(Icons.Filled.Image, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.composer_pick_media))
        }

        if (state.media.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            state.media.forEachIndexed { index, draft ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AsyncImage(
                        model = draft.uri,
                        contentDescription = null,
                        modifier = Modifier
                            .size(56.dp)
                            .clip(RoundedCornerShape(8.dp))
                    )
                    OutlinedTextField(
                        value = draft.alt,
                        onValueChange = { vm.updateAlt(index, it) },
                        label = { Text(stringResource(R.string.composer_alt_hint)) },
                        singleLine = true,
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 8.dp)
                    )
                    IconButton(onClick = { vm.removeMedia(index) }) {
                        Icon(Icons.Filled.Close, contentDescription = stringResource(R.string.composer_remove_media))
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))

        Text(
            stringResource(R.string.composer_choose_providers),
            style = MaterialTheme.typography.titleMedium
        )

        when {
            state.loadingProviders ->
                Row(modifier = Modifier.padding(vertical = 12.dp)) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                }
            state.providers.isEmpty() ->
                Text(
                    text = stringResource(R.string.composer_no_accounts),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(vertical = 12.dp)
                )
            else -> {
                Spacer(Modifier.height(8.dp))
                AssistChip(
                    onClick = vm::toggleAll,
                    label = {
                        Text(
                            stringResource(
                                if (state.allSelected) R.string.composer_deselect_all
                                else R.string.composer_select_all
                            )
                        )
                    }
                )
                Spacer(Modifier.height(8.dp))
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    state.providers.forEach { pa ->
                        val selected = pa.id in state.selectedProviderIds
                        FilterChip(
                            selected = selected,
                            onClick = { vm.toggleProvider(pa.id) },
                            label = { Text("${pa.provider}: ${pa.handle ?: ""}") },
                            leadingIcon = if (selected) {
                                {
                                    Icon(
                                        imageVector = Icons.Filled.Check,
                                        contentDescription = null,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            } else null
                        )
                    }
                }
            }
        }

        if (state.error != null) {
            Spacer(Modifier.height(8.dp))
            Text(
                text = state.error!!,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall
            )
        }
        if (state.published) {
            Spacer(Modifier.height(12.dp))
            Text(
                text = "✓ " + stringResource(R.string.composer_published),
                color = MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.titleMedium
            )
            if (state.deliveries.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.composer_deliveries),
                    style = MaterialTheme.typography.titleSmall
                )
                Spacer(Modifier.height(4.dp))
                state.deliveries.forEach { d ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = d.provider + (d.handle?.let { " · $it" } ?: ""),
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f)
                        )
                        DeliveryStatusBadge(d.status)
                    }
                }
            }
        }

        } // inner scroll column

        // Publish-Button fest am unteren Rand, immer sichtbar — auch bei
        // offener Tastatur (dank imePadding am äußeren Column).
        Button(
            onClick = vm::submit,
            enabled = !state.submitting && state.providers.isNotEmpty() && state.text.isNotBlank(),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
        ) {
            if (state.submitting) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
            } else {
                Text(stringResource(R.string.composer_publish))
            }
        }
    }
}

@Composable
private fun DeliveryStatusBadge(status: String) {
    val (label, bg) = when (status) {
        "succeeded"           -> "ok"        to MaterialTheme.colorScheme.primary
        "in_progress"         -> "läuft"     to MaterialTheme.colorScheme.tertiary
        "queued"              -> "wartet"    to MaterialTheme.colorScheme.secondary
        "awaiting_signature"  -> "signieren" to MaterialTheme.colorScheme.secondary
        "failed"              -> "Fehler"    to MaterialTheme.colorScheme.error
        else                  -> status      to MaterialTheme.colorScheme.secondary
    }
    val onBg = when (status) {
        "succeeded"  -> MaterialTheme.colorScheme.onPrimary
        "failed"     -> MaterialTheme.colorScheme.onError
        "in_progress" -> MaterialTheme.colorScheme.onTertiary
        else         -> MaterialTheme.colorScheme.onSecondary
    }
    Text(
        text = label,
        color = onBg,
        style = MaterialTheme.typography.labelSmall,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .padding(horizontal = 8.dp, vertical = 2.dp)
    )
}
