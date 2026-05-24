package de.gummipunkt.crossy.data.remote

import de.gummipunkt.crossy.data.remote.dto.CreatePostResponse
import de.gummipunkt.crossy.data.remote.dto.MeResponse
import de.gummipunkt.crossy.data.remote.dto.ProviderAccountResponse
import de.gummipunkt.crossy.data.remote.dto.ProviderAccountsResponse
import de.gummipunkt.crossy.data.remote.dto.SignInRequest
import de.gummipunkt.crossy.data.remote.dto.SignInResponse
import de.gummipunkt.crossy.data.remote.dto.TimelineResponse
import okhttp3.MultipartBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.Field
import retrofit2.http.FormUrlEncoded
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query

interface CrossyApi {

    @POST("api/v1/auth/sign_in")
    suspend fun signIn(@Body body: SignInRequest): SignInResponse

    @DELETE("api/v1/auth/sign_out")
    suspend fun signOut(): Response<Unit>

    @GET("api/v1/auth/me")
    suspend fun me(): MeResponse

    @GET("api/v1/timeline")
    suspend fun timeline(@Query("limit") limit: Int = 50): TimelineResponse

    @FormUrlEncoded
    @POST("api/v1/timeline/action")
    suspend fun timelineAction(
        @Field("provider") provider: String,
        @Field("id") id: String,
        @Field("action_type") actionType: String,
        @Field("cid") cid: String? = null
    ): Response<Unit>

    @GET("api/v1/provider_accounts")
    suspend fun providerAccounts(): ProviderAccountsResponse

    @FormUrlEncoded
    @POST("api/v1/provider_accounts")
    suspend fun connectMastodon(
        @Field("provider") provider: String = "mastodon",
        @Field("handle") handle: String,
        @Field("instance") instance: String,
        @Field("access_token") accessToken: String
    ): ProviderAccountResponse

    @FormUrlEncoded
    @POST("api/v1/provider_accounts")
    suspend fun connectBluesky(
        @Field("provider") provider: String = "bluesky",
        @Field("handle") handle: String,
        @Field("app_password") appPassword: String,
        @Field("instance") instance: String? = null
    ): ProviderAccountResponse

    @DELETE("api/v1/provider_accounts/{id}")
    suspend fun deleteProviderAccount(@Path("id") id: Long): Response<Unit>

    @Multipart
    @POST("api/v1/posts")
    suspend fun createPost(
        @Part("content_text") contentText: okhttp3.RequestBody,
        @Part("content_warning") contentWarning: okhttp3.RequestBody? = null,
        @Part("alts") alts: okhttp3.RequestBody? = null,
        @Part providerAccountIds: List<MultipartBody.Part> = emptyList(),
        @Part files: List<MultipartBody.Part> = emptyList()
    ): CreatePostResponse
}
