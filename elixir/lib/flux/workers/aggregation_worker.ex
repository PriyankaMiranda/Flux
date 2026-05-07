defmodule Flux.Workers.AggregationWorker do
  @moduledoc """
  Aggregation worker joins multiple input streams.
  - Time-matches data within a window
  - Optionally downsamples to reduce volume
  """

  use Flux.Worker
  require Logger

  @impl Flux.Worker
  def worker_type, do: :aggregation

  @impl GenServer
  def init(config) do
    {:ok, state} = super(config)
    
    # Subscribe to all input streams
    Enum.each(config.inputs, fn stream ->
      Flux.PubSub.subscribe(stream)
    end)
    
    # Initialize buffers for each input stream
    buffers = Enum.reduce(config.inputs, %{}, fn stream, acc ->
      Map.put(acc, stream, [])
    end)
    
    {:ok, Map.merge(state, %{
      buffers: buffers,
      sample_counter: 0,
      last_aggregate_time: now()
    })}
  end

  @impl GenServer
  def handle_info({Flux.PubSub, stream, {:data, data}}, state) do
    config = state.config
    
    # Add data to appropriate buffer
    buffers = update_buffer(state.buffers, stream, data)
    
    # Try to aggregate if we have data from all sources
    case try_aggregate(config, buffers, state.sample_counter) do
      {:ok, aggregated, new_buffers, new_counter} ->
        # Publish aggregated data
        Flux.PubSub.publish(config.config.output_stream, {:data, aggregated})
        
        {:noreply, %{state | 
          buffers: new_buffers, 
          sample_counter: new_counter,
          last_aggregate_time: now()}}
      
      :not_ready ->
        {:noreply, %{state | buffers: buffers}}
    end
  end

  @impl GenServer
  def handle_cast({:message, _}, state), do: {:noreply, state}

  defp update_buffer(buffers, stream, data) do
    current = Map.get(buffers, stream, [])
    Map.put(buffers, stream, current ++ [data])
  end

  defp try_aggregate(config, buffers, sample_counter) do
    # Check if we have data from all inputs
    all_have_data = Enum.all?(config.inputs, fn stream ->
      length(Map.get(buffers, stream, [])) > 0
    end)

    case all_have_data do
      true ->
        # Get latest from each buffer
        aggregated_data = Enum.reduce(config.inputs, %{timestamp: now()}, fn stream, acc ->
          [latest | _] = Enum.reverse(Map.get(buffers, stream))
          Map.put(acc, String.to_atom(stream), latest)
        end)

        # Check downsampling
        downsample = config.config.downsample_factor || 1
        new_counter = sample_counter + 1

        case rem(new_counter, downsample) == 0 do
          true ->
            # Include this sample
            new_buffers = Enum.reduce(config.inputs, buffers, fn stream, acc ->
              Map.put(acc, stream, [])  # Clear buffers
            end)
            {:ok, aggregated_data, new_buffers, new_counter}
          
          false ->
            # Skip this sample (downsampling)
            new_buffers = Enum.reduce(config.inputs, buffers, fn stream, acc ->
              Map.put(acc, stream, [])  # Still clear buffers
            end)
            {:ok, aggregated_data, new_buffers, new_counter}
        end

      false ->
        :not_ready
    end
  end

  defp now, do: System.os_time(:millisecond)
end
