package de.gummipunkt.crossy.data.repository

import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import de.gummipunkt.crossy.data.remote.NetworkProvider
import de.gummipunkt.crossy.data.remote.dto.CreatePostResponse
import de.gummipunkt.crossy.data.remote.dto.DeliveryDto
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

data class MediaUpload(val uri: Uri, val alt: String)

class PostsRepository(
    private val network: NetworkProvider,
    private val context: Context
) {

    suspend fun create(
        contentText: String,
        contentWarning: String? = null,
        providerAccountIds: List<Long>,
        media: List<MediaUpload>
    ): Result<CreatePostResponse> = runCatching {
        val textPlain = "text/plain".toMediaTypeOrNull()

        val contentTextBody = contentText.toRequestBody(textPlain)
        val contentWarningBody = contentWarning?.takeIf { it.isNotBlank() }?.toRequestBody(textPlain)

        // Server expects `alts` as newline-separated values, one per media file.
        val altsBody = if (media.isNotEmpty()) {
            media.joinToString("\n") { it.alt }.toRequestBody(textPlain)
        } else null

        val providerParts = providerAccountIds.map { id ->
            MultipartBody.Part.createFormData("provider_account_ids[]", id.toString())
        }

        val fileParts = media.map { upload ->
            val (bytes, contentType, filename) = readMedia(upload.uri)
            val mediaType = contentType.toMediaTypeOrNull()
            val body = bytes.toRequestBody(mediaType)
            MultipartBody.Part.createFormData("files[]", filename, body)
        }

        network.api.createPost(
            contentText = contentTextBody,
            contentWarning = contentWarningBody,
            alts = altsBody,
            providerAccountIds = providerParts,
            files = fileParts
        )
    }

    suspend fun fetchDeliveries(postId: Long): Result<List<DeliveryDto>> = runCatching {
        network.api.deliveries(postId).deliveries
    }

    private fun readMedia(uri: Uri): Triple<ByteArray, String, String> {
        val resolver = context.contentResolver
        val mimeType = resolver.getType(uri) ?: "application/octet-stream"
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: "bin"

        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IOException("Konnte Medium nicht lesen: $uri")

        val filename = "upload_${System.currentTimeMillis()}.$extension"
        return Triple(bytes, mimeType, filename)
    }
}
