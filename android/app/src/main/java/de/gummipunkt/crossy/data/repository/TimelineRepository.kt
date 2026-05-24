package de.gummipunkt.crossy.data.repository

import de.gummipunkt.crossy.data.remote.NetworkProvider
import de.gummipunkt.crossy.data.remote.dto.TimelineItemDto

class TimelineRepository(private val network: NetworkProvider) {

    suspend fun fetch(limit: Int = 50): Result<List<TimelineItemDto>> = runCatching {
        network.api.timeline(limit).items
    }

    suspend fun action(
        provider: String,
        id: String,
        actionType: String,
        cid: String? = null
    ): Result<Unit> = runCatching {
        val response = network.api.timelineAction(provider, id, actionType, cid)
        if (!response.isSuccessful) {
            error("Server returned ${response.code()}")
        }
    }
}
