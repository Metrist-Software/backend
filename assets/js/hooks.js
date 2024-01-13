import Chart, { applyThemeToAnnotations } from "./chart";
import Alpine from "alpinejs";

let Hooks = {};

Hooks.Chart = {
  mounted() {
    const accountName = this.el.dataset.chartAccountName || 'Account';
    const accountChecks = JSON.parse(this.el.dataset.chartDataAccountCheck || '[]');
    const baselineChecks = JSON.parse(this.el.dataset.chartDataBaselineCheck || '[]');
    const annotationsX = applyThemeToAnnotations(JSON.parse(this.el.dataset.annotationsX || '[]'));

    const series = [
      {
        name: accountName,
        data: accountChecks
      },
      {
        name: 'Metrist',
        data: baselineChecks
      },
    ]

    this.chart = new Chart(this.el, series, { x: annotationsX });

    // for liveliness
    // this.handleEvent("new-point", ({ label, value  }) => {
    //   this.chart.addPoint(label, value)
    // })
  },

  updated() {
    const accountName = this.el.dataset.chartAccountName || 'Account';
    const accountChecks = JSON.parse(this.el.dataset.chartDataAccountCheck || '[]');
    const baselineChecks = JSON.parse(this.el.dataset.chartDataBaselineCheck || '[]');
    const annotationsX = JSON.parse(this.el.dataset.annotationsX || '[]');

    const series = [
      {
        name: accountName,
        data: accountChecks
      },
      {
        name: 'Metrist',
        data: baselineChecks
      }
    ]

    this.chart.chart.updateSeries(series, false)
    this.chart.updateAnnotations({ x: annotationsX })
  }
};

import topbar from "topbar";

Hooks.ProgressBarOnChange = {
  mounted() {
    this.progressTimeout = null;
    this.observer = new MutationObserver((mutationsList, observer) => {
      clearTimeout(this.progressTimeout);
      if (this.el.getAttribute("class").includes("phx-change-loading")) {
        this.progressTimeout = setTimeout(topbar.show, 100);
      } else {
        topbar.hide();
      }
    });
    this.observer.observe(this.el, {
      attributes: true,
    });
  },
};

Hooks.ToggleLightDarkMode = {
  key: 'metrist.theme',
  mounted() {
    const theme = localStorage.getItem(this.key)
    if (!theme) {
      localStorage.setItem(this.key, 'light')
      document.dispatchEvent(new CustomEvent('toggle-dark-mode', { detail: 'light' }))
    } else if (theme == 'dark') {
      this.pushEventTo(`[id="${this.el.id}"]`, 'toggle-light-dark-mode')
    }
    document.querySelector('html').className = localStorage.getItem(this.key)
  },
}

window.addEventListener('phx:toggle-light-dark-mode', e => {
  const newMode = localStorage.getItem('metrist.theme') == 'light' ? 'dark' : 'light'
  document.querySelector('html').className = newMode
  localStorage.setItem('metrist.theme', newMode)
  document.dispatchEvent(new CustomEvent('toggle-dark-mode', { detail: newMode }))
})

// This can be used to initialize the datastack on elements with AlpineJS data (x-data)
// that are injected at runtime (e.g. see realtime pages)
Hooks.AlpineInit = {
  mounted() {
    if (!this.el._x_dataStack) {
      Alpine.initTree(this.el)
    }
  }
}

Hooks.ClickStopPropagation = {
  mounted() {
    this.el.addEventListener('click', e => {
      e.stopImmediatePropagation()

      const event = this.el.getAttribute('phx-value-event')
      if (!event) return

      const target = this.el.getAttribute('phx-value-target')
      if (target) {
        this.pushEventTo(target, event)
      } else {
        this.pushEvent(event)
      }
    })
  }
}

// For the feedback form, cleanest way to get the user agent
Hooks.SetUa = {
  mounted() {
    this.el.value = navigator.userAgent
  }
}

import resolveConfig from 'tailwindcss/resolveConfig'
import tailwindConfig from '../tailwind.config'
const fullConfig = resolveConfig(tailwindConfig)
const breakpoints = Object.entries(fullConfig.theme.screens)
  .filter(([key, value]) => typeof value === 'string' && value.endsWith('px'))
  .map(([key, value]) => [key, parseInt(value.replace('px', ''))])
  .sort(([key1, value1], [key2, value2]) => value2 - value1)

