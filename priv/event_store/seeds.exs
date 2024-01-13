#
#  Seeds for the event store. Add commands you want here to setup a minimal
#  database for development.
#
#  You can run this manually with `mix run priv/event_store/seeds.exs` but
#  it is also part of `mix event_store.setup` (and some other commands that
#  will invoke that target)
require Logger
alias Domain.Account.Commands, as: AccountCmds
alias Domain.User.Commands, as: UserCmds
alias Domain.Monitor.Commands, as: MonitorCmds
alias Domain.StatusPage.Commands, as: StatusPageCmds
alias Domain.Issue.Commands, as: IssueCmds

days = 86_400
hours = 3_600
minutes = 60

Logger.info("Running event store seeds...")

# In favour of this is that you get "real" IDs. Against
# is that you have to re-login if you re-generate the db
# because your account (and, below, user) ID will change.
my_account_id = Domain.Id.new()

status_page_id = Domain.Id.new()

status_page_only_status_page_id = Domain.Id.new()

event_id = Domain.Id.new()
correlation_id = Domain.Id.new()

slack_oauth_token =
  System.get_env("SLACK_TEST_APP_OAUTH_TOKEN", "#{my_account_id}_slack_access_token_1")

slack_team_id = System.get_env("SLACK_TEST_APP_TEAM_ID", "#{my_account_id}_slack_team_id_1")
{:ok, host_name} = :net.gethostname()
host_name = List.to_string(host_name)

private_instance_id = Domain.Id.new()

users = [
  # This is a bit of a manual process, but ensures that you can log in directly
  # with OAuth/Slack on a fresh db. Exercise for the reader: fetch this list
  # from OAuth when this runs (all @canarymonitor.com users, basically).
  %{
    mail: "cees@metrist.io",
    oauth: "oauth2|slack|T015X4DFJ6M-U01FWQDPME0"
  },
  %{
    mail: "dave@metrist.io",
    oauth: "oauth2|slack|T015X4DFJ6M-U01BK2GSTTN"
  },
  %{
    mail: "nikko@metrist.io",
    oauth: "oauth2|slack|T015X4DFJ6M-U01BF55PMUP"
  },
  %{
    mail: "ryan@metrist.io",
    oauth: "oauth2|slack|T015X4DFJ6M-U015H4ASE3F"
  },
  %{
    mail: "daven@metrist.io",
    oauth: "oauth2|slack|T015X4DFJ6M-U02EXJKEWKX"
  },
  %{
    mail: "michelle@metrist.io",
    oauth: "oauth2|slack|T015X4DFJ6M-U03DKQWDTKP"
  },
  %{
    mail: "tina@metrist.io",
    oauth: "oauth2|slack|T015X4DFJ6M-U03DG352FL6"
  },
  %{
    mail: "bruce@metrist.io",
    oauth: "google-oauth2|117285050364886360603"
  },
  %{
    mail: "aydan.jiwani@metrist.io",
    oauth: "oidc|dev1-slack-openidconnect|U04154R4TM3"
  },
	%{
		mail: "david.sabine@metrist.io",
		oauth: "google-oauth2|102279558746170132647"
	},
  %{
    mail: "david.xiao@metrist.io",
    oauth: "google-oauth2|102673358331988838894"
  }
]

# We make this a function so we get slightly different values for shared and private

# 10% fuzzing so we don't get too uniform data, time-wise
fuzzed_offset = fn v, precision ->
  fuzz = div(precision, 10)
  h_fuzz = div(fuzz, 2)
  offset = h_fuzz - :rand.uniform(fuzz)
  -(v * precision - offset)
end

base_cmds = [
  %MonitorCmds.AddTelemetry{
    id: "SHARED_testsignal",
    account_id: "SHARED",
    monitor_logical_name: "testsignal",
    instance_name: host_name,
    is_private: false,
    value: nil,
    report_time: nil,
    check_logical_name: nil
  },
  %MonitorCmds.AddTelemetry{
    id: "#{my_account_id}_testsignal",
    account_id: my_account_id,
    monitor_logical_name: "testsignal",
    instance_name: private_instance_id,
    is_private: true,
    value: nil,
    report_time: nil,
    check_logical_name: nil
  },
  %MonitorCmds.AddTelemetry{
    id: "#{my_account_id}_fakeprivatesyntheticnoshared",
    account_id: my_account_id,
    monitor_logical_name: "fakeprivatesyntheticnoshared",
    instance_name: private_instance_id,
    is_private: true,
    value: nil,
    report_time: nil,
    check_logical_name: nil
  }
]

