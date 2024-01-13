defmodule BackendWeb.MonitorAlertingLive do
  use BackendWeb, :live_view

  require Logger

  @input_placeholders %{
    "slack-destination" => "#slack_channel"
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> clear_form()
      |> assign(
        initial_monitor: nil,
        monitor: "",
        page_title: "Loading...",
        subscription_type: "email",
        subscription_destination: socket.assigns.current_user.email,
        show_form?: false
      )
    {:ok, socket}
  end

  @impl true
  def handle_params(params = %{"monitor" => _monitor}, _url, socket) do
    if connected?(socket) do
      monitor = Backend.Projections.get_monitor(socket.assigns.current_user.account_id, params["monitor"], [:subscriptions])

      {:noreply, socket
        |> assign(
          initial_monitor: params["monitor"],
          monitor: params["monitor"],
          page_title: "#{monitor.name} Alerting",
          subscriptions: monitor.subscriptions |> sort_subscriptions()
        )
        |> assign_common_values()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(%{}, _url, socket) do
    subscriptions = Backend.Projections.get_subscriptions_for_account(socket.assigns.current_user.account_id, [:monitor])
    {:noreply, socket
    |> assign(
      initial_monitor: nil,
      monitor: nil,
      page_title: "Alerting",
      subscriptions: subscriptions |> sort_subscriptions()
    )
    |> assign_common_values()}
  end

  @impl true
  def handle_event("change", %{"ref" => "type", "value" => type}, socket) do
    {:noreply, socket
      |> clear_form()
      |> assign_form_defaults(type)
      |> assign(subscription_type: type)}
  end

  def handle_event("change", %{"ref" => "monitor", "value" => monitor}, socket) do
    {:noreply, assign(socket, monitor: monitor, errors: %{})}
  end

  def handle_event("change", %{"_target" => ["config-auth"], "config-auth" => auth}, socket) do
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, :auth, auth))}
  end

  def handle_event("change", %{"ref" => "workspace", "value" => workspace}, socket) do
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, :workspace, workspace))}
  end

  def handle_event("change", %{"ref" => "team", "value" => team}, socket) do
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, :team, team))}
  end

  def handle_event("change", %{"ref" => "degraded_severity", "value" => severity}, socket) do
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, :degraded_severity, severity))}
  end

  def handle_event("change", %{"ref" => "down_severity", "value" => severity}, socket) do
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, :down_severity, severity))}
  end

  def handle_event("change", %{"_target" => ["config-auto-resolve"], "config-auto-resolve" => value}, socket) do
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, :auto_resolve, value == "on"))}
  end

  def handle_event("toggle-form", _params, socket) do
    {:noreply, toggle_form(socket)}
  end

  def handle_event("change", %{"ref" => "datadog_site", "value" => site}, socket) do
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, :datadog_site, site))}
  end

  def handle_event("change", %{"destination" => destination}, socket)
    when socket.assigns.subscription_type == "slack" do
    %{errors: errors} = socket.assigns
    destination = String.trim(destination)
    socket = assign(socket, subscription_destination: destination)
    new_assigns = case destination do
      "#" <> _channel -> [errors: Map.delete(errors, :destination)]
      "" -> [errors: Map.put(errors, :destination, "Channel is required")]
      _ -> [errors: Map.put(errors, :destination, "Channel must start with #")]
    end
    {:noreply, assign(socket, new_assigns)}
  end

  def handle_event("change", %{"destination" => destination}, socket) do
    {:noreply, assign(socket, subscription_destination: destination)}
  end

  def handle_event("change", _, socket) do
    {:noreply, socket}
  end

  def handle_event("submit", value, socket) do
    socket = value
      |> maybe_set_email_destination(socket)
      |> validate(socket)
      |> do_submit(socket)
    {:noreply, socket}
  end

  def handle_event("delete", %{"subscription" => subscription_id}, socket) do
    cmd = %Domain.Account.Commands.DeleteSubscriptions{
      id: socket.assigns.current_user.account_id,
      subscription_ids: [subscription_id]
    }

    case BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd) do
      {:error, _} -> {:noreply, socket}
      _ -> {:noreply, assign(socket, subscriptions: Enum.reject(socket.assigns.subscriptions, &(&1.id == subscription_id)))}
    end
  end

  defp assign_common_values(socket) do
    slack_workspaces = Backend.Projections.get_slack_workspaces(socket.assigns.current_user.account_id)
    ms_tenants = Backend.Projections.get_microsoft_tenants(socket.assigns.current_user.account_id)
    subscription_types = [
        %{label: "Pagerduty", id: "pagerduty", icon: {:external, monitor_image_url("pagerduty")}},
        %{label: "Webhook",   id: "webhook",   icon: {:svg, "icon-webhook"}},
        %{label: "Datadog",   id: "datadog",   icon: {:external, monitor_image_url("datadog")}},
        %{label: "Email",     id: "email",     icon: {:svg, "icon-email"}}
      ]

    # Nuke web UI chat subscription setup until we have a full experience for this
    # subscription_types = if length(slack_workspaces) > 0 do
    #    [%{label: "Slack", id: "slack", icon: {:external, monitor_image_url("slack")}} | subscription_types]
    # else
    #    subscription_types
    # end
    # subscription_types = if length(ms_tenants) > 0 do
    #    [%{label: "Microsoft Teams", id: "teams", icon: {:svg, "icon-teams"}} | subscription_types]
    # else
    #    subscription_types
    # end

    subscription_types = Enum.reverse(subscription_types)
    monitors = Backend.Projections.list_monitors(socket.assigns.current_user.account_id)

    socket
    |> assign(
      subscription_types: subscription_types,
      slack_workspaces: slack_workspaces,
      ms_tenants: ms_tenants,
      monitors: monitors
    )
  end

  defp validate(%{"type" => ""}, _socket), do: {:invalid, :type}
  defp validate(%{"destination" => ""}, _socket), do: {:invalid, :destination}
  defp validate(%{"monitor" => ""}, _socket), do: {:invalid, :monitor}
  defp validate(value=%{"type" => "webhook", "destination" => destination}, _socket) do
    if String.contains?(destination, "canarymonitor.com") || String.contains?(destination, "metrist.io") do
      {:invalid, :destination}
    else
      {:valid, value}
    end
  end
  defp validate(value=%{"type" => "email", "destination" => destination}, socket) do
    if Enum.any?(socket.assigns.subscriptions,
      fn sub ->
        sub.monitor_id == value["monitor"]
          and sub.delivery_method == "email"
          and sub.identity == destination
      end) do
      {:invalid, :email_subscription_already_exist}
    else
      {:valid, value}
    end
  end
  defp validate(value, _socket), do: {:valid, value}

  defp do_submit({:invalid, :destination}, socket), do: assign(socket, errors: Map.put(socket.assigns.errors, :destination, "Invalid url"))
  defp do_submit({:invalid, :email_subscription_already_exist}, socket), do: assign(socket, errors: Map.put(socket.assigns.errors, :destination, "A subscription for this email already exists"))
  defp do_submit({:invalid, _reason}, socket), do: socket
  defp do_submit({:valid, %{"type" => type, "destination" => destination, "monitor" => monitor}}, socket) do
    subscription = %Domain.Account.Commands.Subscription{
      subscription_id: Domain.Id.new(),
      monitor_id: monitor,
      delivery_method: type,
      identity: destination,
      display_name: destination,
      regions: nil,
      extra_config: config_for_subscription(socket.assigns.config, type)
    }

    cmd = %Domain.Account.Commands.AddSubscriptions{
      id: socket.assigns.current_user.account_id,
      subscriptions: [subscription]
    }

    inserted_subscription = subscription
      |> Map.put(:id, subscription.subscription_id)
      |> Map.put(:inserted_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))

    case BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd) do
      {:error, _} -> socket
      _ ->
        socket
          |> clear_form
          |> toggle_form
          |> assign_form_defaults(type)
          |> assign(subscriptions: [inserted_subscription | socket.assigns.subscriptions] |> sort_subscriptions())
          |> put_flash(:info, "Successfuly added subscription")
    end
  end

  defp clear_form(socket) do
    assign(socket,
      subscription_destination: "",
      config: %{},
      errors: %{})
  end

  defp assign_form_defaults(socket, "pagerduty") do
    assign(socket,
      config: %{
        degraded_severity: "warning",
        down_severity: "error"
      })
  end

  defp assign_form_defaults(socket, "datadog") do
    assign(socket,
      config: %{
        datadog_site: "us",
        degraded_severity: "Warn",
        down_severity: "Critical"
      })
  end

  defp assign_form_defaults(socket, "email") do
    assign(socket, subscription_destination: socket.assigns.current_user.email)
  end

  defp assign_form_defaults(socket, _type), do: socket

  def maybe_set_email_destination(value=%{"type" => "email"}, socket), do: Map.put(value, "destination", socket.assigns.current_user.email)
  def maybe_set_email_destination(value, _socket), do: value

  defp input_type_for_subscription("webhook"), do: "url"
  defp input_type_for_subscription("email"), do: "email"
  defp input_type_for_subscription(_), do: "text"

  defp config_for_subscription(%{auth: nil},  "webhook"), do: %{}
  defp config_for_subscription(%{auth: auth}, "webhook"), do: %{ "AdditionalHeaders" => %{ "Authorization" => auth } }
  defp config_for_subscription(%{team: team}, "teams"), do: %{ "TeamId" => team }
  defp config_for_subscription(%{workspace: workspace}, "slack"), do: %{ "WorkspaceId" => workspace }
  defp config_for_subscription(config, "pagerduty"), do: %{
    "AutoResolve" => Map.get(config, :auto_resolve, false),
    "DegradedSeverity" => Map.get(config, :degraded_severity),
    "DownSeverity" => Map.get(config, :down_severity),
  }
  defp config_for_subscription(config, "datadog"), do: %{
    "DegradedSeverity" => Map.get(config, :degraded_severity),
    "DownSeverity" => Map.get(config, :down_severity),
    "DatadogSite" => Map.get(config, :datadog_site)
  }
  defp config_for_subscription(_, _), do: %{}

  defp slack_workspaces_for_select(slack_workspaces) do
     Enum.map(slack_workspaces, & %{
       label: &1.team_name || &1.id,
       id: &1.id
       })
       |> Enum.sort_by(& &1.label)
  end
  defp ms_tenants_for_select(ms_tenants) do
     Enum.map(ms_tenants, & %{
       label: &1.team_name || &1.id,
       id: &1.id
       })
       |> Enum.sort_by(& &1.label)
  end
  defp monitors_for_select(monitors) do
    Enum.map(monitors, & %{
      label: &1.name,
      id: &1.logical_name,
      icon: {:external, monitor_image_url(&1.logical_name)}
      })
       |> Enum.sort_by(& &1.label)
  end

  defp sort_subscriptions(subscriptions) do
    subscriptions
    |> Enum.sort_by(&({&1.monitor_id, &1.display_name}))
  end


  @integration_type_display_text %{
    "email" => "E-mail",
    "datadog" => "Datadog",
    "webhook" => "Webhook",
    "pagerduty" => "Pagerduty",
    "slack" => "Slack",
    "teams" => "Teams"
  }

  defp integration_type(type) do
    assigns = %{label: @integration_type_display_text[type], type: type}
    case type do
      type when type in ["email", "webhook", "teams"] ->
        ~H"""
        <%= BackendWeb.Helpers.Svg.svg_image("icon-#{@type}", class: "inline h-8 w-8 mr-2") %><%= @label %>
        """
      _ ->
        ~H"""
        <img class="inline h-5 w-5 mr-2" src={monitor_image_url(@type)}/><%= @label %>
        """
    end
  end

  defp destination_cell(subscription, opts) do
    mobile_display = Keyword.get(opts, :mobile, false)

    assigns = %{display_name: Backend.Projections.Dbpa.Subscription.safe_display_name(subscription), mobile_display: mobile_display}
    case subscription.delivery_method do
      "slack" ->
        slack_workspaces = Keyword.fetch!(opts, :slack_workspaces)

        workspace_name =
          case Enum.find(slack_workspaces, & &1.id == subscription.extra_config["WorkspaceId"]) do
            %{team_name: name} -> name
            _ -> "Unknown workspace"
          end

        assigns = Map.put(assigns, :workspace_name, workspace_name)

        if not mobile_display do
          ~H"""
          <%= @workspace_name %> / <%= destination_pill @display_name, @mobile_display %>
          """
        else
          ~H"""
          <%= destination_pill @display_name, @mobile_display %>
          """
        end
      "teams" ->
        ms_teams = Keyword.fetch!(opts, :ms_teams)

        team_name = case Enum.find(ms_teams, & &1.id == subscription.extra_config["TeamId"]) do
          %{team_name: name} -> name
          _ -> "Unknown workspace"
        end

        assigns = Map.put(assigns, :team_name, team_name)
        if not mobile_display do
          ~H"""
          <%= @team_name %> / <%= destination_pill @display_name, @mobile_display %>
          """
        else
          ~H"""
          <%= destination_pill @display_name, @mobile_display %>
          """
        end
      "datadog" ->
        ~H"""
        API Key: <%= destination_pill @display_name, @mobile_display %>
        """
      "webhook" ->
        ~H"""
        <%= destination_pill @display_name, @mobile_display %>
        """
      "email" ->
        ~H"""
        <%= destination_pill @display_name, @mobile_display %>
        """
      "pagerduty" ->
        ~H"""
        Routing Key: <%= destination_pill @display_name, @mobile_display %>
        """
    end
  end
  defp destination_pill(label, true) do
    assigns = %{label: label}
    ~H"""
    <span><%= @label %></span>
    """
  end
  defp destination_pill(label, false) do
    assigns = %{label: label}
    ~H"""
    <span class="pill px-2 py-1 ml-1 !font-lato dark:text-black"><%= @label %></span>
    """
  end

  defp get_placeholder(key, default \\ ""), do: Map.get(@input_placeholders, key, default)

  defp toggle_form(socket) do
    update(socket, :show_form?, fn show_form? -> not show_form? end)
  end
end
