defmodule Backend.Projections.Dbpa.MonitorConfig do
  use Ecto.Schema
  require Logger

  @primary_key {:id, :string, []}
  schema "monitor_configs" do
    field :monitor_logical_name, :string
    field :interval_secs, :integer
    field :extra_config, :map
    field :run_groups, {:array, :string}
    field :run_spec, :map         # Domain.Monitor.Commands.RunConfig
    field :steps, {:array, :map}  # Array of Domain.Monitor.Commands.Step
    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  @doc """
  get configured monitors for the account that match the run groups. Rules for run groups are as follows:
  * if run_groups is empty, we match everything.
  * if one or more run_groups ae set, we match in an OR fashion. So `[a, b]` matches `[a, c]` and `[b, c]`
  """
  def get_monitor_configs(account_id, run_groups) when is_binary(run_groups), do: get_monitor_configs(account_id, [run_groups])
  def get_monitor_configs(account_id, run_groups) do
    Repo.all(__MODULE__, prefix: Backend.Repo.schema_name(account_id))
      |> Enum.filter(fn config ->
        !run_groups || Enum.empty?(run_groups) || Enum.any?(config.run_groups, fn rg -> Enum.member?(run_groups, rg) end)
      end)
    |> Enum.map(&deserialize_inner_json/1)
  end

  def get_monitor_config_by_id(account_id, id) do
    Repo.get(__MODULE__, id, prefix: Repo.schema_name(account_id))
    |> deserialize_inner_json()
  end

  def get_monitor_configs_by_monitor_logical_name(account_id, monitor_logical_name) do
    query =
      from mc in __MODULE__,
      where: mc.monitor_logical_name == ^monitor_logical_name
    Repo.all(query, prefix: Repo.schema_name(account_id))
    |> Enum.map(&deserialize_inner_json/1)
  end

  def get_monitor_config_by_name(account_id, monitor_logical_name) do
    query =
          from mc in __MODULE__,
            where: mc.monitor_logical_name == ^monitor_logical_name

    Repo.one(query, prefix: Repo.schema_name(account_id))
    |> deserialize_inner_json()
  end

  # Public for testing. If we want this elsewhere, please move it.
  # The database deserializes the run_spec and steps as maps with string keys. These do
  # not conform to the intended types, therefore convert to the expected types here.
  def deserialize_inner_json(monitor_config) do
    %__MODULE__{monitor_config |
                steps: Enum.map(monitor_config.steps || [], &step_from_json/1),
                run_spec: spec_from_json(monitor_config.run_spec)}
  end

  def spec_from_json(nil), do: nil
  def spec_from_json(json) do
    %Domain.Monitor.Commands.RunSpec{
      run_type: String.to_atom(Map.get(json, "run_type")),
      name: Map.get(json, "name")
    }
  end
  def step_from_json(json) do
    %Domain.Monitor.Commands.Step{
      check_logical_name: Map.get(json, "check_logical_name"),
      timeout_secs: Map.get(json, "timeout_secs")
    }
  end

  # TODO Move this to a database/projection. For now, this'll do.

  # Note that we generally only return webhook/SQS involving steps for our special "SHARED" account. This is not something that
  # is readily reproducible for private monitoring setups.

  @default_timeout_secs 900.0
  def default_timeout_secs(), do: @default_timeout_secs

  # Hardcoded templates to easily setup monitors.
  def template(monitor_logical_name, account_id) do
    with {run_type, name, steps} <- get_template(monitor_logical_name, account_id) do
      steps =
        steps
        |> Enum.map(fn
          {step_name, timeout} -> %Domain.Monitor.Commands.Step{check_logical_name: step_name, timeout_secs: timeout}
          just_step -> %Domain.Monitor.Commands.Step{check_logical_name: just_step, timeout_secs: @default_timeout_secs}
        end)
      %{
        run_spec: %Domain.Monitor.Commands.RunSpec{run_type: run_type, name: name},
        steps: steps
      }
    else
      _ -> :template_not_found
    end
  end

  # Crutch while we specify this in code, this allows us to also define timeouts for single-step scenarios
  # which happen when we specify a non-null value in a monitor_config check_logical_name
  def timeout(_monitor_logical_name, _step_logical_name, _account_id), do: @default_timeout_secs

  defp get_template(m = "test_do_not_use", _), do: {:exe, m, ["StepOne", {"StepTwo", 2.5}]} # For unit testing.

  defp get_template(m = "artifactory", _), do: {:dll, m, ["UploadArtifact", "DownloadArtifact", "DeleteArtifact"]}
  defp get_template(m = "authzero", _), do: {:dll, m, ["GetAccessToken", "GetBranding"]}
  defp get_template(m = "avalara", _), do: {:dll, m, ["Ping"]}
  defp get_template(m = "awslambda", "SHARED"), do: {:dll, m, ["TriggerLambdaAndWaitForResponse"]}
  defp get_template(m = "azuread", _), do: {:dll, m, ["Authenticate", "WriteUser", "ReadUser", "DeleteUser"]}
  defp get_template(m = "azureaks", _), do: {:dll, m, ["CreateCluster", "CreateDeployment", "RemoveDeployment"]}
  defp get_template(m = "azureblob", _), do: {:dll, m, ["CreateStorageAccount", "CreateContainer", "AddBlob", "GetBlob", "DeleteBlob"]}
  defp get_template(m = "azuredb", _), do: {:dll, m, ["CreateCosmosAccount", "CreateDatabase", "CreateContainer",
                                                      "InsertItem", "GetItem", "DeleteItem", "DeleteContainer", "DeleteDatabase"]}
  defp get_template(m = "azurevm", _), do: {:dll, m, ["CreateInstance", "RunInstance", "TerminateInstance", "DescribePersistentInstance"]}
  defp get_template(m = "bambora", _), do: {:dll, m, ["TestPurchase", "TestRefund", "TestVoid"]}
  defp get_template(m = "baseline", _), do: {:dll, m, ["Ping"]}
  defp get_template(m = "braintree", _), do: {:dll, m, ["SubmitSandboxTransaction"]}
  defp get_template(m = "circleci", _), do: {:dll, m, ["StartPipeline", "RunMonitorDockerWorkflow", "RunMonitorMachineWorkflow"]}
  defp get_template(m = "cloudflare", _), do: {:dll, m, ["Ping", "DNSLookup", "CDN"]}
  defp get_template(m = "cognito", _), do: {:dll, m, ["CreateUser", "DeleteUser"]}
  defp get_template(m = "datadog", _), do: {:dll, m, ["SubmitEvent", "GetEvent"]}
  defp get_template(m = "easypost", _), do: {:dll, m, ["GetAddressesTest", "GetAddressesProd", "VerifyInvalidAddress"]}
  defp get_template(m = "ec2", _), do: {:dll, m, ["RunInstance", "TerminateInstance", "DescribePersistentInstance"]}
  defp get_template(m = "fastly", _), do: {:dll, m, ["PurgeCache", "GetNonCachedFile", "GetCachedFile"]}
  defp get_template(m = "github", _), do: {:dll, m, ["PullCode", "PushCode", "RemoveRemoteBranch", "PullRequests", "Issues", "Raw"]}
  defp get_template(m = "gcal", _), do: {:dll, m, ["CreateEvent", "GetEvent", "DeleteEvent"]}
  defp get_template(m = "gke", _), do: {:dll, m, ["CreateDeployment", "RemoveDeployment"]}
  defp get_template(m = "gmaps", _), do: {:dll, m, ["GetDirections", "GetStaticMapImage", "GetGeocodingFromAddress"]}
  defp get_template(m = "heroku", "SHARED"), do: {:dll, m, ["AppPing", "ConfigUpdate", "AppReleaseWebhook"]}
  defp get_template(m = "heroku", _), do: {:dll, m, ["AppPing", "ConfigUpdate"]}
  defp get_template(m = "hubspot", _), do: {:dll, m, ["GetContacts"]}
  defp get_template(m = "jira", _), do: {:dll, m, ["CreateIssue", "DeleteIssue"]}
  defp get_template(m = "kinesis", _), do: {:dll, m, ["WriteToStream", "ReadFromStream"]}
  defp get_template(m = "moneris", _), do: {:dll, m, ["TestPurchase", "TestRefund"]}
  defp get_template(m = "npm", _), do: {:dll, m, ["Ping", "DownloadPackage"]}
  defp get_template(m = "nuget", _), do: {:dll, m, ["ListVersions", "Download"]}
  defp get_template(m = "pagerduty", "SHARED"), do: {:dll, m, ["CreateIncident", "CheckForIncident", "ReceiveWebhook", "ResolveIncident"]}
  defp get_template(m = "pagerduty", _), do: {:dll, m, ["CreateIncident", "CheckForIncident", "ResolveIncident"]}
  defp get_template(m = "pubnub", _), do: {:dll, m, ["SubscribeToChannel", "SendMessage", "ReceiveMessage"]}
  defp get_template(m = "s3", _), do: {:dll, m, ["PutBucket", "PutObject", "GetObject", "DeleteObject", "DeleteBucket"]}
  defp get_template(m = "sendgrid", _), do: {:dll, m, ["SendEmail"]}
  defp get_template(m = "sentry", "SHARED"), do: {:dll, m, ["CaptureEvent", "WaitForIssue", "ResolveIssue", "DeleteIssue"]}
  defp get_template(m = "sentry", _), do: {:dll, m, ["CaptureEvent", "ResolveIssue", "DeleteIssue"]}
  defp get_template(m = "ses", _), do: {:dll, m, ["SendEmail"]}
  defp get_template(m = "slack", _), do: {:dll, m, ["PostMessage"]}
  defp get_template(m = "snowflake", _), do: {:exe, m, ["CreateDatabase", "CreateTable", "PutFile", "GetData", "DeleteData", "DropTable", "DropDatabase"]}
  defp get_template(m = "sqs", _), do: {:dll, m, ["WriteMessage", "ReadMessage"]}
  defp get_template(m = "stripe", _), do: {:dll, m, ["CreateMethod", "CreateIntent", "ConfirmIntent"]}
  defp get_template(m = "testsignal", _), do: {:dll, m, ["Zero", "Normal", "Poisson"]}
  defp get_template(m = "trello", _), do: {:dll, m, ["CreateCard", "DeleteCard"]}
  defp get_template(m = "twiliovid", _), do: {:dll, m, ["CreateRoom", "GetRoom", "CompleteRoom"]}
  defp get_template(m = "zendesk", _), do: {:dll, m, ["GetUsers", "CreateTicket", "SoftDeleteTicket", "PermanentlyDeleteTicket"]}
  defp get_template(m = "zoom", _), do: {:dll, m, ["GetUsers"]}
  defp get_template(m = "newrelic", _), do: {:dll, m, ["SubmitEvent", "CheckEvent"]}
  defp get_template(m = "gke", _), do: {:dll, m, [{"CreateDeployment", 900}, {"RemoveDeployment", 900}]}

  defp get_template(unknown, account) do
    Logger.warn("Template requested for unknown logical monitor name #{unknown} and account #{account}, returning empty set")
    []
  end
 end
