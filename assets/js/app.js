import "phoenix_html";
import { Socket } from "phoenix";
import topbar from "topbar";
import { LiveSocket } from "phoenix_live_view";
import Hooks from "./hooks";

import Alpine from "alpinejs";
import Tooltip from "@ryangjchandler/alpine-tooltip"

import hljs from 'highlight.js/lib/core'
import elixir from 'highlight.js/lib/languages/elixir'
hljs.registerLanguage('elixir', elixir)

window.highlightAll = function(where = document) {
  where.querySelectorAll('pre code').forEach((block) => {
    const lang = block.getAttribute("class")
    const { value: value } = hljs.highlight(block.innerText, { language: lang})
    block.innerHTML = value
  })
}

window.highlightAll()

Alpine.plugin(Tooltip)
Alpine.store('preferences', {
  hideMonitoringCta: localStorage.getItem('metrist.hideMonitoringCta') || false,

  update(key, value) {
    this[key] = value
    localStorage.setItem(`metrist.${key}`, value)
  }
})
window.Alpine = Alpine
Alpine.start()

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  dom: {
    // Allows Alpine and LiveView to work with each other
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to);
      }
    }
  }
});

let progressTimeout = null;
topbar.config({
  barColors: { 0: "#ddd" },
  shadowColor: "rgba(0, 0, 0, .3)",
});
window.addEventListener("phx:page-loading-start", () => {
  clearTimeout(progressTimeout);
  progressTimeout = setTimeout(topbar.show, 100);
});
window.addEventListener("phx:page-loading-stop", () => {
  clearTimeout(progressTimeout);
  topbar.hide();
});
window.addEventListener("phx:gtm-signup", (e) => {
  window.dataLayer = window.dataLayer || [];
  window.dataLayer.push({
    'event': 'free_trial',
    'plan': 'free',
    'value': '0',
    'email': e.detail.email
  });
})

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