Hooks.ScreenBreakpointListener = {
  mounted() {
    this.width = window.innerWidth

    const [breakpoint] = breakpoints.find(([key, value]) => value <= window.innerWidth) || ['min', 0]
    this.breakpoint = breakpoint
    this.pushEventTo(`#${this.el.id}`, 'breakpoint-change', breakpoint)

    window.addEventListener('resize', (e) => {
      const [newBreakpoint] = breakpoints.find(([key, value]) => value <= window.innerWidth) || ['min', 0]
      if (this.breakpoint !== newBreakpoint) {
        this.breakpoint = newBreakpoint
        this.pushEventTo(`#${this.el.id}`, 'breakpoint-change', newBreakpoint)
      }
    })
  }
}

Hooks.MonitorTimeline = {
  active_element: null,
  escape_trap: null,
  mounted() {
    this.escape_trap = this.escapeTrap.bind(this)
    this.addTimelineBarClickListener();
    window.addEventListener('resize', e => {
      this.closeMonitorTimelineHover()
    })
  },
  updated() {
    this.addTimelineBarClickListener();
    popupClose = document.getElementById('close_monitor_timeline')
    if (popupClose) {
      popupClose.addEventListener('click', e => {
        this.closeMonitorTimelineHover()
        e.preventDefault()
      })
    }
  },
  destroyed() {
    this.closeMonitorTimelineHover()
  },
  escapeTrap(e) {
    if (e.key == 'Escape') {
      this.closeMonitorTimelineHover()
    }
  },
  openMonitorTimelineHover(timelineDayElement) {
    window.removeEventListener('keydown', this.escape_trap)
    window.addEventListener('keydown', this.escape_trap)
    var hoverContainer = document.getElementById('monitor_timeline_hover')
    if (hoverContainer) {
      const rect = timelineDayElement.getBoundingClientRect()
      hoverContainer.style.left = Math.min(rect.left, document.documentElement.clientWidth - hoverContainer.getBoundingClientRect().width) + 'px'
      hoverContainer.style.top = (rect.top - hoverContainer.getBoundingClientRect().height + window.scrollY) + 'px'
      hoverContainer.classList.remove("invisible")
    }
  },
  closeMonitorTimelineHover() {
    if (this.active_element) {
      this.active_element.classList.remove('border-current')
      this.active_element = null
    }

    var el = document.getElementById('monitor_timeline_hover')
    if (el) {
      el.classList.add("invisible")
    }
    window.removeEventListener('keydown', this.escape_trap)
  },
  addTimelineBarClickListener() {
    document.querySelectorAll('.timeline-day').forEach((timelineBarElement) => {
      // Use onclick instead of addEventListener to overwrite the existing
      // listener instead of adding a new one every time this is called
      timelineBarElement.onclick = e => {
        this.active_element = timelineBarElement
        this.pushEventTo(
          `#${this.el.id}`,
          'day-hover',
          {
            day: e.currentTarget.getAttribute('data-day')
          },
          (reply, ref) => {
            this.openMonitorTimelineHover(timelineBarElement)
            timelineBarElement.classList.add('border-current')
          }
        )
      }
    })
  }
}

Hooks.ClickCopyToClipBoard = {
  mounted() {
    this.el.addEventListener('click', e => {
      const target = document.getElementById(this.el.dataset.target);
      if ("clipboard" in navigator) {
        navigator.clipboard.writeText(target.value)
      } else {
        alert("Sorry, your browser does not support clipboard copy.")
      }
    })
  }
}

Hooks.Highlight = {
  mounted() {
    window.highlightAll(this.el)
  },

  updated() {
    window.highlightAll(this.el)
  },
}

Hooks.CloseWindow = {
  mounted() {
    setTimeout(() => window.close(), 3000);
  }
}

import { InitSetup } from "./stripe";
Hooks.StripeInitSetup = InitSetup

import * as DatadogHooks from "./datadog"

Hooks = {
  ...Hooks,
  ...DatadogHooks
}

export default Hooks;
