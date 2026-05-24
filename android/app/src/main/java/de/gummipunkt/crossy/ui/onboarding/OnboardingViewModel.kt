package de.gummipunkt.crossy.ui.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.gummipunkt.crossy.data.local.SettingsStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class OnboardingState(
    val serverUrl: String = "",
    val saving: Boolean = false,
    val error: String? = null
)

class OnboardingViewModel(
    private val settingsStore: SettingsStore,
    initialServerUrl: String? = null
) : ViewModel() {

    private val _state = MutableStateFlow(OnboardingState(serverUrl = initialServerUrl ?: "https://"))
    val state: StateFlow<OnboardingState> = _state

    fun updateUrl(url: String) {
        _state.value = _state.value.copy(serverUrl = url, error = null)
    }

    fun save(onSaved: () -> Unit) {
        val raw = _state.value.serverUrl.trim()
        val normalized = normalize(raw)
        if (normalized == null) {
            _state.value = _state.value.copy(error = "invalid")
            return
        }
        viewModelScope.launch {
            _state.value = _state.value.copy(saving = true, error = null)
            settingsStore.setServerUrl(normalized)
            _state.value = _state.value.copy(saving = false)
            onSaved()
        }
    }

    private fun normalize(raw: String): String? {
        if (raw.isBlank()) return null
        val withScheme = if (raw.startsWith("http://") || raw.startsWith("https://")) raw else "https://$raw"
        val stripped = withScheme.trimEnd('/')
        // Basic sanity check: must have a host
        return runCatching { java.net.URL(stripped) }
            .getOrNull()
            ?.takeIf { !it.host.isNullOrBlank() }
            ?.let { stripped }
    }
}
