Next, let's set up notifications. We will send notifications when a dependency's status changes.

To send notifications to a channel, create a subscription by running this command in Slack: `/metrist subscriptions <channel-name>`

![Slack subscriptions example](/images/slack-install-subscriptions.svg)

<span class="text-sm text-gray-700 dark:text-white">Replace #&lt;channel-name&gt; with your preferred Slack channel.</span>

Click the “Select your monitors” button to manage which channels will receive status change notifications.

![Slack choose monitors example](/images/slack-install-choose-monitors.svg)

Run `/metrist help` to view additional Metrist Slack commands.
