package de.gummipunkt.crossy.ui.nav

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import de.gummipunkt.crossy.CrossyApp
import de.gummipunkt.crossy.ui.auth.LoginScreen
import de.gummipunkt.crossy.ui.main.MainScaffold
import de.gummipunkt.crossy.ui.onboarding.OnboardingScreen

@Composable
fun CrossyNavHost(startTabIndex: Int = 0) {
    val context = LocalContext.current
    val container = remember { (context.applicationContext as CrossyApp).container }
    val serverUrl by container.settingsStore.serverUrl.collectAsState(initial = null)
    val token by container.settingsStore.token.collectAsState(initial = null)

    val startDestination = when {
        serverUrl.isNullOrBlank() -> Routes.ONBOARDING
        token.isNullOrBlank() -> Routes.LOGIN
        else -> Routes.MAIN
    }

    val navController = rememberNavController()

    // Keep navigation in sync if auth/server state changes from outside (e.g. logout).
    LaunchedEffect(serverUrl, token) {
        val target = when {
            serverUrl.isNullOrBlank() -> Routes.ONBOARDING
            token.isNullOrBlank() -> Routes.LOGIN
            else -> Routes.MAIN
        }
        val currentRoute = navController.currentBackStackEntry?.destination?.route
        if (currentRoute != null && currentRoute != target) {
            navController.navigate(target) {
                popUpTo(navController.graph.startDestinationId) { inclusive = true }
                launchSingleTop = true
            }
        }
    }

    NavHost(navController = navController, startDestination = startDestination) {
        composable(Routes.ONBOARDING) {
            OnboardingScreen(
                onContinue = {
                    navController.navigate(Routes.LOGIN) {
                        popUpTo(Routes.ONBOARDING) { inclusive = true }
                    }
                }
            )
        }
        composable(Routes.LOGIN) {
            LoginScreen(
                onSignedIn = {
                    navController.navigate(Routes.MAIN) {
                        popUpTo(Routes.LOGIN) { inclusive = true }
                    }
                },
                onChangeServer = {
                    navController.navigate(Routes.ONBOARDING) {
                        popUpTo(Routes.LOGIN) { inclusive = true }
                    }
                }
            )
        }
        composable(Routes.MAIN) {
            MainScaffold(
                initialTab = startTabIndex,
                onChangeServer = {
                    navController.navigate(Routes.ONBOARDING) {
                        popUpTo(Routes.MAIN) { inclusive = true }
                    }
                },
                onSignedOut = {
                    navController.navigate(Routes.LOGIN) {
                        popUpTo(Routes.MAIN) { inclusive = true }
                    }
                }
            )
        }
    }
}
