package de.gummipunkt.crossy.ui.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

// Brand seed: a Crossy-ish blue. Used as fallback on devices without
// Material You (Android < 12). Material You overrides this on 12+.
private val SeedPrimary = Color(0xFF3A7BD5)
private val SeedSecondary = Color(0xFF6FA8DC)
private val SeedTertiary = Color(0xFFA8C4E8)

val CrossyLightColors = lightColorScheme(
    primary = SeedPrimary,
    secondary = SeedSecondary,
    tertiary = SeedTertiary
)

val CrossyDarkColors = darkColorScheme(
    primary = Color(0xFF98C1FF),
    secondary = Color(0xFFB8CFE8),
    tertiary = Color(0xFFCBD9EC)
)
