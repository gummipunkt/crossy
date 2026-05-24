package de.gummipunkt.crossy.ui.composer

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.gummipunkt.crossy.data.remote.dto.ProviderAccountDto
import de.gummipunkt.crossy.data.repository.MediaUpload
import de.gummipunkt.crossy.data.repository.PostsRepository
import de.gummipunkt.crossy.data.repository.ProviderAccountsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class MediaDraft(val uri: Uri, val alt: String = "")

data class ComposerState(
    val text: String = "",
    val media: List<MediaDraft> = emptyList(),
    val providers: List<ProviderAccountDto> = emptyList(),
    val selectedProviderIds: Set<Long> = emptySet(),
    val loadingProviders: Boolean = true,
    val submitting: Boolean = false,
    val error: String? = null,
    val published: Boolean = false
)

class ComposerViewModel(
    private val postsRepository: PostsRepository,
    private val providerAccountsRepository: ProviderAccountsRepository
) : ViewModel() {

    private val _state = MutableStateFlow(ComposerState())
    val state: StateFlow<ComposerState> = _state

    init {
        loadProviders()
    }

    fun applyShared(text: String?, images: List<Uri>) {
        _state.value = _state.value.copy(
            text = listOfNotNull(_state.value.text.takeIf { it.isNotBlank() }, text).joinToString("\n"),
            media = _state.value.media + images.map { MediaDraft(it) }
        )
    }

    private fun loadProviders() {
        viewModelScope.launch {
            _state.value = _state.value.copy(loadingProviders = true)
            providerAccountsRepository.list()
                .onSuccess { accounts ->
                    // Nostr requires NIP-07 in the browser, so we hide it from the mobile composer.
                    val postable = accounts.filter { it.provider != "nostr" }
                    _state.value = _state.value.copy(
                        providers = postable,
                        selectedProviderIds = postable.map { it.id }.toSet(),
                        loadingProviders = false
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(loadingProviders = false, error = e.message)
                }
        }
    }

    fun updateText(value: String) {
        _state.value = _state.value.copy(text = value, error = null, published = false)
    }

    fun toggleProvider(id: Long) {
        val current = _state.value.selectedProviderIds
        _state.value = _state.value.copy(
            selectedProviderIds = if (id in current) current - id else current + id
        )
    }

    fun toggleAll() {
        val all = _state.value.providers.map { it.id }.toSet()
        _state.value = _state.value.copy(
            selectedProviderIds = if (_state.value.selectedProviderIds == all) emptySet() else all
        )
    }

    fun addMedia(uris: List<Uri>) {
        _state.value = _state.value.copy(media = _state.value.media + uris.map { MediaDraft(it) })
    }

    fun updateAlt(index: Int, alt: String) {
        _state.value = _state.value.copy(
            media = _state.value.media.mapIndexed { i, m -> if (i == index) m.copy(alt = alt) else m }
        )
    }

    fun removeMedia(index: Int) {
        _state.value = _state.value.copy(
            media = _state.value.media.filterIndexed { i, _ -> i != index }
        )
    }

    fun submit() {
        val current = _state.value
        if (current.text.isBlank() || current.selectedProviderIds.isEmpty()) {
            _state.value = current.copy(error = "Text + mindestens ein Netzwerk wählen")
            return
        }
        viewModelScope.launch {
            _state.value = current.copy(submitting = true, error = null, published = false)
            postsRepository.create(
                contentText = current.text,
                providerAccountIds = current.selectedProviderIds.toList(),
                media = current.media.map { MediaUpload(it.uri, it.alt) }
            )
                .onSuccess {
                    _state.value = ComposerState(
                        providers = current.providers,
                        selectedProviderIds = current.selectedProviderIds,
                        published = true
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        submitting = false,
                        error = e.message ?: "Fehler"
                    )
                }
        }
    }
}
