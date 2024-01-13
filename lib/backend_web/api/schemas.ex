defmodule BackendWeb.API.Schemas do
  alias OpenApiSpex.Schema

  defmodule MonitorConfigSchema do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        # The title is optional. It defaults to the last section of the module name.
        # So the derived title for MyApp.User is "User".
        title: "Monitor Config",
        description: "A monitor configuration definition",
        type: :object,
        properties: %{
          id: %Schema{type: :string, description: "The ID of the existing config if applicable"},
          monitor_logical_name: %Schema{type: :string, description: "The monitor logical name of the monitor to configure"},
          interval_secs: %Schema{type: :integer, description: "The time between monitor runs in seconds"},
          run_groups: %Schema{type: :array, description: "The run groups for this config", default: [], minItems: 0, uniqueItems: true},
          run_spec: %Schema{
            type: :object,
            properties: %{
              name: %Schema{ type: :string, description: "The name of the monitor"},
              run_type: %Schema{ type: :string, description: "The run type", enum: ["exe", "dll", "ping"]}
            }
          },
          steps:  %Schema{
            type: :array,
            description: "The run groups for this config",
            items: %Schema{
              type: :object,
              properties: %{
                check_logical_name: %Schema{ type: :string, description: "The name of the check to run"},
                timeout_secs: %Schema{ type: :integer, description: "The timeout value for the check", default: 900}
              }
            },
            minItems: 0
          },
          extra_config:  %Schema{
            type: :array,
            description: "Any config values for the monitor",
            items: %Schema{
              type: :object,
              properties: %{
                name: %Schema{ type: :string, description: "The name of the config value to set"},
                value: %Schema{ type: :string, description: "The value for the config value"}
              }
            },
          }
        },
        required: [:monitor_logical_name, :interval_secs, :run_groups, :run_spec, :steps],
        example: %{
          monitor_logical_name: "asana",
          interval_secs: 120,
          run_groups: [],
          run_spec: %{
            name: "asana",
            run_type: "dll"
          },
          steps: [
            %{
              check_logical_name: "Ping",
              timeout_secs: 900
            }
          ],
          extra_config: [
            %{
              name: "ConfigVariableName",
              value: "ConfigVariableValue"
            }
          ]
        }
      }
    )
  end

  defmodule PagingMetadata do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Paging Metadata",
        description: "Provides cursor data for an API request",
        type: :object,
        properties: %{
          cursor_after: %Schema{type: :string, description: "an opaque cursor representing the last row of the current page"},
          cursor_before: %Schema{type: :string, description: "an opaque cursor representing the first row of the current page"},
        }
      })
  end

  defmodule MonitorErrorCount do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        # The title is optional. It defaults to the last section of the module name.
        # So the derived title for MyApp.User is "User".
        title: "Monitor Error Count",
        description: "A count of monitor errors per Monitor, Instance and Check",
        type: :object,
        properties: %{
          timestamp: %Schema{ type: :string, description: "Time when the error was generated", format: :datetime},
          monitor_logical_name: %Schema{ type: :string, description: "Logical name of monitor"},
          instance: %Schema{ type: :string, description: "Instance that generated the error"},
          check: %Schema{ type: :string, description: "Check that generated the error"},
          count: %Schema{ type: :integer, description: "Error count"}
        },
        example: %{
          timestamp:            "2022-04-21T14:58:17.175203",
          monitor_logical_name: "testsignal",
          instance:             "instance",
          check:                "check",
          count:                5
        }
      }
    )
  end

  defmodule MonitorErrorsResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        # The title is optional. It defaults to the last section of the module name.
        # So the derived title for MyApp.User is "User".
        title: "Monitor Error Response",
        description: "Response containing monitor errors",
        type: :object,
        properties: %{
          entries: %Schema{description: "Returned values", type: :array, items: MonitorErrorCount},
          metadata: PagingMetadata,
        }
      }
    )
  end

  defmodule MonitorConfigsResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor Configs Response",
        description: "A list of monitor configs",
        type: :array,
        items: MonitorConfigSchema
      })
  end


  defmodule MonitorListResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor List Response",
        description: "A list of monitors",
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            name: %Schema{ type: :string, description: "The name of the monitor"},
            logical_name: %Schema{ type: :string, description: "The logical name of the monitor"}
          }
        }
      })
  end

  defmodule MonitorStatusResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor Statuses Response",
        description: "A collection of monitor statuses",
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            last_checked: %Schema{ type: :string, description: "The last time this monitor was checked by Metrist", format: :datetime},
            monitor_logical_name: %Schema{ type: :string, description: "Logical name of monitor"},
            state: %Schema{ type: :string, description: "The state of the monitor up, degraded, issues, down", enum: ["up", "degraded", "down", "issues"]}
          }
        }
      })
  end

  defmodule MonitorTelemetry do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor Telemetry",
        description: "A collection of Telemetry Entries",
        type: :object,
        properties: %{
          timestamp: %Schema{ type: :string, description: "Time when the error was generated", format: :datetime},
          monitor_logical_name: %Schema{ type: :string, description: "Logical name of monitor"},
          instance: %Schema{ type: :string, description: "Instance that generated the telemetry"},
          check: %Schema{ type: :string, description: "Check that generated the telemetry"},
          value: %Schema{ type: :number, description: "The average time this check took to execute in milliseconds"}
        },
      }
    )
  end

  defmodule MonitorTelemetryResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor Telemetry Response",
        description: "An array of MonitorTelemetry",
        type: :array,
        items: MonitorTelemetry,
        example: %{
          timestamp: "2022-04-21T14:58:17.175203",
          monitor_logical_name: "testsignal",
          instance: "instance",
          check: "check",
          value: 200.0
        }
      }
    )
  end

  defmodule StatusPageComponentChange do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Status Page Component Change",
        description: "A single change for a single status page component",
        type: :object,
        properties: %{
          id: %Schema{ type: :string, description: "Unique Metrist id for the change"},
          timestamp: %Schema{ type: :string, description: "Time when the change occurred", format: :datetime},
          monitor_logical_name: %Schema{ type: :string, description: "Logical name of monitor"},
          component: %Schema{ type: :string, description: "Component name that was changed"},
          status: %Schema{ type: :string, description: "Status from the provider status page"}
        },
        example: %{
          id: "11zLogxjA8i8ASoNeXFijut",
          timestamp: "2022-04-21T14:58:17.175203",
          monitor_logical_name: "testsignal",
          component: "component 1",
          status: "operational"
        }
      }
    )
  end

  defmodule StatusPageChangesResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Status Page Changes Response",
        description: "A collection of Status Page Component Changes",
        type: :object,
        properties: %{
          entries: %Schema{description: "Returned values", type: :array, items: StatusPageComponentChange},
          metadata: PagingMetadata,
        }
      }
    )
  end

  defmodule MonitorCheck do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor Check",
        description: "A single monitor check",
        type: :object,
        properties: %{
          logical_name: %Schema{ type: :string, description: "The logical name of the check"},
          name: %Schema{ type: :string, description: "The display name of the check"}
        }
      })
  end

  defmodule MonitorChecksResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor Checks Response",
        description: "A list of monitors + their checks",
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            monitor_logical_name: %Schema{ type: :string, description: "The logical name of the monitor"},
            checks: %Schema{
              type: :array,
              description: "The unique checks for that monitor",
              items: MonitorCheck
              }
            }
          }
        }
      )
  end

  defmodule MonitorInstancesResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Monitor Instances Response",
        description: "A list of monitors + their instances",
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            monitor_logical_name: %Schema{ type: :string, description: "The logical name of the monitor"},
            instances: %Schema{
              type: :array,
              description: "The unique instances for that monitor",
              items: %Schema{ type: :string }
            }
          }
        }
      })
  end

  defmodule IssuesList do
    require OpenApiSpex

    @severity Enum.map(Backend.Projections.Dbpa.MonitorEvent.states(), &Atom.to_string/1)
    @source ["monitor", "status_page"]

    OpenApiSpex.schema(
      %{
        title: "Issues list",
        description: "List of issues",
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, description: "Issue id"},
            source: %Schema{type: :string, description: "Issue source", enum: @source},
            severity: %Schema{type: :string, description: "Severity", enum: @severity},
            service: %Schema{type: :string, description: "Service name"},
            start_time: %Schema{type: :string, description: "Start time", format: :datetime},
            end_time: %Schema{type: :string, description: "End time", format: :datetime},
          },
          required: [:source, :severity, :service, :start_time]
        }
      })

    def severity, do: @severity
    def source, do: @source
  end

  defmodule IssueEventsList do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Issue events list",
        description: "List of issue events",
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, description: "Issue event id"},
            source: %Schema{type: :string, description: "The source of an issue event ", enum: IssuesList.source()},
            component_id: %Schema{type: :string, description: "Status page component id of the event. Available if source is status_page"},
            region: %Schema{type: :string, description: "Region of which the issue event originated. Available if source is monitor"},
            check_logical_name: %Schema{type: :string, description: "Monitor check logical name of which the issue event originated. Available if source is monitor"},
            state: %Schema{type: :string, description: "The state of the a service", enum: IssuesList.severity()},
            start_time: %Schema{type: :string, description: "Start time", format: :datetime},
            end_time: %Schema{type: :string, description: "End time", format: :datetime},
          },
          required: [:source, :severity, :service, :start_time]
        }
      })
  end

  defmodule IssuesListResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "List issues response",
        type: :object,
        properties: %{
          entries: %Schema{description: "Returned values", type: :array, items: IssuesList},
          metadata: PagingMetadata,
        }
      }
    )
  end

  defmodule IssueEventsListResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "List issue events response",
        type: :object,
        properties: %{
          entries: %Schema{description: "Returned values", type: :array, items: IssueEventsList},
          metadata: PagingMetadata,
        }
      }
    )
  end
end
