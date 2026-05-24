package de.gummipunkt.crossy.ui.timeline

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.gummipunkt.crossy.data.remote.dto.TimelineItemDto
import de.gummipunkt.crossy.data.repository.TimelineRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class TimelineState(
    val items: List<TimelineItemDto> = emptyList(),
    val refreshing: Boolean = false,
    val initialLoad: Boolean = true,
    val error: String? = null
)

class TimelineViewModel(
    private val timelineRepository: TimelineRepository
) : ViewModel() {

    private val _state = MutableStateFlow(TimelineState())
    val state: StateFlow<TimelineState> = _state

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _state.value = _state.value.copy(refreshing = true, error = null)
            timelineRepository.fetch()
                .onSuccess { items ->
                    _state.value = TimelineState(
                        items = items,
                        refreshing = false,
                        initialLoad = false,
                        error = null
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        refreshing = false,
                        initialLoad = false,
                        error = e.message ?: "Fehler beim Laden"
                    )
                }
        }
    }

    fun toggleLike(item: TimelineItemDto) {
        // Optimistic UI
        val updated = item.copy(
            likedByMe = !item.likedByMe,
            likesCount = item.likesCount + if (item.likedByMe) -1 else 1
        )
        _state.value = _state.value.copy(items = _state.value.items.map { if (it.id == item.id && it.provider == item.provider) updated else it })

        viewModelScope.launch {
            timelineRepository.action(item.provider, item.id, "like", item.cid)
                .onFailure { rollback(item) }
        }
    }

    fun toggleRepost(item: TimelineItemDto) {
        val updated = item.copy(
            repostedByMe = !item.repostedByMe,
            repostsCount = item.repostsCount + if (item.repostedByMe) -1 else 1
        )
        _state.value = _state.value.copy(items = _state.value.items.map { if (it.id == item.id && it.provider == item.provider) updated else it })

        viewModelScope.launch {
            timelineRepository.action(item.provider, item.id, "repost", item.cid)
                .onFailure { rollback(item) }
        }
    }

    private fun rollback(original: TimelineItemDto) {
        _state.value = _state.value.copy(
            items = _state.value.items.map { if (it.id == original.id && it.provider == original.provider) original else it },
            error = "Aktion fehlgeschlagen"
        )
    }
}
