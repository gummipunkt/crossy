# Android-Handoff: Engagement & Notifications

Der Crossy-Server hat seit Sommer 2026 ein Engagement-System (Likes/Antworten/Reposts pro Post, pro Netzwerk, mit Author-Profilen) und einen aggregierten Notifications-Feed. Diese Datei beschreibt die JSON-API-Erweiterungen, damit die Android-App die gleichen Features wie das Web bekommt.

Server-URL (Prod): `https://crossy.ecow.dev`. Auth wie bisher: `Authorization: Bearer <api_token>`.

---

## Was ist neu am Server

1. Pro **Delivery** (eine Veröffentlichung an ein Netzwerk) werden Counts gespeichert: `like_count`, `reply_count`, `repost_count`, `metrics_fetched_at`, `metrics_error`.
2. Pro Delivery sind **Replies** (Tabelle `delivery_replies`) und **Reactions** (Tabelle `delivery_reactions` mit `kind = "like" | "repost"`) gespeichert — inkl. Author-Handle, Display-Name, Avatar-URL und Permalinks/Profile-URLs.
3. **Threads-Limitation:** Die Threads-API gibt keine individuellen Liker/Reposter zurück — nur Counts. `likes` / `reposts`-Arrays sind dort immer leer. Counts stimmen aber.
4. Sync läuft on-demand: jeder Aufruf von `posts#show`, `deliveries#index` oder `notifications#index` enqueued einen Background-Job für jede „stale" Delivery (>5 min alt) der letzten 14 Tage.

---

## Geänderte/neue Endpoints

### 1. `GET /api/v1/posts` (geändert)

Listet die letzten 50 Posts des Users. **Neu:** `engagement` pro Post mit aggregierten Totals über alle Netzwerke.

```json
{
  "posts": [
    {
      "id": 66,
      "content_text": "Kommen jetzt die Menschen aus den Tropen…",
      "content_warning": null,
      "created_at": "2026-06-29T07:18:54Z",
      "engagement": {
        "like_count": 0,
        "reply_count": 1,
        "repost_count": 0,
        "last_synced_at": "2026-06-29T20:13:55Z"  // ISO8601 oder null
      }
    }
  ]
}
```

### 2. `GET /api/v1/posts/:id` (geändert)

Wie bisher, aber:
- `engagement` (Totals) auf Post-Ebene
- jede Delivery hat zusätzlich ein `engagement`-Objekt (siehe unten)

### 3. `GET /api/v1/posts/:post_id/deliveries` (geändert)

Liefert pro Delivery jetzt das `engagement`-Objekt mit Counts, Replies, Likes und Reposts inline.

```json
{
  "deliveries": [
    {
      "id": 156,
      "provider": "mastodon",         // mastodon | bluesky | threads | nostr
      "handle": "gummipunkt",
      "status": "succeeded",          // queued | in_progress | awaiting_signature | succeeded | failed
      "provider_post_id": "11678…",
      "error_message": null,
      "finished_at": "2026-06-21T17:17:06Z",
      "engagement": {
        "like_count": 1,
        "reply_count": 0,
        "repost_count": 0,
        "metrics_fetched_at": "2026-06-29T20:13:44Z",
        "metrics_error": null,         // string, wenn letzter Sync fehlschlug
        "syncable": true,              // false z.B. bei nostr oder failed deliveries
        "replies": [
          {
            "id": 25,
            "remote_id": "18119851954702681",
            "author_handle": "ht_seins",
            "author_name": null,
            "author_avatar_url": null,
            "content": "Ja 🥴",
            "posted_at": "2026-06-22T17:30:09Z",
            "permalink": "https://www.threads.com/@ht_seins/post/DZ5…"
          }
        ],
        "likes": [
          {
            "id": 37,
            "kind": "like",
            "remote_id": "116114131778969930",   // Author-ID/DID (idempotency key)
            "author_handle": "Sigourney",
            "author_name": null,                  // optional
            "author_avatar_url": "https://…",
            "author_url": "https://fnordon.de/@Sigourney",
            "reacted_at": null,                   // bei Mastodon meistens null
            "observed_at": "2026-06-29T19:04:02Z" // wann wir es entdeckt haben
          }
        ],
        "reposts": []
      }
    }
  ]
}
```

Inline-Limits: bis zu 50 Replies, 50 Likes, 50 Reposts pro Delivery.

### 4. `POST /api/v1/posts/:id/refresh_engagement` (neu)

Triggert sofort einen Sync für alle syncfähigen Deliveries des Posts. Antwort:

```json
{ "enqueued": 3 }
```

Status: `202 Accepted`. Die Jobs laufen asynchron. Nächster GET liefert die frischen Daten.

### 5. `GET /api/v1/notifications?limit=60` (neu)

Aggregierter chronologischer Feed über alle Netzwerke. Default `limit=60`, max `200`.

