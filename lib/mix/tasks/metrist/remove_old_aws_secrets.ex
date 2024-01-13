defmodule Mix.Tasks.Metrist.RemoveOldAwsSecrets do

  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @shortdoc "Removes AWS secrets older than 3 months "

  @opts [
    :env,
    :dry_run,
  ]

  @moduledoc """
  #{Helpers.gen_command_line_docs(@opts)}

  """

  def run(args) do
   options = Helpers.parse_args(@opts, args)
   config = Helpers.config_from_env(options.env)
   Helpers.config_to_env(config)

   [:ex_aws_secretsmanager, :hackney, :jason]
   |> Enum.map(&Application.ensure_all_started/1)

   list_to_delete =
    list_all_secrets(config.region)
      |> Enum.filter(
            fn x -> last_access_date_eligible(Map.get(x,"LastAccessedDate")) end
          )
      |> Enum.filter(
            fn x -> not String.contains?(Map.get(x,"ARN"),"/manual")
          end)
      |> Enum.map(
          fn x-> Map.get(x,"ARN")
         end)

   if options.dry_run do
    Logger.info("DRY RUN: Not actually deleting #{length(list_to_delete)} secrets.")
    list_to_delete
      |> Enum.map(fn x ->
        Logger.info("Would delete: #{x}")
      end)
   else
    Logger.info("Deleting #{length(list_to_delete)} secrets.")
    list_to_delete
      |> Enum.map(fn x ->
        Logger.info("Deleting #{x}")
        ExAws.SecretsManager.delete_secret(x) |> ExAws.request(region: "us-west-1")
      end)
   end
  end

  defp list_all_secrets(region) do
    {:ok, map} =  ExAws.SecretsManager.list_secrets() |> ExAws.request(region: region)
    if Map.has_key?(map, "NextToken") do
      Map.get(map,"SecretList") ++  list_all_secrets(Map.get(map, "NextToken"), region)
    else
      Map.get(map,"SecretList") ++ list_all_secrets("done", region)
    end
  end

  defp list_all_secrets(nexttoken, _region) when nexttoken == "done" or is_nil(nexttoken) do
    []
  end

  defp list_all_secrets(nexttoken, region) do
    {:ok, map} =  ExAws.SecretsManager.list_secrets([next_token: nexttoken]) |> ExAws.request(region: region)
    Map.get(map, "SecretList") ++ list_all_secrets(Map.get(map,"NextToken"), region)
  end

  defp last_access_date_eligible(nil), do: true
  defp last_access_date_eligible(date) do
    three_months = NaiveDateTime.utc_now() |> Timex.shift(months: -3)

    naive_date =
      date
        |> round()
        |> DateTime.from_unix()
        |> Kernel.elem(1)
        |> DateTime.to_naive()

    NaiveDateTime.compare(naive_date, three_months) == :lt
  end
end
