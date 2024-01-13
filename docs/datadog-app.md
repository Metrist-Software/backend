# The Metrist Datadog App

The backend includes router endpoints that are used by our Metrist Datadog app.

The way that Datadog apps work is described in their app [programming model](https://github.com/DataDog/apps/blob/master/docs/en/programming-model.md).
TLDR; Datadog hits urls exposed by us in iFrames. One of them is the "controller" URL in our case `/dd-metrist/` which captures events
and can use their Javascript SDK to perform actions. Other iFrames such as widgets have their own URL endpoints. We can also use their SDK to make [FramePost](https://github.com/DataDog/apps/tree/master/packages/framepost) API calls which use inter frame communication after the user accepts the OAuth challenge.

The URLs hit for the different iFrames are all under the `/dd-metrist` scope.

All Datadog setup and configuration is completed within our Datadog Partner account which can be accessed at https://app.datadoghq.com by logging in with your
Metrist Google account. If you have multiple Datadog accounts associated with your `@metrist.io` account, please choose `DPN | Metrist, Inc.`

## Permissions

The Datadog app currently request all `Synthetic Monitoring` permissions from its public OAuth client when running within Datadog

## Data Storage

At this time, all data is retrieved/stored from/to Datadog using FramePost requests. This includes any sensitive data
such as the API keys used by the third party providers we setup in our synthetics wizard. Synthetics that the user request
are setup within Datadog itself.

In future tickets, we are likely going to add authentication which would include a confidential OAuth flow so that we can
retrieve synthetic test results when the widget is not running. This will require the users permission. We may then end up storing 
some relevant result data within the Metrist data stores.

## Editing app configuration

Application configuration such as title/description, what widgets are enabled at which URL endpoints, as well as OAUTH scopes can
be done from the [Apps](https://app.datadoghq.com/apps) section within our Datadog Partner Account

## Testing against local

Testing the solution while running the backend locally is simple.

1. Run your local backend
2. Go to https://app.datadoghq.com/dashboard/h5h-f6t-nxw/metrist-dev-test-dashboard (login with your Metrist Google account)
3. You will then see hits to your local `/dd-metrist` endpoints when the dashboard loads our content

The dashboard runs the the [Metrist-Dev](https://app.datadoghq.com/apps/37a081b2-bd0b-11ed-aae6-da7ad0900002/edit) Datadog app
which points to https://localhost:4443 for its iFrame endpoints

Note: The local [DEV] Add Monitors menu item is in the cog menu in the top right corner of the dashboard view. That will open the wizard
side panel.

## Testing against production

The following dashboard points to production (app.metrist.io)

https://app.datadoghq.com/dashboard/qst-b7r-ydw/metrist (login with your Metrist Google account)

This dashboard runs the [Metrist](https://app.datadoghq.com/apps/495a82cc-b2de-11ed-b8c2-da7ad0900002/edit) Datadog app which points to
production (app.metrist.io) for its iFrame endpoints

Note: The local Add Monitors menu item is in the cog menu in the top right corner of the dashboard view. That will open the wizard
side panel.