```json
{
  "fetched_at": "2026-06-29T20:13:41Z",
  "items": [
    {
      "id": 44,
      "kind": "like",                   // reply | like | repost
      "provider": "mastodon",
      "event_at": "2026-06-29T19:04:10Z",   // wann es im Netzwerk passierte (kann null sein für Mastodon-Likes)
      "observed_at": "2026-06-29T19:04:10Z",// wann wir es entdeckt haben
      "post": {
        "id": 59,
        "content_text": "530? FÜNFHUNDERTDREIẞIG?…"
      },
      "delivery_id": 174,
      "author": {
        "handle": "Tagetes",
        "name": null,
        "avatar_url": "https://fnordon.de/avatars/original/missing.png",
        "url": "https://fnordon.de/@Tagetes"    // nur bei kind != reply
      },
      "content": "…",                   // nur bei kind == reply
      "permalink": "https://…"          // nur bei kind == reply
    }
  ]
}
```

Sortierung: `event_at DESC` (Fallback `observed_at`). Items sind eine Mischung aus Replies und Reactions; per `kind` unterscheidbar.

Beim Aufruf werden im Hintergrund Sync-Jobs für stale Deliveries enqueued — der Client kann also direkt nach dem Aufruf z.B. nach 2–5 s erneut pollen, um neue Items zu sehen.

---

## Empfohlene Android-Umsetzung

### DTOs (`data/remote/dto/`)

```kotlin
@Serializable
data class PostEngagementSummaryDto(
    @SerialName("like_count") val likeCount: Int = 0,
    @SerialName("reply_count") val replyCount: Int = 0,
    @SerialName("repost_count") val repostCount: Int = 0,
    @SerialName("last_synced_at") val lastSyncedAt: String? = null
)

@Serializable
data class DeliveryEngagementDto(
    @SerialName("like_count") val likeCount: Int = 0,
    @SerialName("reply_count") val replyCount: Int = 0,
    @SerialName("repost_count") val repostCount: Int = 0,
    @SerialName("metrics_fetched_at") val metricsFetchedAt: String? = null,
    @SerialName("metrics_error") val metricsError: String? = null,
    val syncable: Boolean = false,
    val replies: List<ReplyDto> = emptyList(),
    val likes: List<ReactionDto> = emptyList(),
    val reposts: List<ReactionDto> = emptyList()
)

@Serializable
data class ReplyDto(
    val id: Long,
    @SerialName("remote_id") val remoteId: String,
    @SerialName("author_handle") val authorHandle: String? = null,
    @SerialName("author_name") val authorName: String? = null,
    @SerialName("author_avatar_url") val authorAvatarUrl: String? = null,
    val content: String? = null,
    @SerialName("posted_at") val postedAt: String? = null,
    val permalink: String? = null
)

@Serializable
data class ReactionDto(
    val id: Long,
    val kind: String,                           // "like" | "repost"
    @SerialName("remote_id") val remoteId: String,
    @SerialName("author_handle") val authorHandle: String? = null,
    @SerialName("author_name") val authorName: String? = null,
    @SerialName("author_avatar_url") val authorAvatarUrl: String? = null,
    @SerialName("author_url") val authorUrl: String? = null,
    @SerialName("reacted_at") val reactedAt: String? = null,
    @SerialName("observed_at") val observedAt: String? = null
)

@Serializable
data class NotificationItemDto(
    val id: Long,
    val kind: String,                           // "reply" | "like" | "repost"
    val provider: String,                       // "mastodon" | "bluesky" | "threads"
    @SerialName("event_at") val eventAt: String? = null,
    @SerialName("observed_at") val observedAt: String? = null,
    val post: NotificationPostRefDto,
    @SerialName("delivery_id") val deliveryId: Long,
    val author: NotificationAuthorDto,
    val content: String? = null,                // nur bei kind == reply
    val permalink: String? = null               // nur bei kind == reply
)

@Serializable
data class NotificationPostRefDto(
    val id: Long,
    @SerialName("content_text") val contentText: String
)

@Serializable
data class NotificationAuthorDto(
    val handle: String? = null,
    val name: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val url: String? = null
)

@Serializable
data class NotificationsResponse(
    val items: List<NotificationItemDto> = emptyList(),
    @SerialName("fetched_at") val fetchedAt: String? = null
)

@Serializable
data class RefreshEngagementResponse(val enqueued: Int = 0)
```

**Bestehendes anpassen:**
- `DeliveryDto` um optional `engagement: DeliveryEngagementDto?` ergänzen
- `CreatePostResponse` / „Post-Detail"-DTO um optional `engagement: PostEngagementSummaryDto?` ergänzen
- Neuen Endpoint im `CrossyApi`-Interface:

```kotlin
@POST("api/v1/posts/{id}/refresh_engagement")
suspend fun refreshEngagement(@Path("id") postId: Long): RefreshEngagementResponse

@GET("api/v1/notifications")
suspend fun notifications(@Query("limit") limit: Int = 60): NotificationsResponse
```

### Begriffs-Klärung — Timeline vs. My Posts

Achtung: „Timeline" hat in Crossy zwei verschiedene Bedeutungen. Wichtig nicht zu verwechseln:

