defmodule Flux.Workers.AlgorithmWorker do
  @moduledoc """
  Algorithm worker processes data through Rust NIFs or Python algorithms.
  Caches data for windowed analysis (last N points).
  """

  use Flux.Worker
  require Logger

  @impl Flux.Worker
  def worker_type, do: :algorithm

  @impl GenServer
  def init(config) do
    {:ok, state} = super(config)
    
    # Subscribe to input streams
    Enum.each(config.inputs, fn stream ->
      Flux.PubSub.subscribe(stream)
    end)
    
    cache_window = config.config.cache_window || 100
    
    {:ok, Map.merge(state, %{
      cache: [],
      cache_window: cache_window
    })}
  end

  @impl GenServer
  def handle_info({Flux.PubSub, _stream, {:data, data}}, state) do
    config = state.config
    
    # Add to cache
    cache = [data | state.cache]
    cache = Enum.take(cache, state.cache_window)
    
    # Run algorithm
    case run_algorithm(config, cache) do
      {:ok, result} ->
        Logger.debug("#{config.id} algorithm result: #{inspect(result, limit: 2)}")
        
        # Publish results
        Enum.each(config.outputs, fn stream_name ->
          Flux.PubSub.publish(stream_name, {:data, result})
        end)
        
        {:noreply, %{state | cache: cache}}
      
      {:error, reason} ->
        Logger.error("#{config.id} algorithm failed: #{inspect(reason)}")
        {:noreply, %{state | cache: cache}}
    end
  end

  @impl GenServer
  def handle_cast({:message, _}, state), do: {:noreply, state}

  defp run_algorithm(config, cache) do
    algorithm = config.config.algorithm_module
    rust_nif = config.config.rust_nif
    
    # Example: Call Rust NIF if configured
    case rust_nif do
      nil ->
        # Call Elixir algorithm
        apply(String.to_atom("Elixir." <> algorithm), :analyze, [cache])
      
      nif ->
        # Call Rust via NIF
        try do
          result = Flux.Native.call_nif(nif, cache)
          {:ok, result}
        rescue
          e -> {:error, e}
        end
    end
  end
end
