package de.gummipunkt.crossy.data.repository

import android.os.Build
import de.gummipunkt.crossy.data.local.SettingsStore
import de.gummipunkt.crossy.data.remote.NetworkProvider
import de.gummipunkt.crossy.data.remote.dto.SignInRequest
import de.gummipunkt.crossy.data.remote.dto.UserDto
import kotlinx.coroutines.flow.Flow

class AuthRepository(
    private val network: NetworkProvider,
    private val settingsStore: SettingsStore
) {
    val token: Flow<String?> = settingsStore.token
    val userEmail: Flow<String?> = settingsStore.userEmail

    suspend fun signIn(email: String, password: String): Result<UserDto> = runCatching {
        val response = network.api.signIn(
            SignInRequest(
                email = email,
                password = password,
                deviceLabel = "${Build.MANUFACTURER} ${Build.MODEL}"
            )
        )
        settingsStore.setToken(response.token, response.user.email)
        response.user
    }

    suspend fun signOut() {
        runCatching { network.api.signOut() }
        settingsStore.clearToken()
    }

    suspend fun me(): Result<UserDto> = runCatching {
        network.api.me().user
    }
}
