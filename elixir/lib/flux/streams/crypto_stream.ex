defmodule Flux.Streams.CryptoStream do
  use GenServer
  require Logger

  @exchange "binance"
  @symbol "BTCUSDT"
  @url "wss://stream.binance.com:9443/ws/btcusdt@trade"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Initializing crypto stream: #{@exchange}:#{@symbol}")
    {:ok, connect_to_stream()}
  end

  defp connect_to_stream() do
    case WebSockex.start_link(@url, __MODULE__, %{}) do
      {:ok, pid} ->
        Logger.info("Connected to Binance WebSocket")
        %{ws_pid: pid, exchange: @exchange, symbol: @symbol}
      
      {:error, reason} ->
        Logger.error("Failed to connect: #{inspect(reason)}")
        # Retry in 5 seconds
        Process.send_after(self(), :retry_connect, 5000)
        %{exchange: @exchange, symbol: @symbol}
    end
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    with {:ok, data} <- Jason.decode(msg) do
      # Extract relevant fields from Binance trade data
      normalized = normalize_trade(data, state.exchange, state.symbol)
      
      # Store the data
      Flux.DataStore.store(state.exchange, state.symbol, normalized)
      
      # Broadcast to subscribers
      broadcast_data(normalized)
      
      # Process with Rust cruncher for calculations
      process_with_rust(normalized)
    end

    {:ok, state}
  end

  @impl true
  def handle_cast(:disconnect, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:retry_connect, state) do
    {:noreply, connect_to_stream()}
  end

  defp normalize_trade(data, exchange, symbol) do
    %{
      "exchange" => exchange,
      "symbol" => symbol,
      "price" => data["p"],
      "quantity" => data["q"],
      "timestamp" => data["T"],
      "buyer_is_maker" => data["m"],
      "raw" => data
    }
  end

  defp broadcast_data(trade_data) do
    Phoenix.PubSub.broadcast(
      :"flux_pubsub",
      "trades:#{trade_data["exchange"]}:#{trade_data["symbol"]}",
      {:trade, trade_data}
    )
  end

  defp process_with_rust(trade_data) do
    # This will call Rust NIF for heavy computation
    case Flux.Native.calculate_indicators(
      String.to_float(trade_data["price"]),
      String.to_float(trade_data["quantity"])
    ) do
      {:ok, result} ->
        Logger.debug("Rust calculation result: #{inspect(result)}")
      
      {:error, reason} ->
        Logger.error("Rust calculation failed: #{inspect(reason)}")
    end
  end
end
