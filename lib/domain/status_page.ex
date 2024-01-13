defmodule Domain.StatusPage do
  use TypedStruct
  alias Domain.Helpers
  require Logger

  typedstruct module: Subscription do
    @derive Jason.Encoder
    field :id, String.t()
    field :account_id, String.t()
    field :component_id, String.t()
  end

  @type component_name() :: String.t()
  @type instance() :: String.t()
  @type component_id() :: String.t()

  @type component_key() :: {component_name(), instance(), component_id()}
  @type component_map() :: %{required(component_key()) => [String.t() | NaiveDateTime.t()]}
  @type scraped_components_map() :: %{required(component_id()) => String.t()}

  typedstruct do
    field :id, String.t()
    field :components, component_map(), default: %{}
    field :scraped_components, scraped_components_map(), default: %{}
    field :subscriptions, [Domain.StatusPage.Subscription.t()], default: []
    field :x_val, any()
  end

  alias Backend.Projections.Dbpa.Snapshot
  alias Commanded.Aggregate.Multi
  alias __MODULE__.Commands
  alias __MODULE__.Events

  # Copied from Domain.Monitor. Needed for snapshotting since the tuple
  # component keys don't serialize
  defimpl Jason.Encoder do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          "x_val" => Base.encode64(:erlang.term_to_binary(value))
        },
        opts
      )
    end
  end

  defimpl Commanded.Serialization.JsonDecoder do
    def decode(value) do
      :erlang.binary_to_term(Base.decode64!(value.x_val))
    end
  end

  # Command handling

  def execute(%__MODULE__{id: nil}, c = %Commands.Create{}) do
    %Events.Created{id: c.id, page: c.page}
  end

  def execute(_status_page, %Commands.Create{}) do
    # Ignore duplicate registrations
    nil
  end

  def execute(%__MODULE__{id: nil}, c) do
    Logger.error("Invalid command on status page that has not seen a Create: #{inspect(c)}")
    {:error, :no_create_command_seen}
  end

  def execute(user, _ = %Commands.Print{}) do
    IO.inspect(user)
    nil
  end

  def execute(status_page, c = %Commands.Reset{}) do
    already_reset =
      status_page.components == %{} &&
      status_page.scraped_components == %{} &&
      status_page.subscriptions == []

    # issuing remove component events removes associated subscriptions via event_handler.ex
    if not already_reset do
      status_page
      |> Multi.new()
      |> Multi.execute(&(remove_components(&1, c.id)))
      |> Multi.execute(fn _ -> %Events.Reset{
        id: c.id
      } end)
    end
  end

  # set enabled subscriptions to components in c.component_ids
  def execute(status_page, c = %Commands.SetSubscriptions{}) do
    # get subscriptions to be added and ones to be removed
    account_subscriptions =
      status_page.subscriptions
      |> Enum.filter(&(&1.account_id == c.account_id))

    current_component_ids = Enum.map(account_subscriptions, fn sub -> sub.component_id end)

    add_to_subscriptions = Enum.reject(c.component_ids, fn component_id -> Enum.member?(current_component_ids, component_id) end)
    remove_from_subscriptions = Enum.reject(account_subscriptions, fn sub -> Enum.member?(c.component_ids, sub.component_id) end)

    multi = Multi.new(status_page)
    multi =
      add_to_subscriptions
        |> Enum.reduce(multi, fn component_id, acc ->
          acc |> Multi.execute(&add_subscription(&1, c.id, c.account_id, component_id))
        end)
    multi =
      remove_from_subscriptions
        |> Enum.reduce(multi, fn sub, acc ->
          acc |> Multi.execute(&remove_subscription(&1, c.id, c.account_id, sub.component_id, sub.id))
        end)
    multi
  end

  def execute(status_page, c = %Commands.AddSubscription{}) do
    if not Enum.any?(status_page.subscriptions, fn sps ->
      sps.account_id == c.account_id
      &&
      sps.component_id == c.component_id
    end) do
      %Events.SubscriptionAdded{
        id: c.id,
        subscription_id: Domain.Id.new(),
        account_id: c.account_id,
        component_id: c.component_id
      }
    end
  end

  def execute(status_page, c = %Commands.RemoveSubscription{}) do
    if Enum.any?(status_page.subscriptions, fn sps ->
      sps.id == c.subscription_id
    end) do
      %Events.SubscriptionRemoved{
        id: c.id,
        account_id: c.account_id,
        component_id: c.component_id,
        subscription_id: c.subscription_id
      }
    end
  end

  def execute(page, c = %Commands.ProcessObservations{}) do
    page
    |> Multi.new()
    |> Multi.execute(&maybe_component_status_changed_events(c, &1))
    |> Multi.execute(&maybe_reset_component_status_changed(c, &1))
    |> Multi.execute(&maybe_status_page_component_events(c, &1))
  end

  def execute(_page, c = %Commands.RemoveComponentChanges{}) do
    Enum.map(c.change_ids, fn change_id ->
      %Events.ComponentChangeRemoved{
        id: c.id,
        change_id: change_id
      }
    end)
  end

  def execute(_page, c = %Commands.Remove{}) do
      %Events.Removed{
        id: c.id
      }
  end

  def execute(page, c = %Commands.RemoveComponent{}) do
    page.scraped_components
    |> Enum.filter(fn {{name, _, _}, _} -> name == c.component_name end)
    |> Enum.map(fn {{name, instance, data_component_id}, component_id} ->
      %Events.ComponentRemoved{
        id: c.id,
        data_component_id: data_component_id,
        account_id: Domain.Helpers.shared_account_id(),
        instance: instance,
        name: name,
        component_id: component_id
      }
    end)
  end

  def apply(page, e = %Events.Created{}) do
    %__MODULE__{page | id: e.id}
  end

  def apply(page, _ = %Events.Removed{}) do
    page
  end

  def apply(page, e = %Events.ComponentAdded{}) do
    # by making the "practical assumption" that components will be uniquely named,
    # only add the associated id if the component name doesn't exist in our evented log
    # the caveat here is that if a vendor status page has a "bug" whereby a component has
    # a duplicate name we won't create the component to subscribe to
    %__MODULE__{page | scraped_components: Map.put_new(page.scraped_components, get_component_key(e), component_id_of(e))}
  end

  def apply(page, e = %Events.ComponentRemoved{}) do
    %__MODULE__{page | scraped_components: Map.delete(page.scraped_components, get_component_key(e)), components: Map.delete(page.components, get_component_key(e))}
  end

  def apply(page, e = %Events.ComponentStatusChanged{}) do
    %__MODULE__{
      page
      | components: Map.put(page.components, get_component_key(e), [e.status, e.changed_at, e.change_id])
    }
  end

  def apply(page, %Events.Reset{}) do
    %__MODULE__{page | components: %{}, scraped_components: %{}, subscriptions: []}
  end

  def apply(page, e = %Events.SubscriptionAdded{}) do
    %__MODULE__{
      page
      | subscriptions: [ %Subscription{ id: e.subscription_id, component_id: e.component_id, account_id: e.account_id } | page.subscriptions ]
    }
  end

  def apply(page, e = %Events.SubscriptionRemoved{}) do
    %__MODULE__{
      page
      | subscriptions: Enum.reject(page.subscriptions, fn sub -> sub.id == e.subscription_id end)
    }
  end

  def apply(page, %Events.ComponentChangeRemoved{}) do
    page
  end

  def component_id_of(e = %Events.ComponentAdded{}), do: Helpers.id_of(e, :component_id)
  def component_id_of(e = %Events.ComponentRemoved{}), do: Helpers.id_of(e, :component_id)
  def component_id_of(e = %Events.ComponentStatusChanged{}), do: Helpers.id_of(e, :component_id)

  # For a while, metrist was treating the "name" of a scraped page component as a "unique" key. Recently, it was discovered that statuspage.io status pages
  # will allow duplicate names for status page components. The only unique attribute for those in the scraped html is a data-component-id attribute.
  # So will use to build a "unique" component_id key for the associate events such as
  # ComponentAdded, ComponentRemoved, etc.
  # We have to be consistent with build_component_key below. If it takes Atom's and changes them to strings, component_id has to as well
  # as the scraped_components list is used for ComponentAdded/ComponentRemoved
  def build_component_id(%{instance: instance} = map) when is_atom(instance),
    do: build_component_id(Map.put(map, :instance, Atom.to_string(instance)))
  def build_component_id(%{name: component, instance: instance, data_component_id: data_component_id}),
    do: Enum.join([component, instance, data_component_id], "-") |> String.trim_trailing("-")

  defp maybe_component_status_changed_events(c, page) do
    Enum.map(c.observations, fn observation ->
      maybe_event = %Events.ComponentStatusChanged{
        id: page.id,
        data_component_id: fetch_component_property(observation, :data_component_id, ""),
        # This is an idempotency key to detect event replay, in essence. We need that
        # because the changes list is append-only so without it, we cannot detect duplicate
        # appends.
        change_id: Domain.Id.new(),
        component: observation.component,
        status: observation.status,
        state: observation.state,
        instance: observation.instance,
        changed_at: observation.changed_at,
        component_id: build_component_id(%{name: observation.component, instance: observation.instance, data_component_id: fetch_component_property(observation, :data_component_id, "")})
      }

      case Map.get(page.components, get_component_key(maybe_event)) do
        nil ->
          maybe_event

        [status, dt, _id] when observation.status != status ->
          # Potential race condition here if we send two events for the same page/component at
          # _exactly_ the same time. I don't see that happening.
          if NaiveDateTime.compare(observation.changed_at, dt) == :gt do
            maybe_event
          end

        _ ->
          nil
      end
    end)
    |> Enum.filter(fn e -> not is_nil(e) end)
  end

  # reset a "component status" back to up if it disappears from the html of a scraped page and is stuck in a "non-up" state
  # assumes it was scraped in an "up" status at some point in the past
  defp maybe_reset_component_status_changed(%{observations: observations}, %__MODULE__{
         id: page_id,
         components: components
       }) do
    observation_keys = Enum.map(observations, &get_component_key/1)

    components
    |> Enum.reject(fn {{_name_key, _region, _data_component_id} = key, [status, _dt, _id]} ->
      is_binary(key) or
        key in observation_keys or
        Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state(status) ==
          Snapshot.state_up()
    end)
    |> Enum.map(fn {{component, instance, data_component_id}, _status} ->
      %Events.ComponentStatusChanged{
        id: page_id,
        data_component_id: data_component_id,
        change_id: Domain.Id.new(),
        component: component,
        status: "up",
        state: Snapshot.state_up(),
        instance: instance,
        changed_at: NaiveDateTime.utc_now(),
        component_id: build_component_id(%{name: component, instance: instance, data_component_id: data_component_id})
      }
    end)
  end

  defp maybe_status_page_component_events(
         %{observations: observations},
         %__MODULE__{} = domain_status_page
       ) do
    latest_component_status_map =
      observations
      |> Enum.reduce(%{}, fn observation, acc ->
        # instance can be an atom like :global...
        Map.merge(acc, %{get_component_key(observation) => observation.status})
      end)

    # need to intersect / map these component keys to the scraped_components %{component_name/instance/optional data_component_id => unique_id} mapping to determine if I need to call Domain.Id.new
    latest_component_keys =
      latest_component_status_map
      |> Map.keys()
      |> MapSet.new()

    maybe_issue_add_component_event(latest_component_keys, domain_status_page) ++
      maybe_issue_remove_component_event(latest_component_keys, domain_status_page)
  end

  # a page component is added when it appears in the latest component name list and does not appear in the original component name list
  defp maybe_issue_add_component_event(latest_component_keys, %__MODULE__{
         id: page_id,
         scraped_components: scraped_components,
         components: components
       }) do
    original_component_keys = Map.keys(scraped_components) |> MapSet.new()

    change_id_by_key = Enum.into(components, %{}, fn {{_name_key, _region, _id_key} = key, [_status, _dt, id]} ->
      {key, id}
    end)

    latest_component_keys
    |> MapSet.difference(original_component_keys)
    |> Enum.map(fn {component, instance, data_component_id} = latest_component_key ->
      %Events.ComponentAdded{
        id: page_id,
        data_component_id: data_component_id,
        account_id: Domain.Helpers.shared_account_id(),
        change_id: change_id_by_key[latest_component_key],
        instance: instance,
        name: component,
        component_id: build_component_id(%{name: component, instance: instance, data_component_id: data_component_id})
      }
    end)
  end

  # a page component is removed when it does not appear in the latest component name list but appears in the original component name list
  defp maybe_issue_remove_component_event(latest_component_keys, %__MODULE__{
         id: page_id,
         scraped_components: scraped_components
       }) do
    original_component_keys = Map.keys(scraped_components) |> MapSet.new()

    original_component_keys
    |> MapSet.difference(latest_component_keys)
    |> Enum.map(fn {component, instance, data_component_id} = _original_component_key ->
      %Events.ComponentRemoved{
        id: page_id,
        data_component_id: data_component_id,
        account_id: Domain.Helpers.shared_account_id(),
        instance: instance,
        name: component,
        component_id: build_component_id(%{name: component, instance: instance, data_component_id: data_component_id})
      }
    end)
  end

  # Need to specifically handle possible atom keys due to serialization changing them to strings
  defp get_component_key(change_event) when is_atom(change_event.instance),
    do: Map.put(change_event, :instance, Atom.to_string(change_event.instance)) |> build_component_key()

  defp get_component_key(change_event), do: build_component_key(change_event)

  # data_component_id could be a blank string since it's a concept only in the Atlassian status page scraper
  defp build_component_key(%Events.ComponentStatusChanged{component: component, instance: instance, data_component_id: data_component_id}), do: {component, instance, data_component_id}
  defp build_component_key(%Events.ComponentAdded{name: component, instance: instance, data_component_id: data_component_id}), do: {component, instance, data_component_id}
  defp build_component_key(%Events.ComponentRemoved{name: component, instance: instance, data_component_id: data_component_id}), do: {component, instance, data_component_id}
  defp build_component_key(%Commands.Observation{component: component, instance: instance, data_component_id: data_component_id}), do: {component, instance, data_component_id}

  defp fetch_component_property(cmd_obs, property, default), do: Map.get(cmd_obs, property, default)

  defp remove_components(status_page, id) do
    Enum.map(status_page.scraped_components, fn {{name, instance, data_component_id}, component_id} ->
      %Events.ComponentRemoved{
        id: id,
        data_component_id: data_component_id,
        account_id: Domain.Helpers.shared_account_id(),
        instance: instance,
        name: name,
        component_id: component_id
      }
    end)
  end

  defp add_subscription(_status_page, id, account_id, component_id) do
    %Events.SubscriptionAdded{
      id: id,
      subscription_id: Domain.Id.new(),
      account_id: account_id,
      component_id: component_id
    }
  end
  defp remove_subscription(_status_page, id, account_id, component_id, subscription_id) do
    %Events.SubscriptionRemoved{
      id: id,
      subscription_id: subscription_id,
      account_id: account_id,
      component_id: component_id
    }
  end
end
