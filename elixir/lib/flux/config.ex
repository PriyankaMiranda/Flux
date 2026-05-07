defmodule Flux.Config do
  @moduledoc """
  Configuration for Flux framework
  """

  def get_env(key, default \\ nil) do
    System.get_env(key) || default
  end

  def stream_config do
    %{
      binance: %{
        enabled: true,
        symbol: get_env("BINANCE_SYMBOL", "BTCUSDT"),
        ws_url: get_env("BINANCE_WS_URL", "wss://stream.binance.com:9443/ws")
      },
      kraken: %{
        enabled: get_env("KRAKEN_ENABLED", "false") == "true",
        symbols: ["XBTUSD", "ETHUSD"]
      }
    }
  end

  def cache_config do
    %{
      ttl: String.to_integer(get_env("REDIS_CACHE_TTL", "3600")),
      max_size: 10_000
    }
  end

  def server_config do
    %{
      host: get_env("ELIXIR_HOST", "0.0.0.0") |> String.to_charlist(),
      port: get_env("ELIXIR_PORT", "4000") |> String.to_integer()
    }
  end
end
