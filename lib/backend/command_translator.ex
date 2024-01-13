defmodule Backend.CommandTranslator do
  @doc """
  Translate between commands in the format of our .NET framework and
  commands that Commanded expects.
  """
  @spec translate(map) :: struct()
  def translate(cmd) do
    translate_cmd(cmd)
  end

  def translate_id(account_id, monitor_logical_name) do
    Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor_logical_name)
  end

  defp translate_cmd(c = %{"Command" => "AddMonitorEvent"}) do
    %Domain.Monitor.Commands.AddEvent{
      id: translate_id(c["Id"], c["MonitorLogicalName"]),
      event_id: Domain.Id.new(),
      check_logical_name: c["CheckLogicalName"],
      instance_name: c["InstanceName"],
      message: c["Message"],
      state: c["State"],
      start_time: Backend.JsonUtils.maybe_time_from(c["StartTime"]),
      end_time: Backend.JsonUtils.maybe_time_from(c["EndTime"]),
      correlation_id: c["CorrelationId"]
    }
  end

  defp translate_cmd(c = %{"Command" => "EndMonitorEvent"}),
    do: %Domain.Monitor.Commands.EndEvent{
      id: translate_id(c["Id"], c["MonitorLogicalName"]),
      monitor_event_id: c["MonitorEventId"],
      end_time: NaiveDateTime.utc_now()
    }

  defp translate_cmd(c = %{"Command" => "ClearMonitorEvents"}),
    do: %Domain.Monitor.Commands.ClearEvents{
      id: translate_id(c["Id"], c["MonitorLogicalName"]),
      end_time: NaiveDateTime.utc_now()
    }

  defp translate_cmd(c = %{"Command" => "AddSlackSlashCommand"}),
    do: %Domain.Account.Commands.AddSlackSlashCommand{
      id: c["Id"],
      data: c["Data"]
    }

  defp translate_cmd(c = %{"Command" => "AddMicrosoftTeamsCommand"}),
    do: %Domain.Account.Commands.AddMicrosoftTeamsCommand{
      id: c["Id"],
      data: c["Data"]
    }

  defp translate_cmd(c = %{"Command" => "UpdateMicrosoftTenant"}),
    do: %Domain.Account.Commands.UpdateMicrosoftTenant{
      id: c["Id"],
      tenant_id: c["TenantId"],
      team_id: c["TeamId"],
      team_name: c["TeamName"],
      service_url: c["ServiceUrl"]
    }

  defp translate_cmd(c = %{"__struct__" => "Domain.Monitor.Commands.AddConfig"}) do
    %Domain.Monitor.Commands.AddConfig{
      id: c["id"],
      config_id: c["config_id"],
      account_id: c["account_id"],
      monitor_logical_name: c["monitor_logical_name"],
      interval_secs: c["interval_secs"],
      extra_config: c["extra_config"],
      run_groups: c["run_groups"],
      run_spec: %Domain.Monitor.Commands.RunSpec{
        name: c["run_spec"]["name"],
        run_type: String.to_existing_atom(c["run_spec"]["run_type"])
      },
      steps: Enum.map(c["steps"], fn step ->
        %Domain.Monitor.Commands.Step{
          check_logical_name: step["check_logical_name"],
          timeout_secs: step["timeout_secs"]
        }
      end)
    }
  end

  defp translate_cmd(c = %{"__struct__" => _}) do
    to_struct(c)
  end

  defp translate_cmd(c) do
    raise "Unsupported command received, please add translation in command_translator.ex.\n#{inspect c, pretty: true}"
  end

  defp to_struct(m) when is_map(m) do
    m
    |> Enum.map(fn
      {"__struct__", t} ->
        {:__struct__, String.to_atom("Elixir." <> t)}
      {k, v} ->
        {String.to_atom(k), to_struct(v)}
    end)
    |> Map.new()
  end
  defp to_struct(l) when is_list(l) do
    Enum.map(l, &to_struct(&1))
  end
  defp to_struct(o), do: o
end
