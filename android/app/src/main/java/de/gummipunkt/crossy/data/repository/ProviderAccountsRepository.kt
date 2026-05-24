package de.gummipunkt.crossy.data.repository

import de.gummipunkt.crossy.data.remote.NetworkProvider
import de.gummipunkt.crossy.data.remote.dto.ProviderAccountDto

class ProviderAccountsRepository(private val network: NetworkProvider) {

    suspend fun list(): Result<List<ProviderAccountDto>> = runCatching {
        network.api.providerAccounts().providerAccounts
    }

    suspend fun connectMastodon(
        handle: String,
        instance: String,
        accessToken: String
    ): Result<ProviderAccountDto> = runCatching {
        network.api.connectMastodon(
            handle = handle,
            instance = instance,
            accessToken = accessToken
        ).providerAccount
    }

    suspend fun connectBluesky(
        handle: String,
        appPassword: String,
        instance: String? = null
    ): Result<ProviderAccountDto> = runCatching {
        network.api.connectBluesky(
            handle = handle,
            appPassword = appPassword,
            instance = instance?.takeIf { it.isNotBlank() }
        ).providerAccount
    }

    suspend fun delete(id: Long): Result<Unit> = runCatching {
        val response = network.api.deleteProviderAccount(id)
        if (!response.isSuccessful) error("Server returned ${response.code()}")
    }
}
