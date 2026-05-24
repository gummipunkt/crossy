# Crossy für Android

Nativer Android-Client für [Crossy](../README.md). Sprich beim ersten Start
deine eigene Crossy-Instanz an, melde dich an und poste in mehrere
soziale Netzwerke gleichzeitig — direkt aus der App.

## Status

Etappe 1 (dieser Stand):

- Server-URL beim ersten Start
- Login per E-Mail + Passwort (Token-Auth über `/api/v1/auth/sign_in`)
- Timeline (aggregiert) mit Pull-to-Refresh, Like/Repost (optimistisch)
- Composer mit Galerie-Picker, Alt-Text und Provider-Auswahl
- Verbundene Konten: Mastodon, Bluesky (nativ), Threads (Custom Tab)
- Share-Intent: aus anderen Apps „Teilen → Crossy" befüllt den Composer
- Material You (dynamische Farben ab Android 12), Dark Mode automatisch
- Adaptive App-Icon inkl. Monochrome-Layer für Android 13+ Themed Icons
- „Server wechseln" + Logout im Einstellungen-Tab

Nicht in Etappe 1: nativer Nostr-Flow (Nostr-Konten erscheinen daher nicht
im Composer; nutze dafür weiter den Web-Composer mit NIP-07).

## Voraussetzungen

- Android Studio Ladybug oder neuer (Kotlin 2.1, AGP 8.7)
- JDK 17
- Eine erreichbare Crossy-Instanz mit aktivem `/api/v1` (siehe
  Setup-Schritte in `../README.md`)

## Erste Schritte

```bash
# In Android Studio:
File → Open → Verzeichnis „android/" wählen
# Beim ersten Sync generiert Android Studio den Gradle-Wrapper automatisch.
```

Alternativ per CLI, falls Gradle 8.10+ installiert ist:

```bash
cd android
gradle wrapper           # einmalig — erzeugt gradlew + gradle-wrapper.jar
./gradlew assembleDebug  # baut die APK
```

Die debug-APK landet unter
`app/build/outputs/apk/debug/app-debug.apk` und hat den
Application-ID-Suffix `.debug`, damit sie parallel zu einer Release-Version
installiert werden kann.

## Konfiguration

Es gibt keine fest verdrahteten Server-URLs — die Adresse trägst du beim
ersten App-Start ein und liegt danach im DataStore. Im Einstellungen-Tab
kannst du den Server jederzeit wieder wechseln.

Die App spricht ausschließlich `https://<dein-server>/api/v1/*`. CORS und
Bearer-Auth werden serverseitig durch die Änderungen in dieser PR
freigeschaltet — siehe Root-`README.md`.

## Architektur (Kurz)

```
de.gummipunkt.crossy/
├── CrossyApp.kt          Application + AppContainer (manuelles DI)
├── MainActivity.kt       Single-Activity host, behandelt Share-Intents
├── data/
│   ├── local/SettingsStore.kt        DataStore: Server-URL + Token + Email
│   ├── remote/                       Retrofit + OkHttp
│   │   ├── CrossyApi.kt              Endpoint-Interface
│   │   ├── HostRewriteInterceptor    Setzt Server-URL pro Request neu
│   │   ├── AuthInterceptor           Hängt den Bearer-Token an
│   │   └── dto/                      Serializable Responses
│   └── repository/                   Auth / Timeline / Posts / Accounts
└── ui/
    ├── theme/                        Material You + Dark Mode
    ├── nav/                          NavGraph + Routes
    ├── onboarding/                   Server-URL eingeben
    ├── auth/                         Login
    ├── main/MainScaffold.kt          Bottom-Navigation
    ├── timeline/                     Pull-to-Refresh, Like/Repost
    ├── composer/                     Text + Medien + Alt-Text + Provider
    ├── accounts/                     Mastodon/Bluesky/Threads-CTA
    └── settings/                     Server wechseln, Logout
```

`HostRewriteInterceptor` ist der Trick, der „Server beim Start eingeben"
ermöglicht, ohne Retrofit zur Laufzeit neu aufzubauen: Retrofit bekommt
eine Platzhalter-Base-URL, und der Interceptor ersetzt Scheme/Host/Port
jedes Requests aus dem aktuellen DataStore-Wert.

## Bekannte To-Dos / Etappe 2

- Nostr-Signing nativ (z. B. via Android Keystore + Schlüssel-Import)
- Threads-OAuth: Rückkanal über App-Links statt Custom Tab + Re-Login
- Push-Benachrichtigungen (Web Push → FCM Bridge serverseitig)
- Eigene Posts-Tab (analog `/my` in der Web-UI)
- Mehrsprachigkeit (aktuell nur Deutsch)
