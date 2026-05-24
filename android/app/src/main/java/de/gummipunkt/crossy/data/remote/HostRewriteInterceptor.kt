package de.gummipunkt.crossy.data.remote

import kotlinx.coroutines.runBlocking
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/**
 * Replaces the placeholder host of every outgoing request with the
 * server URL that the user entered during onboarding. The Retrofit
 * instance is built once with a dummy base URL; the real one comes from
 * DataStore here so we don't need to rebuild Retrofit when the user
 * switches servers.
 */
class HostRewriteInterceptor(
    private val serverUrlProvider: suspend () -> String?
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val base = runBlocking { serverUrlProvider() }
            ?: throw IOException("Kein Crossy-Server konfiguriert.")
        val baseUrl = base.toHttpUrlOrNull() ?: throw IOException("Ungültige Server-URL: $base")

        val original = chain.request()
        val newUrl = original.url.newBuilder()
            .scheme(baseUrl.scheme)
            .host(baseUrl.host)
            .port(baseUrl.port)
            .build()

        return chain.proceed(original.newBuilder().url(newUrl).build())
    }
}
