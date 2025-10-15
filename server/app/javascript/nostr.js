function downloadJson(filename, dataObj) {
  const json = JSON.stringify(dataObj, null, 2)
  const blob = new Blob([json], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.rel = 'noopener'
  a.style.display = 'none'
  document.body.appendChild(a)
  a.click()
  setTimeout(() => {
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }, 0)
  // Fallback: in neuem Tab öffnen
  setTimeout(() => {
    if (!document.hidden) {
      try { window.open(url, '_blank', 'noopener') } catch (_) {}
    }
  }, 200)
  // Zusätzlich ins Clipboard kopieren (silent fallback)
  if (navigator?.clipboard?.writeText) {
    navigator.clipboard.writeText(json).catch(() => {})
  }
}

async function prepare(postId, providerAccountId) {
  try {
    const resp = await fetch('/api/v1/nostr/prepare_event', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ post_id: postId, provider_account_id: providerAccountId })
    });
    if (!resp.ok) {
      const txt = await resp.text();
      alert('Fehler beim Vorbereiten: ' + txt);
      return;
    }
    const json = await resp.json();
    if (!json.event) {
      alert('Antwort ohne Event erhalten')
      return;
    }
    downloadJson(`nostr_event_post_${postId}.json`, json.event);
    // Sichtbar machen für Entwickler-Tools
    window.lastNostrEvent = json.event
  } catch (e) {
    alert('Netzwerkfehler: ' + (e?.message || e));
  }
}

window.NostrPrepare = { prepare };


