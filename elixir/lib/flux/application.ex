defmodule Flux.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Worker supervisor (loads config and manages all workers)
      {Flux.WorkerSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Flux.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Load workers from config
        :ok = Flux.WorkerSupervisor.load_and_start_workers()
        {:ok, pid}
      
      error ->
        error
    end
  end
end