telem =
  for bc <- base_cmds do
    # 30 days every 12 hours = 60 points
    h12h_offsets = for i <- 1..60, do: fuzzed_offset.(i, 12 * hours)
    # 7 days ever 4 hour = 42 points
    h4h_offsets = for i <- 1..42, do: fuzzed_offset.(i, 4 * hours)
    # 1 day every 30 minutes = 48 points
    h30m_offsets = for i <- 1..48, do: fuzzed_offset.(i, 30 * minutes)
    # 4 hours every 5 minutes = 48 points
    h5m_offsets = for i <- 1..48, do: fuzzed_offset.(i, 5 * minutes)

    offsets =
      [h12h_offsets, h4h_offsets, h30m_offsets, h5m_offsets]
      |> List.flatten()
      |> Enum.sort()
      |> Enum.uniq()

    {bc, offsets}
  end

base_cmds = [
  %MonitorCmds.AddError{
    id: "SHARED_testsignal",
    error_id: Domain.Id.new(),
    instance_name: host_name,
    check_logical_name: nil,
    message: nil,
    report_time: nil,
    monitor_logical_name: "testsignal",
    account_id: "SHARED",
    is_private: false
  },
  %MonitorCmds.AddError{
    id: "#{my_account_id}_testsignal",
    error_id: Domain.Id.new(),
    instance_name: private_instance_id,
    check_logical_name: nil,
    message: nil,
    report_time: nil,
    monitor_logical_name: "testsignal",
    account_id: my_account_id,
    is_private: true
  }
]

errors =
  for bc <- base_cmds do
    # Guarantee at least 5 errors in the month
    count = :rand.uniform(10) + 1000

    offsets =
      1..count
      |> Enum.map(fn _ -> -1 * :rand.uniform(30 * 86_400) end)
      |> Enum.sort()

    {bc, offsets}
  end

make_observations = fn components, state, seconds_ago, monitor_logical_name, status_page_id ->
  %StatusPageCmds.ProcessObservations{
    id: status_page_id,
    page: monitor_logical_name,
    observations:
      for component <- components do
        %StatusPageCmds.Observation{
          changed_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(-seconds_ago),
          component: component,
          instance: nil,
          status: "#{state}",
          state: state
        }
      end
  }
end

testsignal_template = Backend.Projections.Dbpa.MonitorConfig.template("testsignal", "SHARED")

