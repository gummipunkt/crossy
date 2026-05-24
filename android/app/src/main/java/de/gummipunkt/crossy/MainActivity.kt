package de.gummipunkt.crossy

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import de.gummipunkt.crossy.ui.common.SharedContent
import de.gummipunkt.crossy.ui.common.SharedContentHolder
import de.gummipunkt.crossy.ui.nav.CrossyNavHost
import de.gummipunkt.crossy.ui.theme.CrossyTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        handleSharedIntent(intent)
        val openedFromShare = SharedContentHolder.pending != null

        setContent {
            CrossyTheme {
                val startTab = remember { mutableStateOf(if (openedFromShare) 1 else 0) }
                CrossyNavHost(startTabIndex = startTab.value)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                val image = imageUri(intent)
                if (!text.isNullOrBlank() || image != null) {
                    SharedContentHolder.pending = SharedContent(
                        text = text,
                        images = listOfNotNull(image)
                    )
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                val uris: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                if (!text.isNullOrBlank() || !uris.isNullOrEmpty()) {
                    SharedContentHolder.pending = SharedContent(
                        text = text,
                        images = uris?.toList().orEmpty()
                    )
                }
            }
        }
    }

    private fun imageUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
}
