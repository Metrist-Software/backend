defmodule Backend.Mnesia do
  use GenServer
  require Logger

  @hammer_table_name :__hammer_backend_mnesia

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    :ok = :net_kernel.monitor_nodes(true)
    :ok = connect_mnesia_to_cluster()

    {:ok, state}
  end

  def handle_info({:nodeup, node}, state) do
    Logger.info("Node connected: #{inspect node}")
    update_mnesia_nodes()

    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("Node disconnected: #{inspect node}")

    update_mnesia_nodes()

    {:noreply, state}
  end

  defp ensure_table_exists() do
    Hammer.Backend.Mnesia.create_mnesia_table(@hammer_table_name)
    |> case do
      {:atomic, :ok} ->
        :ok
      {:aborted, {:already_exists, @hammer_table_name}} ->
        :ok
    end

    :ok = :mnesia.wait_for_tables([@hammer_table_name], 5000)
  end

  defp connect_mnesia_to_cluster() do
    :ok = :mnesia.start()

    {:ok, nodes} = :mnesia.change_config(:extra_db_nodes, Node.list())
    Logger.info("Extra db nodes: #{inspect nodes}")

    :ok = ensure_table_exists()
    ensure_table_copies_exist()

    Logger.info("Successfully connected Mnesia to the cluster!")

    :ok
  end

  defp update_mnesia_nodes() do
    nodes = Node.list()
    Logger.info("Updating Mnesia nodes with #{inspect nodes}")
    :mnesia.change_config(:extra_db_nodes, nodes)
  end

  defp ensure_table_copies_exist() do
    Enum.map(Node.list(), fn node ->
      :mnesia.add_table_copy(@hammer_table_name, node, :ram_copies)
    end)
  end
end