# Actual seed command list starts here
[
  # "ADMIN" is a fake user with some special treatment so we can bootstrap a database.
  %UserCmds.Create{id: "ADMIN", user_account_id: "SHARED", email: "admin@example.com"},

  # Setup shared account
  %AccountCmds.Create{
    id: "SHARED",
    name: "Metrist",
    creating_user_id: "ADMIN",
    selected_instances: [],
    selected_monitors: []
  },
  %AccountCmds.AddAPIToken{id: "SHARED", api_token: "fake-api-token-for-dev"},
  %AccountCmds.AddMonitor{
    id: "SHARED",
    logical_name: "testsignal",
    name: "Test Signal",
    default_degraded_threshold: 10.0,
    instances: [host_name],
    check_configs: []
  },
  %MonitorCmds.Create{
    id: "SHARED_testsignal",
    monitor_logical_name: "testsignal",
    name: "Test Signal",
    account_id: "SHARED"
  },
  %MonitorCmds.AddConfig{
    id: "SHARED_testsignal",
    config_id: Domain.Id.new(),
    monitor_logical_name: "testsignal",
    interval_secs: 60,
    run_spec: testsignal_template.run_spec,
    extra_config: %{
      "first-key" => "first value",
      "second-key" => "second much longer value for testing"
    },
    run_groups: ["local-development"],
    steps: testsignal_template.steps
  },
  # Setup user account
  %AccountCmds.Create{
    id: my_account_id,
    name: "Local Dev Account",
    creating_user_id: "ADMIN",
    selected_instances: [],
    selected_monitors: []
  },
  Enum.map(users, fn user ->
    id = Domain.Id.new()

    [
      %UserCmds.Create{id: id, user_account_id: nil, email: user.mail, uid: user.oauth},
      %AccountCmds.AddUser{id: my_account_id, user_id: id},
      %UserCmds.MakeAdmin{id: id}
    ]
  end),
  %AccountCmds.AddMonitor{
    id: my_account_id,
    logical_name: "testsignal",
    name: "Test Signal",
    default_degraded_threshold: 10.0,
    instances: [host_name],
    check_configs: []
  },
  for {monitor, tag} <- [
        {"authzero", "saas"},
        {"avalara", "api"},
        {"awslambda", "aws"},
        {"azuread", "azure"},
        {"azureaks", "azure"},
        {"bambora", "api"},
        {"braintree", "api"},
        {"jira", "api"},
        {"fastly", "api"},
        {"circleci", "saas"},
        {"github", "saas"},
        {"cloudflare", "infrastructure"},
        {"cognito", "aws"},
        {"datadog", "saas"},
        {"easypost", "api"},
        {"ec2", "aws"},
        {"zoom", "saas"},
        {"gke", "gcp"},
        {"newrelic", "saas"},
        {"envoy", "saas"},
        {"envoy", "metrist.beta:true"}
      ],
      name = "#{Macro.camelize(monitor)}",
      template = Backend.Projections.Dbpa.MonitorConfig.template(monitor, "SHARED"),
      monitor_id = "SHARED_#{monitor}",
      template != :template_not_found do
    commands = [
      %AccountCmds.AddMonitor{
        id: "SHARED",
        logical_name: monitor,
        name: name,
        default_degraded_threshold: 10.0,
        instances: [host_name],
        check_configs: []
      },
      %MonitorCmds.Create{
        id: monitor_id,
        monitor_logical_name: monitor,
        name: monitor,
        account_id: "SHARED"
      },
      %MonitorCmds.AddConfig{
        id: monitor_id,
        config_id: Domain.Id.new(),
        monitor_logical_name: monitor,
        interval_secs: 60,
        run_spec: template.run_spec,
        run_groups: ["local-development"],
        steps: template.steps
      },
      %MonitorCmds.AddTag{id: monitor_id, tag: tag},
      %AccountCmds.AddMonitor{
        id: my_account_id,
        logical_name: monitor,
        name: name,
        default_degraded_threshold: 10.0,
        instances: [host_name],
        check_configs: []
      }
    ]

    add_telemetry_cmds =
      Enum.map(template.steps, fn step ->
        %MonitorCmds.AddTelemetry{
          id: "SHARED_#{monitor}",
          account_id: "SHARED",
          check_logical_name: step.check_logical_name,
          monitor_logical_name: monitor,
          instance_name: host_name,
          report_time: NaiveDateTime.utc_now(),
          is_private: false,
          value: abs(Statistics.Distributions.Normal.rand(0, 0.1))
        }
      end)

    commands ++ add_telemetry_cmds
  end,
  for {monitor, tag} <- [{"fakeprivatesyntheticnoshared", "metrist.beta:true"}],
      monitor_id = "#{my_account_id}_#{monitor}" do
    [
      %AccountCmds.AddMonitor{
        id: my_account_id,
        logical_name: monitor,
        name: "Fake Private Synthetic Without Shared",
        default_degraded_threshold: 10.0,
        instances: [host_name],
        check_configs: []
      },
      %MonitorCmds.Create{
        id: monitor_id,
        monitor_logical_name: monitor,
        name: monitor,
        account_id: my_account_id
      },
      %MonitorCmds.AddConfig{
        id: monitor_id,
        config_id: Domain.Id.new(),
        monitor_logical_name: monitor,
        interval_secs: 60,
        run_spec: testsignal_template.run_spec,
        run_groups: ["local-development"],
        steps: testsignal_template.steps
      },
      %MonitorCmds.AddTag{id: monitor_id, tag: tag}
    ]
  end,
  for {monitor, tag} <- [{"statuspageonlymonitor", "aws"}],
      monitor_id = "SHARED_#{monitor}" do
    [
      %AccountCmds.AddMonitor{
        id: "SHARED",
        logical_name: monitor,
        name: "Status Page Only Monitor",
        default_degraded_threshold: 10.0,
        instances: [],
        check_configs: []
      },
      %MonitorCmds.Create{
        id: monitor_id,
        monitor_logical_name: monitor,
        name: monitor,
        account_id: "SHARED"
      },
      %AccountCmds.AddMonitor{
        id: my_account_id,
        logical_name: monitor,
        name: "Status Page Only Monitor",
        default_degraded_threshold: 10.0,
        instances: [],
        check_configs: []
      },
      %MonitorCmds.AddTag{id: monitor_id, tag: tag}
    ]
  end,
  %AccountCmds.AttachSlackWorkspace{
    id: my_account_id,
    integration_id: "integration_id",
    team_id: slack_team_id,
    team_name: "#{my_account_id}_slack_1",
    scope: [
      "commands",
      "channels:read",
      "chat:write",
      "chat:write.public"
    ],
    bot_user_id: "#{my_account_id}_slack_bot_id_1",
    access_token: slack_oauth_token
  },
  %AccountCmds.AttachMicrosoftTenant{
    id: my_account_id,
    tenant_id: "#{my_account_id}_tenant_id",
    team_id: "#{my_account_id}_teams_team_id_1",
    team_name: "#{my_account_id}_teams_1"
  },

  # Add random telemetry to both
  for {base_cmd, offsets} <- telem do
    for offset <- offsets do
      report_time =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(offset, :second)

      [
        %MonitorCmds.AddTelemetry{
          base_cmd
          | check_logical_name: "Zero",
            report_time: report_time,
            value: abs(Statistics.Distributions.Normal.rand(0, 0.1))
        },
        %MonitorCmds.AddTelemetry{
          base_cmd
          | check_logical_name: "Normal",
            report_time: report_time,
            value: Statistics.Distributions.Normal.rand(10.0, 2.0)
        },
        %MonitorCmds.AddTelemetry{
          base_cmd
          | check_logical_name: "Poisson",
            report_time: report_time,
            value: Statistics.Distributions.Poisson.rand(3.0)
        }
      ]
    end
  end,

  # Add random errors to both
  for {base_cmd, offsets} <- errors do
    for offset <- offsets do
      report_time =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(offset, :second)

      check = ["Normal", "Zero", "Poisson"] |> Enum.at(:rand.uniform(3) - 1)

      %MonitorCmds.AddError{
        base_cmd
        | error_id: Domain.Id.new(),
          check_logical_name: check,
          message: "Could not do check",
          report_time: report_time
      }
    end
  end,

  # Status page. We fake one that starts "up" and then has some blips.
  %StatusPageCmds.Create{id: status_page_id, page: "testsignal"},
  make_observations.(["Normal", "Poisson"], :up, 100 * days, "testsignal", status_page_id),
  make_observations.(["Normal", "Poisson"],:degraded, 7 * days, "testsignal", status_page_id),
  make_observations.(["Normal", "Poisson"],:up, 7 * days - 2 * hours, "testsignal", status_page_id),
  make_observations.(["Normal", "Poisson"],:down, 5 * days, "testsignal", status_page_id),
  make_observations.(["Normal", "Poisson"],:up, 5 * days - 4 * hours, "testsignal", status_page_id),
  make_observations.(["Normal", "Poisson"],:down, 2 * days, "testsignal", status_page_id),
  make_observations.(["Normal", "Poisson"],:degraded, 2 * days - 1 * hours, "testsignal", status_page_id),
  make_observations.(["Normal", "Poisson"],:up, 2 * days - 3 * hours, "testsignal", status_page_id),

  %StatusPageCmds.Create{id: status_page_only_status_page_id, page: "statuspageonlymonitor"},
  make_observations.(["Component1", "Component1"], :up, 100 * days, "statuspageonlymonitor", status_page_only_status_page_id),
  make_observations.(["Component1"], :degraded, 7 * days, "statuspageonlymonitor", status_page_only_status_page_id),
  make_observations.(["Component2"], :degraded, 7 * days, "statuspageonlymonitor", status_page_only_status_page_id),
  make_observations.(["Component1", "Component1"],:up, 7 * days - 2 * hours, "testsignal", status_page_only_status_page_id),

  for multiplier <- 0..50, account_id = my_account_id, service = "testsignal" do
    {state, end_time} = if rem(multiplier, 2) == 0 do
      {Enum.random([:down, :degraded]), nil}
    else
      {:up, NaiveDateTime.utc_now()}
    end

    %IssueCmds.EmitIssue{
      id:                 Domain.IssueTracker.id(account_id, service),
      account_id:         account_id,
      service:            service,
      source:             :monitor,
      start_time:         NaiveDateTime.utc_now() |> NaiveDateTime.add(-multiplier * 2, :minute),
      end_time:           end_time,
      state:              state,
      region:             host_name,
      check_logical_name: "Normal"
    }
  end,

  # And finally a single down/up event.


  # Dummy alert, should not affect timeline
  %AccountCmds.AddAlerts{
      id: "SHARED",
      alerts: [
        %AccountCmds.Alert{
          alert_id: Domain.Id.new(),
          correlation_id: correlation_id,
          monitor_logical_name: "SHARED_testsignal",
          state: :degraded,
          is_instance_specific: false,
          subscription_id: nil,
          formatted_messages: %{
            slack: "slack_message",
            teams: "teams_message",
            email: "message",
            pagerduty: "message"
          },
          affected_regions: [],
          affected_checks: [],
          generated_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(-(10 * days + 1 * hours))
        }
      ]
  },

  %MonitorCmds.AddEvent{
    id: "SHARED_testsignal",
    event_id: event_id,
    instance_name: host_name,
    check_logical_name: "Normal",
    state: "down",
    message: "Normal is down",
    start_time: NaiveDateTime.utc_now() |> NaiveDateTime.add(-(2 * days + 1 * hours)),
    end_time: nil,
    correlation_id: correlation_id
  },
  %MonitorCmds.EndEvent{
    id: "SHARED_testsignal",
    monitor_event_id: event_id,
    end_time: NaiveDateTime.utc_now() |> NaiveDateTime.add(-(2 * days - 4 * hours))
  },
  %MonitorCmds.AddEvent{
    id: "SHARED_testsignal",
    event_id:  Domain.Id.new(),
    instance_name: host_name,
    check_logical_name: "Normal",
    state: "up",
    message: "Normal is up and running",
    start_time: NaiveDateTime.utc_now() |> NaiveDateTime.add(-(2 * days - 4 * hours)),
    end_time: NaiveDateTime.utc_now() |> NaiveDateTime.add(-(2 * days - 4 * hours)),
    correlation_id: correlation_id
  },
  # Alerting.
  %AccountCmds.AddSubscriptions{
    id: my_account_id,
    subscriptions: [
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "testsignal",
        delivery_method: "webhook",
        identity: "https://webhooks.metri.st/url/may/have/secrets",
        display_name: "https://webhooks.metri.st/url/may/have/secrets",
        regions: nil,
        extra_config: %{
          "AdditionalHeaders" => %{"authorization" => "secretsecret"}
        }
      },
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "testsignal",
        delivery_method: "slack",
        identity: "#testing-channel",
        display_name: "#testing-channel",
        regions: nil,
        extra_config: %{WorkspaceId: "T015X4DFJ6M"}
      },
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "testsignal",
        delivery_method: "slack",
        identity: "#testing-channel2",
        display_name: "#testing-channel2",
        regions: nil,
        extra_config: %{WorkspaceId: "T015X4DFJ6M"}
      },
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "cloudflare",
        delivery_method: "slack",
        identity: "#testing-channel",
        display_name: "#testing-channel",
        regions: nil,
        extra_config: %{WorkspaceId: "T015X4DFJ6M"}
      },
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "datadog",
        delivery_method: "slack",
        identity: "#testing-channel",
        display_name: "#testing-channel",
        regions: nil,
        extra_config: %{WorkspaceId: "T015X4DFJ6M"}
      },
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "testsignal",
        delivery_method: "pagerduty",
        identity: "routing_key_is_a_secret",
        display_name: "routing_key_is_a_secret",
        regions: nil,
        extra_config: %{}
      },
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "testsignal",
        delivery_method: "datadog",
        identity: "api_key_is_a_secret",
        display_name: "api_key_is_a_secret",
        regions: nil,
        extra_config: %{}
      },
      %AccountCmds.Subscription{
        subscription_id: Domain.Id.new(),
        monitor_id: "testsignal",
        delivery_method: "email",
        identity: "email_is_a_secret@metrist.io",
        display_name: "email_is_a_secret@metrist.io",
        regions: nil,
        extra_config: %{}
      }
    ]
  }
]
|> List.flatten()
|> Enum.each(fn cmd ->
  res = Backend.App.dispatch_with_actor(Backend.Auth.Actor.db_setup(), cmd)
  Logger.info("Seed command #{inspect(cmd)} => #{inspect(res)}")
end)

Logger.info("status_page_id in seeds for testsignal: #{status_page_id}")

# We're going to cheat here so that we don't have to wait for the projection
status_page_component_id =
  Commanded.Aggregates.Aggregate.aggregate_state(Backend.App, Domain.StatusPage, status_page_id)
  |> Map.get(:scraped_components)
  |> Map.get({"Normal", "nil", nil})

Logger.info("status page component_id: #{status_page_component_id}")

# make a status page subscription now that enough time has elapsed for an evented status page component to be added for testsignal...
Backend.App.dispatch_with_actor(Backend.Auth.Actor.db_setup(), %StatusPageCmds.AddSubscription{
  id: status_page_id,
  component_id: status_page_component_id,
  account_id: my_account_id
})

Logger.info("Event store seeding done, sleeping a bit for everything to catch up...")
Process.sleep(5_000)
Logger.info("Event store sleep done, the database feels totally refreshed now!")
