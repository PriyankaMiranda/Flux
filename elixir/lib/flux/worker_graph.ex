defmodule Flux.WorkerGraph do
  @moduledoc """
  Loads worker configuration from YAML and builds the worker dependency graph.
  Starts workers in dependency order.
  """

  require Logger

  def load_config(config_path \\ "config/workers.yaml") do
    case YamlElixir.read_file(config_path) do
      {:ok, config} -> 
        Logger.info("Loaded worker config from #{config_path}")
        {:ok, config}
      {:error, reason} -> 
        Logger.error("Failed to load config: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def build_graph(config) do
    workers = config["workers"] || %{}
    
    # Topologically sort workers by dependencies
    graph = workers
      |> Enum.map(fn {id, worker_config} ->
        {id, worker_config, inputs(worker_config)}
      end)
      |> topological_sort()
    
    Logger.info("Worker graph built with #{length(graph)} workers")
    {:ok, graph}
  end

  def start_workers(graph, supervisor_pid) do
    Enum.each(graph, fn {id, config, _} ->
      if config["enabled"] != false do
        worker_module = worker_module(config["type"])
        
        config_map = %{
          id: id,
          type: String.to_atom(config["type"]),
          config: config["config"] || %{},
          inputs: config["inputs"] || [],
          outputs: config["outputs"] || []
        }
        
        case DynamicSupervisor.start_child(supervisor_pid, {worker_module, config_map}) do
          {:ok, pid} ->
            Logger.info("Started worker: #{id} (PID: #{inspect(pid)})")
          {:error, reason} ->
            Logger.error("Failed to start worker #{id}: #{inspect(reason)}")
        end
      end
    end)
    
    {:ok, length(graph)}
  end

  defp inputs(worker_config) do
    worker_config["inputs"] || []
  end

  defp topological_sort(workers) do
    # Simple topological sort for DAG
    # In production, use a proper algorithm for cycle detection
    sorted = []
    visited = MapSet.new()
    
    Enum.reduce(workers, {sorted, visited}, fn {id, config, inputs}, {sorted, visited} ->
      if MapSet.member?(visited, id) do
        {sorted, visited}
      else
        # Add dependencies first
        {new_sorted, new_visited} = add_dependencies(workers, inputs, sorted, visited)
        {new_sorted ++ [{id, config, inputs}], MapSet.put(new_visited, id)}
      end
    end)
    |> elem(0)
  end

  defp add_dependencies(workers, inputs, sorted, visited) do
    Enum.reduce(inputs, {sorted, visited}, fn input, {acc_sorted, acc_visited} ->
      # Find worker that outputs this stream
      case find_worker_by_output(workers, input) do
        {id, config, deps} ->
          if MapSet.member?(acc_visited, id) do
            {acc_sorted, acc_visited}
          else
            {new_sorted, new_visited} = add_dependencies(workers, deps, acc_sorted, acc_visited)
            {new_sorted ++ [{id, config, deps}], MapSet.put(new_visited, id)}
          end
        nil ->
          {acc_sorted, acc_visited}
      end
    end)
  end

  defp find_worker_by_output(workers, output_stream) do
    Enum.find(workers, fn {_id, config, inputs} ->
      outputs = config["outputs"] || []
      Enum.member?(outputs, output_stream)
    end)
  end

  defp worker_module(worker_type) do
    case String.downcase(worker_type) do
      "source" -> Flux.Workers.SourceWorker
      "transcriber" -> Flux.Workers.TranscriberWorker
      "aggregation" -> Flux.Workers.AggregationWorker
      "algorithm" -> Flux.Workers.AlgorithmWorker
      _ -> raise "Unknown worker type: #{worker_type}"
    end
  end
end
