package de.gummipunkt.crossy.ui.main

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import de.gummipunkt.crossy.R
import de.gummipunkt.crossy.ui.accounts.AccountsScreen
import de.gummipunkt.crossy.ui.composer.ComposerScreen
import de.gummipunkt.crossy.ui.settings.SettingsScreen
import de.gummipunkt.crossy.ui.timeline.TimelineScreen

@Composable
fun MainScaffold(
    initialTab: Int = 0,
    onChangeServer: () -> Unit,
    onSignedOut: () -> Unit
) {
    var selected by rememberSaveable { mutableStateOf(initialTab) }

    val tabs = listOf(
        Tab(stringResource(R.string.tab_timeline), Icons.Filled.Home),
        Tab(stringResource(R.string.tab_compose), Icons.Filled.Edit),
        Tab(stringResource(R.string.tab_accounts), Icons.Filled.AccountCircle),
        Tab(stringResource(R.string.tab_settings), Icons.Filled.Settings)
    )

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        selected = selected == index,
                        onClick = { selected = index },
                        icon = { Icon(tab.icon, contentDescription = tab.title) },
                        label = { Text(tab.title) }
                    )
                }
            }
        }
    ) { inner ->
        when (selected) {
            0 -> androidx.compose.foundation.layout.Box(Modifier.padding(inner)) { TimelineScreen() }
            1 -> androidx.compose.foundation.layout.Box(Modifier.padding(inner)) { ComposerScreen() }
            2 -> androidx.compose.foundation.layout.Box(Modifier.padding(inner)) { AccountsScreen() }
            else -> androidx.compose.foundation.layout.Box(Modifier.padding(inner)) {
                SettingsScreen(
                    onChangeServer = onChangeServer,
                    onSignedOut = onSignedOut
                )
            }
        }
    }
}

private data class Tab(
    val title: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector
)
