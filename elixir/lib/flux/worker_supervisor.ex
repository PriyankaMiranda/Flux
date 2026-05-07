defmodule Flux.WorkerSupervisor do
  @moduledoc """
  Main supervisor that loads config and manages all workers.
  """

  use Supervisor
  require Logger

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    Logger.info("Initializing Flux Worker Supervisor")

    children = [
      # PubSub adapter
      {Phoenix.PubSub, name: Flux.PubSub},
      
      # Worker registry
      {Registry, keys: :unique, name: Flux.WorkerRegistry},
      
      # Dynamic supervisor for workers
      {DynamicSupervisor, strategy: :one_for_one, name: Flux.WorkerDynamicSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  def load_and_start_workers(config_path \\ "config/workers.yaml") do
    with {:ok, config} <- Flux.WorkerGraph.load_config(config_path),
         {:ok, graph} <- Flux.WorkerGraph.build_graph(config),
         {:ok, count} <- Flux.WorkerGraph.start_workers(graph, Flux.WorkerDynamicSupervisor) do
      Logger.info("Started #{count} workers")
      {:ok, count}
    else
      {:error, reason} ->
        Logger.error("Failed to start workers: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
