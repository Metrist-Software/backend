// Changes to this file must be manually deployed. See `wordpress/README.md` for details
const startPollEv = new Event('start-poll');

function loadScript(fileUrl, async = true, type = "text/javascript") {
  return new Promise((resolve, reject) => {
    try {
      const scriptEle = document.createElement("script");
      scriptEle.type = type;
      scriptEle.async = async;
      scriptEle.src = fileUrl;

      scriptEle.addEventListener("load", (_ev) => {
        resolve({ status: true });
      });

      scriptEle.addEventListener("error", (_ev) => {
        reject({
          status: false,
          message: `Failed to load the script ＄{fileUrl}`
        });
      });

      document.body.appendChild(scriptEle);
    } catch (error) {
      reject(error);
    }
  });
};

function render({ entryEl: entryEl, wsEndpoint: wsEndpoint, prefix: prefix, pollAutomatically: pollAutomatically }) {
  let socket = new Phoenix.Socket(wsEndpoint);
  socket.connect();

  let channel = socket.channel("public_realtime_data:landing_page", {})

  entryEl.innerHTML = `
<table id="${prefix}-monitor-telemetry-table">
  <thead>
    <tr>
      <th class="${prefix}-telemetry-time-header">Time</th>
      <th class="${prefix}-telemetry-monitor-header">Monitor</th>
      <th class="${prefix}-telemetry-region-header">Region</th>
      <th class="${prefix}-telemetry-speed-header">Speed</th>
      <th class="${prefix}-telemetry-check-header">Check</th>
    </tr>
  </thead>
  <tbody class="${prefix}-telemetry-table-body">
    <tr id="${prefix}-telemetry-table-placeholder">
      <td colspan="5">Waiting for telemetry...</td>
    </tr>
  </tbody>
</table>
<template id="${prefix}-telemetry-template">
  <tr>
    <td class="${prefix}-telemetry-time">
    </td>
    <td class="${prefix}-telemetry-monitor">
      <div class="${prefix}-telemetry-monitor-wrapper">
        <img class="${prefix}-telemetry-monitor-img">
        <span class="${prefix}-telemetry-monitor-content"></span>
      </div>
    </td>
    <td class="${prefix}-telemetry-region">
    </td>
    <td class="${prefix}-telemetry-speed">
    </td>
    <td class="${prefix}-telemetry-check">
    </td>
  </tr>
</template>
`;

  const template = document.getElementById(`${prefix}-telemetry-template`);

  entryEl.addEventListener('start-poll', () => {
    channel.join()
      .receive("ok", resp => { console.log("Joined successfully", resp) })
      .receive("error", resp => { console.log("Unable to join", resp) })
  })

  if (pollAutomatically) {
    entryEl.dispatchEvent(startPollEv)
  }

  const LOCK_OFFSET = 100; // how many pixels close to bottom consider scroll to be locked

  function handleScroll() {
    const scrollFromBottom =
      entryEl.scrollHeight -
      entryEl.scrollTop -
      entryEl.clientHeight; // how many pixels user scrolled up from button of the table container.

    if (scrollFromBottom < LOCK_OFFSET) { // set new isLocked. lock, if user is close to the bottom, and unlock, if user is far from the bottom.
      entryEl.scrollTop = entryEl.scrollHeight;
    }
  }

  entryEl.addEventListener('scroll', handleScroll);

  channel.on("new-telemetry", payload => {
    const item = template.content.cloneNode(true)
    item.querySelector(`.${prefix}-telemetry-time`).innerText = timestampToUTCText(payload.timestamp)
    item.querySelector(`.${prefix}-telemetry-monitor-content`).innerText = payload.monitor
    item.querySelector(`.${prefix}-telemetry-monitor-img`).src = `https://assets.metrist.io/monitor-logos/${payload.monitor}.png`
    item.querySelector(`.${prefix}-telemetry-region`).innerText = payload.instance
    item.querySelector(`.${prefix}-telemetry-speed`).innerText = millisToHumanReadbleText(payload.value);
    item.querySelector(`.${prefix}-telemetry-check`).innerText = payload.check

    const tbody = document.querySelector(`.${prefix}-telemetry-table-body`);
    const placeholder = document.getElementById(`${prefix}-telemetry-table-placeholder`);

    // hide the place holder when the first telemetry shows up
    if (tbody.childElementCount == 1) {
      placeholder.style.visibility = "hidden"
    }

    placeholder.before(item)
    handleScroll();
  })

  function timestampToUTCText(timestamp) {
    const date = new Date(timestamp)
    // British English uses day-month-year order and 24-hour time without AM/PM
    return date.toLocaleString("en-GB", { timeZone: "UTC", timeZoneName: "short" })
  }

  function millisToHumanReadbleText(millis) {
    if (millis > 5000) {
      return `${(millis / 1000).toFixed(0)} s`;
    }
    return `${millis.toFixed(0)} ms`;
  }
}

/**
 * @param {Object} options
 * @param {string?} options.entryElementId - ID given to the entry point element. Defaults to `metrist-realtime-data`
 * @param {string} options.endpoint - websocket endpoint to use
 * @param {string?} options.classPrefix - class prefix that will be used by the dynamically rendered elements. Defaults to `metrist`
 * @param {boolean?} options.pollAutomatically - polls for the realtime data if set to true. Defaults to `true`
 * @param {boolean?} options.loadRemotePhoenixJS - adds a script element that loads phoenix-js from unpkg.com if set to true. Defaults to `true`
 */
async function pollForTelemetry(options) {
  const entryElementId = options?.entryElementId ?? `metrist-realtime-data`
  const entryEl = document.getElementById(entryElementId);
  const prefix = options?.classPrefix ?? entryEl.dataset.classPrefix ?? "metrist"
  const wsEndpoint = options?.endpoint ?? entryEl.dataset.endpoint
  const pollAutomatically = options?.pollAutomatically ?? entryEl.dataset.pollAutomatically ?? true
  const loadRemotePhoenixJS = options?.loadRemotePhoenixJS ?? entryEl.dataset.loadRemotePhoenixJS ?? true

  if (!wsEndpoint) {
    throw Error("Missing endpoint")
  }

  if (loadRemotePhoenixJS) {
    await loadScript("https://unpkg.com/phoenix@1.7.0-rc.2/priv/static/phoenix.js")
  }

  render({ entryEl, prefix, wsEndpoint, pollAutomatically })
}

