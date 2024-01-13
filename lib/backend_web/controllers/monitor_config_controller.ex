defmodule BackendWeb.MonitorConfigController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  alias BackendWeb.API.Schemas.{MonitorConfigSchema, MonitorConfigsResponse}

  require Logger

  use TypedStruct

  @doc """
  Creates a MonitorConfig object

  Sample request body:

  ```
  {
    "monitor_logical_name": "asana",
    "interval_secs": 120,
    "run_groups": ["Metrist Agent"],
    "run_spec": {
      "name": "asana",
      "run_type": "dll"
    },
    "steps": [
      {
        "check_logical_name": "Ping",
        "timeout_secs": 900
      }
    ]
  }
  ```

  Returns the ID of the MonitorConfig object.

  Example:

  ```
  curl -d $JSON -H "Content-Type: application/json" -H "Authorization: Bearer XXX" 'https://app.metrist.io/api/v0/monitor-config'
  ```

  Returns:

  ```
  11y9YlrWxXf39mRWIrhFtPl
  ```
  """

  operation :post,
    summary: "Add a monitor config to your account",
    request_body: {"Config attributes", "application/json", MonitorConfigSchema, required: true},
    tags: ["Monitor Config"],
    responses: %{
      202 => {"config_id of added config", "text/plain", %OpenApiSpex.Schema{ type: :string }}
    }
  def post(conn, _params) do
    body = conn.body_params
    monitor = body["monitor_logical_name"]
    account_id = get_session(conn, :account_id)
    config_id = Domain.Id.new()

    steps = body["steps"]
    |> Enum.map(fn step ->
      %Domain.Monitor.Commands.Step{
        check_logical_name: step["check_logical_name"],
        timeout_secs: step["timeout_secs"]
      }
    end)

    run_spec = body["run_spec"]
    extra_config =
      case body["extra_config"] do
        nil -> nil
        extra_config ->
          Enum.map(extra_config, fn %{"name" => name, "value" => value} -> {name, value} end)
          |> Map.new()
      end

    command = %Domain.Monitor.Commands.AddConfig{
      id: Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor),
      account_id: account_id,
      config_id: config_id,
      monitor_logical_name: monitor,
      interval_secs: body["interval_secs"],
      run_spec: %Domain.Monitor.Commands.RunSpec{
        run_type: String.to_existing_atom(run_spec["run_type"]),
        name: run_spec["name"]
      },
      run_groups: body["run_groups"],
      steps: steps,
      extra_config: extra_config
    }
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(conn, command)
    Backend.Projections.register_api_hit(account_id)

    conn
    |> put_resp_content_type("text/plain")
    |> resp(202, config_id)
  end

  @doc """
  Deletes a MonitorConfig object

  Example:

  ```
  curl -X DELETE -H "Authorization: Bearer XXX" 'https://app.metrist.io/api/v0/monitor-config/asana/11y9YlrWxXf39mRWIrhFtPl'
  ```

  Returns:

  ```
  OK
  ```
  """
  operation :delete,
    summary: "Delete a monitor config from your account",
    parameters: [
      monitor: [ in: :path, description: "The monitor logical name on which you wish to delete the config", type: :string ],
      id: [ in: :path, description: "The ID of the config to delete", type: :string ],
    ],
    tags: ["Monitor Config"],
    responses: [
      ok: {"OK", "text/plain", %OpenApiSpex.Schema{ type: :string } }
    ]
  def delete(conn, _params = %{"monitor" => monitor, "id" => config_id}) do
    account_id = get_session(conn, :account_id)

    command = %Domain.Monitor.Commands.RemoveConfig{
      id: Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor),
      config_id: config_id
    }

    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(conn, command)
    Backend.Projections.register_api_hit(account_id)

    conn
    |> put_resp_content_type("text/plain")
    |> resp(200, "OK")
  end

  operation :get,
    summary: "List monitor configs in your account for a specific monitor",
    parameters: [
      monitor: [ in: :query, description: "The monitor logical name for which you wish to retrieve the configs", type: :string, required: false ]
    ],
    tags: ["Monitor Config"],
    responses: [
      ok: {"OK", "application/json", MonitorConfigsResponse }
    ]
  def get(conn, params) do
    monitor = params["monitor"]
    account_id = get_session(conn, :account_id)

    configs =
      if is_nil(monitor) do
        Backend.Projections.get_monitor_configs(account_id)
      else
        Backend.Projections.get_monitor_configs_by_monitor_logical_name(account_id, monitor)
      end

    entries = Enum.map(configs, fn c ->
      %MonitorConfigSchema{
        id: c.id,
        monitor_logical_name: c.monitor_logical_name,
        interval_secs: c.interval_secs,
        run_groups: c.run_groups,
        run_spec: c.run_spec,
        steps: c.steps,
        extra_config:
          if is_nil(c.extra_config) do
            c.extra_config
          else
            Enum.map(c.extra_config, fn {key, _val} -> %{ name: key, value: "<redacted>" } end)
          end
      }
    end)

    Backend.Projections.register_api_hit(account_id)

    json(conn, entries)
  end
end
