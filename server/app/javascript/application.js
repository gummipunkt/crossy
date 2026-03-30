// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import "./nostr"
import "./nostr_connect"

function updateCharCounter (field, countEl, wrapEl, warnAt, strongAt) {
  if (!field || !countEl) return
  const n = field.value.length
  countEl.textContent = String(n)
  if (!wrapEl) return
  wrapEl.classList.remove("crossy-char-count--warn", "crossy-char-count--strong")
  if (strongAt && n >= strongAt) wrapEl.classList.add("crossy-char-count--strong")
  else if (warnAt && n >= warnAt) wrapEl.classList.add("crossy-char-count--warn")
}

function setupComposerCounters () {
  const text = document.getElementById("post_content_text")
  const textCount = document.getElementById("post_content_text_count")
  const textWrap = document.getElementById("post_content_text_count_wrap")
  if (text && textCount && !text.dataset.counterBound) {
    text.dataset.counterBound = "1"
    const warn = parseInt(text.dataset.warnChars || "500", 10)
    const strong = parseInt(text.dataset.strongWarnChars || "4500", 10)
    const onInput = () => updateCharCounter(text, textCount, textWrap, warn, strong)
    text.addEventListener("input", onInput)
    onInput()
  }

  const cw = document.getElementById("post_content_warning")
  const cwCount = document.getElementById("post_content_warning_count")
  const cwWrap = document.getElementById("post_content_warning_count_wrap")
  if (cw && cwCount && !cw.dataset.counterBound) {
    cw.dataset.counterBound = "1"
    const warn = parseInt(cw.dataset.warnChars || "200", 10)
    const onInput = () => updateCharCounter(cw, cwCount, cwWrap, warn, null)
    cw.addEventListener("input", onInput)
    onInput()
  }

  const alts = document.getElementById("post_alts")
  const altsCount = document.getElementById("post_alts_count")
  const altsWrap = document.getElementById("post_alts_count_wrap")
  if (alts && altsCount && !alts.dataset.counterBound) {
    alts.dataset.counterBound = "1"
    const onInput = () => updateCharCounter(alts, altsCount, altsWrap, 800, null)
    alts.addEventListener("input", onInput)
    onInput()
  }
}

function setupDeliveriesPolling () {
  const frame = document.querySelector("[data-deliveries-frame]")
  if (!frame || frame.dataset.pollingBound) return
  frame.dataset.pollingBound = "1"

  const startedAt = Date.now()
  const maxDurationMs = 60000 // stop after ~1 minute
  const intervalMs = 4000

  const timer = setInterval(() => {
    if (!document.body.contains(frame)) {
      clearInterval(timer)
      return
    }
    if (Date.now() - startedAt > maxDurationMs) {
      clearInterval(timer)
      return
    }
    if (typeof frame.reload === "function") {
      frame.reload()
    } else if (frame.src) {
      // Fallback for older Turbo — reset src to trigger reload
      frame.src = frame.src
    }
  }, intervalMs)
}

// Composer: Select/Deselect all providers + Character counter + Deliveries-Polling
document.addEventListener("turbo:load", () => {
  const selAll = document.getElementById("select-all-providers")
  const deselAll = document.getElementById("deselect-all-providers")
  const boxes = document.querySelectorAll("input.provider-checkbox")
  if (selAll && !selAll.dataset.bound) {
    selAll.dataset.bound = "1"
    selAll.addEventListener("click", () => { boxes.forEach(b => { b.checked = true }) })
  }
  if (deselAll && !deselAll.dataset.bound) {
    deselAll.dataset.bound = "1"
    deselAll.addEventListener("click", () => { boxes.forEach(b => { b.checked = false }) })
  }

  setupComposerCounters()
  setupDeliveriesPolling()
})
