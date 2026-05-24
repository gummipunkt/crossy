package de.gummipunkt.crossy.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TimelineImageDto(
    val url: String? = null,
    val alt: String? = null
)

@Serializable
data class TimelineItemDto(
    val provider: String,
    val id: String,
    val author: String? = null,
    val content: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    val url: String? = null,
    val images: List<TimelineImageDto>? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("likes_count") val likesCount: Int = 0,
    @SerialName("reposts_count") val repostsCount: Int = 0,
    @SerialName("replies_count") val repliesCount: Int = 0,
    @SerialName("liked_by_me") val likedByMe: Boolean = false,
    @SerialName("reposted_by_me") val repostedByMe: Boolean = false,
    @SerialName("bookmarked_by_me") val bookmarkedByMe: Boolean = false,
    val cid: String? = null,
    @SerialName("reblogged_by") val rebloggedBy: String? = null
)

@Serializable
data class TimelineResponse(
    val items: List<TimelineItemDto> = emptyList()
)
