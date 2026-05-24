package de.gummipunkt.crossy

import android.app.Application
import de.gummipunkt.crossy.data.AppContainer

class CrossyApp : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
