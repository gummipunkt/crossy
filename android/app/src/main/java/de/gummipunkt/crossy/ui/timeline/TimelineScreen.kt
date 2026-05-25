package de.gummipunkt.crossy.ui.timeline

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import de.gummipunkt.crossy.R
import de.gummipunkt.crossy.data.AppContainer
import de.gummipunkt.crossy.data.remote.dto.TimelineItemDto
import de.gummipunkt.crossy.ui.common.rememberAppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimelineScreen() {
    val vm = rememberAppViewModel { container: AppContainer ->
        TimelineViewModel(container.timelineRepository)
    }
    val state by vm.state.collectAsStateWithLifecycle()

    PullToRefreshBox(
        isRefreshing = state.refreshing,
        onRefresh = vm::refresh,
        modifier = Modifier.fillMaxSize()
    ) {
        when {
            state.initialLoad && state.items.isEmpty() ->
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            state.items.isEmpty() ->
                Box(
                    Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        stringResource(R.string.timeline_empty),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            else ->
                LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(state.items, key = { "${it.provider}:${it.id}" }) { item ->
                        TimelineItemRow(
                            item = item,
                            onLike = { vm.toggleLike(item) },
                            onRepost = { vm.toggleRepost(item) }
                        )
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    }
                }
        }
    }
}

@Composable
private fun TimelineItemRow(
    item: TimelineItemDto,
    onLike: () -> Unit,
    onRepost: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        AsyncImage(
            model = item.avatarUrl,
            contentDescription = stringResource(R.string.cd_avatar),
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
        )
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = item.author ?: "—",
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(Modifier.width(8.dp))
                ProviderBadge(item.provider)
            }
            if (item.rebloggedBy != null) {
                Text(
                    text = "↻ ${item.rebloggedBy}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(Modifier.height(4.dp))
            Text(
                text = item.content.orEmpty(),
                style = MaterialTheme.typography.bodyLarge
            )

            item.images?.firstOrNull()?.url?.let { url ->
                Spacer(Modifier.height(8.dp))
                AsyncImage(
                    model = url,
                    contentDescription = item.images.firstOrNull()?.alt,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp)
                        .clip(RoundedCornerShape(12.dp))
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                IconButton(onClick = onLike) {
                    Icon(
                        imageVector = if (item.likedByMe) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                        tint = if (item.likedByMe) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        contentDescription = stringResource(R.string.cd_like)
                    )
                }
                Text(
                    text = item.likesCount.toString(),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.align(Alignment.CenterVertically)
                )
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = onRepost) {
                    Icon(
                        imageVector = Icons.Filled.Repeat,
                        tint = if (item.repostedByMe) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        contentDescription = stringResource(R.string.cd_repost)
                    )
                }
                Text(
                    text = item.repostsCount.toString(),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.align(Alignment.CenterVertically)
                )
            }
        }
    }
}

@Composable
private fun ProviderBadge(provider: String) {
    val color = when (provider) {
        "mastodon" -> Color(0xFF6364FF)
        "bluesky"  -> Color(0xFF0085FF)
        "threads"  -> Color(0xFF000000)
        "nostr"    -> Color(0xFF8E44AD)
        else       -> MaterialTheme.colorScheme.tertiary
    }
    Text(
        text = provider,
        color = Color.White,
        style = MaterialTheme.typography.labelSmall,
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(color)
            .padding(horizontal = 6.dp, vertical = 2.dp)
    )
}
