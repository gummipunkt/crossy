package de.gummipunkt.crossy.data

import android.content.Context
import de.gummipunkt.crossy.data.local.SettingsStore
import de.gummipunkt.crossy.data.remote.NetworkProvider
import de.gummipunkt.crossy.data.repository.AuthRepository
import de.gummipunkt.crossy.data.repository.PostsRepository
import de.gummipunkt.crossy.data.repository.ProviderAccountsRepository
import de.gummipunkt.crossy.data.repository.TimelineRepository

class AppContainer(context: Context) {

    val appContext: Context = context.applicationContext

    val settingsStore = SettingsStore(appContext)

    private val networkProvider = NetworkProvider(settingsStore)

    val authRepository = AuthRepository(networkProvider, settingsStore)
    val timelineRepository = TimelineRepository(networkProvider)
    val postsRepository = PostsRepository(networkProvider, appContext)
    val providerAccountsRepository = ProviderAccountsRepository(networkProvider)
}
