import { Controller } from "@hotwired/stimulus"

// Periodically reloads a turbo-frame on a fixed interval. Pauses when the tab is
// hidden, resumes on visibility change. Listens for manual visibility events to
// avoid wasted requests while the user is on another tab.
//
// Usage:
//   <div data-controller="poll"
//        data-poll-interval-value="30000"
//        data-poll-target-id="notifications-feed">
//     <turbo-frame id="notifications-feed" src="/notifications">…</turbo-frame>
//   </div>
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 30000 },
    targetId: String
  }

  connect() {
    this.start()
    this.boundVisibility = this.handleVisibility.bind(this)
    document.addEventListener("visibilitychange", this.boundVisibility)
  }

  disconnect() {
    this.stop()
    document.removeEventListener("visibilitychange", this.boundVisibility)
  }

  start() {
    if (this.timer) return
    this.timer = window.setInterval(() => this.tick(), this.intervalValue)
  }

  stop() {
    if (!this.timer) return
    window.clearInterval(this.timer)
    this.timer = null
  }

  handleVisibility() {
    if (document.hidden) {
      this.stop()
    } else {
      this.tick()
      this.start()
    }
  }

  tick() {
    const id = this.targetIdValue
    if (!id) return
    const frame = document.getElementById(id)
    if (!frame || typeof frame.reload !== "function") return
    frame.reload()
  }
}
