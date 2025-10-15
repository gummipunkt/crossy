async function getCSRF() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.content : undefined
}

function ensureNIP07() {
  if (!window.nostr) {
    alert('Kein Nostr NIP-07 Signer im Browser gefunden. Bitte Erweiterung installieren oder den Download-Button nutzen.')
    return false
  }
  return true
}

async function connect() {
  if (!ensureNIP07()) return
  try {
    const pubkey = await window.nostr.getPublicKey()
    window.nostrPubkey = pubkey
    alert('Nostr verbunden: ' + pubkey)
  } catch (e) {
    alert('Nostr Verbindung fehlgeschlagen: ' + (e?.message || e))
  }
}

async function signAndPublish(postId, providerAccountId) {
  if (!ensureNIP07()) return
  try {
    // 1) Unsigned Event vom Server holen
    const prep = await fetch('/api/v1/nostr/prepare_event', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ post_id: postId, provider_account_id: providerAccountId })
    })
    if (!prep.ok) {
      return alert('Fehler bei prepare_event: ' + (await prep.text()))
    }
    const { event } = await prep.json()

    // 2) Pubkey aus NIP-07 (überschreibt zur Sicherheit)
    try {
      const pk = await window.nostr.getPublicKey()
      if (pk) event.pubkey = pk
    } catch (_) {}

    // 3) Signieren
    const signed = await window.nostr.signEvent(event)

    // 4) Publish an Server
    const pub = await fetch('/api/v1/nostr/publish', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ post_id: postId, provider_account_id: providerAccountId, event: signed })
    })
    if (!pub.ok) {
      return alert('Fehler bei publish: ' + (await pub.text()))
    }
    alert('Nostr veröffentlicht')
    window.location.reload()
  } catch (e) {
    alert('Signieren/Publish fehlgeschlagen: ' + (e?.message || e))
  }
}

window.NostrConnect = { connect, signAndPublish }


