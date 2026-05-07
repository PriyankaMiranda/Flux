defmodule Flux.WebSocketHandler do
  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  def websocket_init(state) do
    {:ok, state}
  end

  def websocket_handle({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"action" => "subscribe", "symbol" => symbol, "exchange" => exchange}} ->
        topic = "trades:#{exchange}:#{symbol}"
        Phoenix.PubSub.subscribe(:"flux_pubsub", topic)
        {:reply, {:text, Jason.encode!(%{"status" => "subscribed", "topic" => topic})}, state}

      {:ok, _} ->
        {:ok, state}

      {:error, _} ->
        {:reply, {:text, Jason.encode!(%{"error" => "Invalid JSON"})}, state}
    end
  end

  def websocket_info({:trade, trade_data}, state) do
    {:reply, {:text, Jason.encode!(trade_data)}, state}
  end

  def websocket_terminate(_reason, _state) do
    :ok
  end
end
