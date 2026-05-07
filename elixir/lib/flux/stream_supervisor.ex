defmodule Flux.StreamSupervisor do
  use Supervisor
  require Logger

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Flux.Streams.CryptoStream, []}
    ]

    Logger.info("Starting stream supervisor")
    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_stream(module, opts) do
    Supervisor.start_child(__MODULE__, {module, opts})
  end
end
