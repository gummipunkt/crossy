package de.gummipunkt.crossy.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SignInRequest(
    val email: String,
    val password: String,
    @SerialName("device_label") val deviceLabel: String? = null
)

@Serializable
data class SignInResponse(
    val token: String,
    @SerialName("token_id") val tokenId: Long,
    val user: UserDto
)

@Serializable
data class UserDto(
    val id: Long,
    val email: String,
    @SerialName("display_name") val displayName: String? = null,
    val admin: Boolean = false
)

@Serializable
data class MeResponse(val user: UserDto)

@Serializable
data class ErrorResponse(val error: String? = null)
