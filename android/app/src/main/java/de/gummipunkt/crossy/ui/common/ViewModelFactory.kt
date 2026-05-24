package de.gummipunkt.crossy.ui.common

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import de.gummipunkt.crossy.CrossyApp
import de.gummipunkt.crossy.data.AppContainer

@Composable
inline fun <reified VM : ViewModel> rememberAppViewModel(
    crossinline factory: (AppContainer) -> VM
): VM {
    val container = (LocalContext.current.applicationContext as CrossyApp).container
    return viewModel(
        modelClass = VM::class.java,
        factory = object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                @Suppress("UNCHECKED_CAST")
                return factory(container) as T
            }
        }
    )
}
