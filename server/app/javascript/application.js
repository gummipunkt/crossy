// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import "./nostr"
import "./nostr_connect"

// Composer: Select/Deselect all providers
document.addEventListener('turbo:load', () => {
  const selAll = document.getElementById('select-all-providers')
  const deselAll = document.getElementById('deselect-all-providers')
  const boxes = document.querySelectorAll('input.provider-checkbox')
  if(selAll){ selAll.addEventListener('click', () => { boxes.forEach(b => b.checked = true) }) }
  if(deselAll){ deselAll.addEventListener('click', () => { boxes.forEach(b => b.checked = false) }) }
})
