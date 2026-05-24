package de.gummipunkt.crossy.ui.common

import android.net.Uri

/**
 * Payload extracted from an incoming ACTION_SEND / ACTION_SEND_MULTIPLE
 * intent and handed to the Composer screen. Held in process memory only;
 * not persisted.
 */
data class SharedContent(
    val text: String? = null,
    val images: List<Uri> = emptyList()
) {
    val isEmpty: Boolean get() = text.isNullOrBlank() && images.isEmpty()
}

object SharedContentHolder {
    @Volatile var pending: SharedContent? = null
}
