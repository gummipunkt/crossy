package de.gummipunkt.crossy.ui.accounts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.gummipunkt.crossy.data.remote.dto.ProviderAccountDto
import de.gummipunkt.crossy.data.repository.ProviderAccountsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class AccountsState(
    val accounts: List<ProviderAccountDto> = emptyList(),
    val loading: Boolean = true,
    val error: String? = null,
    val saving: Boolean = false
)

class AccountsViewModel(
    private val repository: ProviderAccountsRepository
) : ViewModel() {

    private val _state = MutableStateFlow(AccountsState())
    val state: StateFlow<AccountsState> = _state

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            repository.list()
                .onSuccess { _state.value = AccountsState(accounts = it, loading = false) }
                .onFailure {
                    _state.value = _state.value.copy(loading = false, error = it.message)
                }
        }
    }

    fun addMastodon(handle: String, instance: String, token: String, onDone: () -> Unit) {
        viewModelScope.launch {
            _state.value = _state.value.copy(saving = true, error = null)
            repository.connectMastodon(handle, instance, token)
                .onSuccess {
                    _state.value = _state.value.copy(saving = false)
                    onDone(); load()
                }
                .onFailure {
                    _state.value = _state.value.copy(saving = false, error = it.message)
                }
        }
    }

    fun addBluesky(handle: String, appPassword: String, instance: String?, onDone: () -> Unit) {
        viewModelScope.launch {
            _state.value = _state.value.copy(saving = true, error = null)
            repository.connectBluesky(handle, appPassword, instance)
                .onSuccess {
                    _state.value = _state.value.copy(saving = false)
                    onDone(); load()
                }
                .onFailure {
                    _state.value = _state.value.copy(saving = false, error = it.message)
                }
        }
    }

    fun delete(id: Long) {
        viewModelScope.launch {
            repository.delete(id).onSuccess { load() }
        }
    }
}