| Web-Pfad     | App-Begriff       | Endpoint                  | Inhalt                                                                  |
| ------------ | ----------------- | ------------------------- | ----------------------------------------------------------------------- |
| `/timeline`  | „Timeline"        | `GET /api/v1/timeline`    | Aggregierter Multi-Netzwerk-Feed (fremde Posts, eingeloggte Accounts)   |
| `/my`        | „My Posts" (neu!) | `GET /api/v1/posts`       | **Eigene** gesendete Posts mit Delivery-Status + Engagement-Totals      |

Die Android-App hat aktuell nur den ersten Tab („Timeline" = aggregierter Feed). „My Posts" fehlt komplett — bitte als eigenen Top-Level-Tab ergänzen.

### Screens (Compose)

1. **MyPostsScreen** (neu) — LazyColumn mit Cards aus `GET /api/v1/posts`:
   - Header: `Post #ID` + Datum
   - Body: `content_text` (max ~4 Zeilen, expand on tap)
   - Pro Delivery ein Chip in Netzwerk-Farbe: `Mastodon · succeeded`, `Bluesky · queued` etc.
   - Engagement-Zeile aus `post.engagement`: `♥ N · 💬 M · 🔁 K · aktualisiert vor X`
   - Tap → PostDetailScreen
   - Pull-to-Refresh ruft den Endpoint neu (löst beim Server auto-enqueue stale syncs aus)
2. **PostDetailScreen** (neu) — `GET /api/v1/posts/:id`:
   - Post-Body + CW
   - Pro Delivery-Card: Status-Chip, externe Post-ID, Counts-Zeile, aufklappbare Replies/Likes-Listen mit Avatar + Handle + Permalink
   - Button „Engagement aktualisieren" ruft `refreshEngagement(postId)` → Snackbar „Sync läuft" → nach 2–5 s erneuter GET
3. **NotificationsScreen** (neu) — LazyColumn mit `NotificationItemDto`-Karten:
   - Icon je nach `kind`: ♥ rosa / 💬 violett / 🔁 grün
   - Avatar + Author-Name/Handle + „hat geliked"/"hat geantwortet"/"hat reposted"
   - Network-Badge in Network-Farbe (Mastodon grün, Bluesky himmelblau, Threads bernstein)
   - Bei `kind == "reply"`: Reply-Content
   - Tap auf Post-Snippet → PostDetailScreen
   - Tap auf Author → external Browser auf `author.url` bzw. `permalink`
   - **Polling:** ViewModel mit `viewModelScope.launch { while (isActive) { refresh(); delay(30_000) } }` — pausieren via `Lifecycle.Event.ON_STOP`.

### Bottom-Nav / Drawer

Aktuelle Tabs: Timeline · Compose · Accounts · Settings (4).
Mit My Posts + Notifications wären's 6 — Material Design verträgt das gerade so. Empfohlene Reihenfolge:

`Timeline · My Posts · Notifications · Compose · Accounts · Settings`

Icon-Vorschläge (Material Symbols):
- My Posts: `Icons.Outlined.Inbox` oder `Icons.AutoMirrored.Outlined.Article`
- Notifications: `Icons.Outlined.Notifications`

Falls 6 Tabs zu eng wirken: Settings ins TopAppBar-Overflow-Menu verschieben (3-Punkt-Menü), dann bleiben 5 Tabs unten.

### Caveats

- **Threads-Likes-Liste ist leer**, auch wenn `like_count > 0`. UI sollte das nicht als „keine Likes" interpretieren — entweder Threads-Likes als „N Likes" ohne Avatare anzeigen, oder die Liste komplett weglassen und nur den Count.
- **Mastodon `reacted_at` ist meistens `null`** — API gibt keine Per-Like-Timestamps. Verwende `observed_at` als Fallback.
- **Reactions werden geprunt**, wenn der Liker zurückzieht — d.h. die ID einer Reaction ist nicht stabil über Zeit. Verwende `remote_id` (Author-DID/-ID), wenn du Reactions deduplizieren willst.
- **Pagination:** Notifications-Endpoint hat aktuell kein Pagination — `limit` ist Hard-Cap (max 200). Wenn der User scrollt und mehr will, müsstest du das später am Server ergänzen (z.B. `before_id`).

---

## Testen

API-Token issuen (im Rails-Container):
```ruby
ApiToken.issue!(user: User.find_by(email: "…"), device_label: "android-dev").raw_token
```

Beispiel-Curls (alle gegen `https://crossy.ecow.dev`):
```bash
curl -H "Authorization: Bearer $TOKEN" .../api/v1/posts
curl -H "Authorization: Bearer $TOKEN" .../api/v1/posts/53
curl -H "Authorization: Bearer $TOKEN" .../api/v1/posts/53/deliveries
curl -X POST -H "Authorization: Bearer $TOKEN" .../api/v1/posts/53/refresh_engagement
curl -H "Authorization: Bearer $TOKEN" ".../api/v1/notifications?limit=20"
```
