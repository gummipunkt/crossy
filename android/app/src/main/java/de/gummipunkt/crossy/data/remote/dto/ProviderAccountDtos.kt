package de.gummipunkt.crossy.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ProviderAccountDto(
    val id: Long,
    val provider: String,
    val handle: String? = null,
    val instance: String? = null,
    val status: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class ProviderAccountsResponse(
    @SerialName("provider_accounts") val providerAccounts: List<ProviderAccountDto> = emptyList()
)

@Serializable
data class ProviderAccountResponse(
    @SerialName("provider_account") val providerAccount: ProviderAccountDto
)
