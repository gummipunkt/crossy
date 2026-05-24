package de.gummipunkt.crossy.data.local

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "crossy_settings")

class SettingsStore(private val context: Context) {

    private object Keys {
        val SERVER_URL = stringPreferencesKey("server_url")
        val TOKEN = stringPreferencesKey("api_token")
        val USER_EMAIL = stringPreferencesKey("user_email")
    }

    val serverUrl: Flow<String?> = context.dataStore.data.map { it[Keys.SERVER_URL] }
    val token: Flow<String?> = context.dataStore.data.map { it[Keys.TOKEN] }
    val userEmail: Flow<String?> = context.dataStore.data.map { it[Keys.USER_EMAIL] }

    suspend fun currentServerUrl(): String? = context.dataStore.data.first()[Keys.SERVER_URL]
    suspend fun currentToken(): String? = context.dataStore.data.first()[Keys.TOKEN]

    suspend fun setServerUrl(url: String) {
        context.dataStore.edit { it[Keys.SERVER_URL] = url }
    }

    suspend fun setToken(token: String, email: String) {
        context.dataStore.edit {
            it[Keys.TOKEN] = token
            it[Keys.USER_EMAIL] = email
        }
    }

    suspend fun clearToken() {
        context.dataStore.edit {
            it.remove(Keys.TOKEN)
            it.remove(Keys.USER_EMAIL)
        }
    }

    suspend fun clearAll() {
        context.dataStore.edit { it.clear() }
    }
}
