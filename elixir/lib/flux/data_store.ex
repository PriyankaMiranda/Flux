defmodule Flux.DataStore do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def store(exchange, symbol, data) do
    GenServer.cast(__MODULE__, {:store, exchange, symbol, data})
  end

  def get(exchange, symbol) do
    GenServer.call(__MODULE__, {:get, exchange, symbol})
  end

  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(__MODULE__, topic)
  end

  def broadcast(topic, message) do
    Phoenix.PubSub.broadcast(__MODULE__, topic, message)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:store, exchange, symbol, data}, state) do
    key = "#{exchange}:#{symbol}"
    new_state = Map.put(state, key, data)
    Logger.debug("Stored data: #{key}")
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get, exchange, symbol}, _from, state) do
    key = "#{exchange}:#{symbol}"
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end
end
