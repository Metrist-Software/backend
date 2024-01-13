defmodule Backend.Projections.Dbpa.MonitorTags do
  use Ecto.Schema
  import Ecto.Query

  alias Backend.Repo

  @monitor_tag_names [
    {"aws", "AWS"},
    {"azure", "Azure"},
    {"gcp", "Google Cloud Platform"},
    {"api", "API"},
    {"infrastructure", "Infrastructure"},
    {"saas", "SaaS"},
    {"other", "Other"}
  ]
  @monitor_tag_names_map Map.new(@monitor_tag_names)

  @primary_key false
  schema "monitor_tags" do
    field :monitor_logical_name, :string, primary_key: true
    field :tags, {:array, :string}
  end

  def tag_name(nil), do: "Other"
  def tag_name(tag), do: Map.get(@monitor_tag_names_map, tag, tag)

  def tag_names(), do: @monitor_tag_names

  def get_tags_for_monitor(monitor_id, account_id \\ nil) do
    query = from t in __MODULE__,
    where: t.monitor_logical_name == ^monitor_id

    query
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.one()
  end

  def list_monitors_by_tag(account_id \\ nil) do
    tags_query = from t in __MODULE__,
               select: %{monitor_logical_name: t.monitor_logical_name, tag: fragment("unnest(tags)")}

    query = from t in subquery(tags_query, prefix: Repo.schema_name(Domain.Helpers.shared_account_id())),
            right_join: m in Backend.Projections.Dbpa.Monitor,
            on: m.logical_name == t.monitor_logical_name,
            select: {t.tag, m.logical_name, m.name},
            order_by: [asc: t.tag, asc: m.name]

    query
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def get_monitor_logical_names_by_tags(tags, account_id \\ nil) do
    query = from t in __MODULE__,
            select: t.monitor_logical_name

    query
    |> filter_tags(tags)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def get_tag_names do
    Map.keys(@monitor_tag_names_map)
  end

  defp filter_tags(query, tag) when is_binary(tag) do
    from t in query,
      where: ^tag in t.tags
  end

  defp filter_tags(query, tags) when is_list(tags) do
    from t in query,
      where: fragment("? && ?", t.tags, ^tags)
  end
end
