import { DDClient, EventType, init } from '@datadog/ui-extensions-sdk'
import { Hook, makeHook } from 'phoenix_typed_hook'

const authenticatedInit = () => {
  return init({
    authProvider: {
      url: '/dd-metrist/auth-app',
      resolution: 'close',
      authStateCallback: async () => {
        const res = await fetch('/dd-metrist/auth-check', { credentials: 'include' })

        return {
          isAuthenticated: res.status === 200
        }
      }
    }
  })
}

const openSyntheticsWizard = (client: DDClient) => {
  client.sidePanel.open({
    source: 'dd-metrist/synthetics-wizard',
    key: SyntheticsWizard.SIDE_PANEL_KEY,
    title: 'Add Monitors'
  })
}

class DDHook extends Hook {
  client: DDClient
}

class Controller extends DDHook {
  mounted(): void {
    console.log("controller mounted!")
    this.client = authenticatedInit()

    this.client.events.on(EventType.DASHBOARD_COG_MENU_CLICK, context => {
      if (context.menuItem.key === 'add-monitors') {
        this.client.sidePanel.open({
          source: 'dd-metrist/synthetics-wizard',
          key: SyntheticsWizard.SIDE_PANEL_KEY,
          title: 'Add Monitors'
        })
      }
    })
  }
}

class SyntheticsWizard extends DDHook {
  static SIDE_PANEL_KEY = 'synthetics-side-panel'

  async mounted(): Promise<void> {
    console.log("Synthetics wizard mounted")
    this.client = authenticatedInit()
    // Bind "this" after this.client is set as the event handler has to use this.client.location.goTo
    this.linkToMonitors = this.linkToMonitors.bind(this)

    this.checkForMonitorsNavigationLink()
    try {
      await this.client.getContext()
      const res = await this.client.api.get('/api/v1/synthetics/tests')
      const metristTests = res.tests.filter(test => test.tags.includes("metrist-created"))
      this.pushEvent("datadog-initialized", { tests: metristTests})
    } catch (error) {
      //we can't get the context or existing tests so don't continue
      console.log('no context')
    }

    this.handleEvent('create_tests', async (submission_configs) => {
      console.log('Creating tests')
      try {
        await Promise.all(submission_configs.new_configs.map(config => {
          return this.client.api.post('/api/v1/synthetics/tests/api', config)
        }))

        await Promise.all(submission_configs.existing_configs.map(config => {
          const public_id = config.public_id
          delete config.public_id
          return this.client.api.put(`/api/v1/synthetics/tests/api/${public_id}`, config)
        }))

        this.client.notification.send({
          label: 'Synthetics created successfully',
          level: 'success'
        })
        this.pushEvent("creation-complete", {})
      } catch (error) {
        console.log(error)
        this.client.notification.send({
          label: `Sorry, at least one of your synthetics could not be created because of: ${JSON.stringify(error)}`,
          level: 'danger'
        })
      }
    })

    this.handleEvent('close_side_panel', async () => this.client.sidePanel.close(SyntheticsWizard.SIDE_PANEL_KEY))
  }
  updated(): void {
    console.log('Synthetics wizard updated')
    this.checkForMonitorsNavigationLink()
  }
  checkForMonitorsNavigationLink(): void {
    const el = document.getElementById('ddMonitorsButton');
    if (el && !el.getAttribute('data-click-bound')) {
      el.addEventListener('click', this.linkToMonitors)
      el.setAttribute('data-click-bound', 'true')
    }
  }
  linkToMonitors(ev : Event): void {
    ev.preventDefault()
    this.client.location.goTo('/synthetics/tests?query=tag%3A(metrist-created)');
  }
}

class HealthWidget extends DDHook {
  async mounted(): Promise<void> {
    console.log("Health widget mounted")
    this.client = authenticatedInit()
    // Bind "this" after this.client is set as the event handler has to use this.client.location.goTo
    // Can reuse one reference instead of 1 per card
    this.linkToSynthetics = this.linkToSynthetics.bind(this)

    this.handleEvent('refresh_data', () => this.loadData())
    this.handleEvent('open_synthetics_wizard', () => openSyntheticsWizard(this.client))

    this.client.events.on(EventType.SIDE_PANEL_CLOSE, (context) => {
      if (context.key === SyntheticsWizard.SIDE_PANEL_KEY) {
        return this.loadData()
      }
    })

    await this.loadData()
    this.bindMonitorCardLinks()
  }
  updated(): void {
    console.log('HealthWidget updated')
    this.bindMonitorCardLinks()
  }
  bindMonitorCardLinks(): void {
    const els = document.getElementsByClassName('monitor-card-link');

    const self = this;
    Array.from(els).forEach(function(el) {
      if (!el.getAttribute('data-click-bound')) {
        el.addEventListener('click', self.linkToSynthetics)
        el.setAttribute('data-click-bound', 'true')
      }
    });
  }
  linkToSynthetics(ev : Event): void {
    ev.preventDefault()
    const link = `/synthetics/details/${(<HTMLElement>ev.currentTarget).getAttribute('data-id')}`
    this.client.location.goTo(link)
  }
  async loadData(): Promise<void> {
    console.log('Loading data')

    const res = await this.client.api.get('/api/v1/synthetics/tests')
    // Only retrieve data for metrist-created tagged tests
    const metristTests = res.tests.filter(test => test.tags.includes("metrist-created"))
    const testResults = await Promise.all(metristTests.map(async test => {
      const results = await this.client.api.get(`/api/v1/synthetics/tests/${test.public_id}/results`)
      return {
        name: test.name,
        locations: test.locations,
        tags: test.tags,
        public_id: test.public_id,
        ...results
      }
    }))

    this.pushEvent("tests-loaded", testResults)
  }
}

export const DatadogController = makeHook(Controller)
export const DatadogSyntheticsWizard = makeHook(SyntheticsWizard)
export const DatadogHealthWidget = makeHook(HealthWidget)

// A little hacky, but this needs to happen as soon as the page loads and Hook mounted is too late. All is bundled into one app.js so check the path. Only run when path starts with /dd-
if (window.location.pathname.startsWith('/dd-')) {
  authenticatedInit()
}
