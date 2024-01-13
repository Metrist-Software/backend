defmodule Backend.Twitter.Supervisor do
  @moduledoc """
  Supervisor for Twitter search instances. It works a bit like the realtime analytics setup,
  in that it loads all data and uses Horde to enfore singletons cluster-wide and route requests.

  It's a bit more "stupid" than Horde in that it does not do state handoffs. It'll try to restart
  everything all the time because there's not a lot of data involved. That's also why it just incorporates
  the loading/starting functionality instead of having that in a separate module.
  """
  use Supervisor
  require Logger
  alias Domain.Monitor.Events.TwitterHashtagsSet


  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Backend.Twitter.DynamicSupervisor},
      {Task.Supervisor, name: Backend.Twitter.TaskSupervisor},
      {Task, fn ->
        Swarm.whereis_or_register_name(Backend.Twitter.Loader, __MODULE__, :load_children_and_watch_for_changes, [])
      end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def load_children_and_watch_for_changes() do
    Logger.info("Doing initial load for Twitter workers")
    Task.Supervisor.start_child(Backend.Twitter.TaskSupervisor, fn ->
      do_load_children_and_watch_for_changes()
      do_watch_loop()
    end)
  end

  def do_load_children_and_watch_for_changes() do
    for monitor_logical_name <- Backend.Projections.Dbpa.MonitorTwitterInfo.names() do
      start_children(monitor_logical_name)
    end

    # Subscribe for _all_ monitors so that we monitor changes in twitter keywords
    # for monitors that currently don't have them too. Duplicate subscriptions cause
    # duplicate events, so unsubscribe first.
    for monitor <- Backend.Projections.list_monitors("SHARED") do
      id =
        Backend.Projections.construct_monitor_root_aggregate_id(
          "SHARED",
          monitor.logical_name
        )
      topic = Backend.PubSub.topic_of("Monitor", id)
      Logger.debug("Subscribing to monitors updates as #{topic}")

      Backend.PubSub.unsubscribe(topic)
      Backend.PubSub.subscribe(topic)
    end
  end

  def do_watch_loop() do
    receive do
      %{event: %TwitterHashtagsSet{monitor_logical_name: monitor_logical_name}} ->
        restart_children(monitor_logical_name)
      msg ->
        Logger.debug("Ignoring unknown message #{inspect msg}")
    end

    do_watch_loop()
  end

  def restart_children(monitor_logical_name) do
    Logger.info("Restarting Twitter counters for #{monitor_logical_name}")
    info = Backend.Projections.Dbpa.MonitorTwitterInfo.get(monitor_logical_name)
    Swarm.multi_call({Backend.Twitter.Worker, monitor_logical_name}, {:maybe_stop, info.hashtags})
    start_children(monitor_logical_name, info.hashtags)
  end

  defp start_children(monitor_logical_name) do
    info = Backend.Projections.Dbpa.MonitorTwitterInfo.get(monitor_logical_name)
    start_children(monitor_logical_name, info.hashtags)
  end

  def start_children(monitor_logical_name, hashtags) do
    for hashtag <- hashtags,
      name = worker_name(monitor_logical_name, hashtag),
      Swarm.whereis_name(name) == :undefined
    do
      Logger.info("Starting Twitter counter for #{monitor_logical_name}/##{hashtag}")
      {:ok, pid} = Swarm.register_name(name, __MODULE__, :do_start_children, [monitor_logical_name, hashtag])
      Swarm.join({Backend.Twitter.Worker, monitor_logical_name}, pid)
    end
  end

  def do_start_children(monitor_logical_name, hashtag) do
    DynamicSupervisor.start_child(
      Backend.Twitter.DynamicSupervisor,
      %{
        id: "Backend.Twitter.Worker_#{monitor_logical_name}_#{hashtag}",
        start: {Backend.Twitter.Worker, :start_link, [monitor_logical_name, hashtag]},
        restart: :transient
      }
    )
  end

  def worker_name(monitor_logical_name, hashtag, :via_tuple),
    do: {:via, :swarm, worker_name(monitor_logical_name, hashtag)}
  def worker_name(monitor_logical_name, hashtag),
    do: {Backend.Twitter.Worker, monitor_logical_name, hashtag}
end
