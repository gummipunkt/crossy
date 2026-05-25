package de.gummipunkt.crossy.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class DeliveryDto(
    val id: Long,
    val provider: String,
    val handle: String? = null,
    val status: String,
    @SerialName("provider_post_id") val providerPostId: String? = null,
    @SerialName("error_message") val errorMessage: String? = null,
    @SerialName("finished_at") val finishedAt: String? = null
)

@Serializable
data class CreatePostResponse(
    val id: Long,
    @SerialName("content_text") val contentText: String,
    val deliveries: List<DeliveryDto> = emptyList()
)

@Serializable
data class DeliveriesResponse(
    val deliveries: List<DeliveryDto> = emptyList()
)
