defmodule Flux.Workers.TranscriberWorker do
  @moduledoc """
  Transcriber worker saves data to TimescaleDB.
  Batches writes for efficiency and passes data through to next worker.
  """

  use Flux.Worker
  require Logger

  @impl Flux.Worker
  def worker_type, do: :transcriber

  @impl GenServer
  def init(config) do
    {:ok, state} = super(config)
    
    # Subscribe to input streams
    Enum.each(config.inputs, fn stream ->
      Flux.PubSub.subscribe(stream)
    end)
    
    {:ok, Map.merge(state, %{messages: [], last_flush: now()})}
  end

  @impl GenServer
  def handle_info({Flux.PubSub, stream, {:data, data}}, state) do
    config = state.config
    batch_size = config.config.batch_size || 100
    
    # Add to buffer
    messages = state.messages ++ [data]
    
    # Check if we should flush
    should_flush = length(messages) >= batch_size or 
                   (now() - state.last_flush) > 5000  # Flush every 5 seconds
    
    if should_flush do
      case save_to_db(config, messages) do
        {:ok, saved_count} ->
          Logger.info("#{config.id} saved #{saved_count} records to #{config.config.table}")
          
          # Pass through to outputs
          Enum.each(config.outputs, fn stream_name ->
            Enum.each(messages, fn msg ->
              Flux.PubSub.publish(stream_name, {:data, msg})
            end)
          end)
          
          {:noreply, %{state | messages: [], last_flush: now()}}
        
        {:error, reason} ->
          Logger.error("#{config.id} DB save failed: #{inspect(reason)}")
          {:noreply, state}
      end
    else
      {:noreply, %{state | messages: messages}}
    end
  end

  @impl GenServer
  def handle_info(:flush, state) do
    if length(state.messages) > 0 do
      config = state.config
      
      case save_to_db(config, state.messages) do
        {:ok, saved_count} ->
          Logger.info("#{config.id} flushed #{saved_count} records")
          
          # Pass through
          Enum.each(config.outputs, fn stream_name ->
            Enum.each(state.messages, fn msg ->
              Flux.PubSub.publish(stream_name, {:data, msg})
            end)
          end)
          
          {:noreply, %{state | messages: [], last_flush: now()}}
        
        {:error, reason} ->
          Logger.error("#{config.id} flush failed: #{inspect(reason)}")
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:message, _}, state), do: {:noreply, state}

  defp save_to_db(config, messages) do
    table = config.config.table
    
    # TODO: Implement actual TimescaleDB insert
    # For now, simulate
    Logger.debug("Would save #{length(messages)} records to table: #{table}")
    {:ok, length(messages)}
  end

  defp now, do: System.os_time(:millisecond)
end
