defmodule Flux.Worker do
  @moduledoc """
  Behavior for Flux workers in the data pipeline.
  
  Each worker:
  - Has a type (source, aggregation, transcriber, algorithm)
  - Takes input from streams (channels)
  - Produces output to streams (channels)
  - Can be configured via workers.yaml
  """

  @type worker_type :: :source | :aggregation | :transcriber | :algorithm
  @type stream_name :: String.t()
  @type config :: map()
  @type message :: any()

  @callback worker_type() :: worker_type()
  @callback start_link(config()) :: {:ok, pid()} | {:error, any()}
  @callback handle_message(message(), config()) :: {:ok, message()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Flux.Worker
      use GenServer
      require Logger

      def start_link(config) do
        name = via_tuple(config.id)
        GenServer.start_link(__MODULE__, config, name: name)
      end

      def init(config) do
        Logger.info("Starting worker: #{config.id} (type: #{config.type})")
        {:ok, %{config: config, buffer: []}}
      end

      defp via_tuple(worker_id) do
        {:via, Registry, {Flux.WorkerRegistry, worker_id}}
      end

      def send_message(worker_id, message) do
        case Registry.lookup(Flux.WorkerRegistry, worker_id) do
          [{pid, _}] -> GenServer.cast(pid, {:message, message})
          [] -> {:error, :worker_not_found}
        end
      end
    end
  end
end
