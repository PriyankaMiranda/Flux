defmodule Flux.Workers.SourceWorker do
  @moduledoc """
  Base source worker that fetches data from external APIs.
  Supports adapters: alphavantage, yfinance, newsapi, etc.
  """

  use Flux.Worker
  require Logger

  @impl Flux.Worker
  def worker_type, do: :source

  @impl GenServer
  def init(config) do
    {:ok, state} = super(config)
    
    # Schedule first fetch
    schedule_fetch(config)
    
    {:ok, Map.put(state, :next_fetch_time, now())}
  end

  @impl GenServer
  def handle_cast({:message, _}, state), do: {:noreply, state}

  @impl GenServer
  def handle_info(:fetch, state) do
    config = state.config
    
    case fetch_data(config) do
      {:ok, data} ->
        Logger.debug("#{config.id} fetched data: #{inspect(data, limit: 2)}")
        
        # Publish to output streams
        Enum.each(config.outputs, fn stream_name ->
          Flux.PubSub.publish(stream_name, {:data, data})
        end)

      {:error, reason} ->
        Logger.error("#{config.id} fetch failed: #{inspect(reason)}")
    end

    schedule_fetch(config)
    {:noreply, state}
  end

  defp schedule_fetch(config) do
    interval = parse_interval(config.config.interval)
    Process.send_after(self(), :fetch, interval)
  end

  defp fetch_data(config) do
    adapter = config.config.adapter || :alphavantage
    
    case adapter do
      :alphavantage -> fetch_alphavantage(config)
      :yfinance -> fetch_yfinance(config)
      :newsapi -> fetch_newsapi(config)
      _ -> {:error, "Unknown adapter: #{adapter}"}
    end
  end

  defp fetch_alphavantage(config) do
    symbols = config.config.symbols
    api_key = System.get_env(config.config.api_key || "ALPHAVANTAGE_KEY")
    
    case api_key do
      nil -> {:error, "ALPHAVANTAGE_KEY not set"}
      key ->
        # Simulate API call (replace with actual HTTP request)
        data = Enum.map(symbols, fn symbol ->
          %{
            symbol: symbol,
            price: 100 + :rand.uniform(50),
            timestamp: System.os_time(:millisecond)
          }
        end)
        {:ok, data}
    end
  end

  defp fetch_yfinance(config) do
    symbols = config.config.symbols
    
    # Simulate API call
    data = Enum.map(symbols, fn symbol ->
      %{
        symbol: symbol,
        price: 100 + :rand.uniform(50),
        timestamp: System.os_time(:millisecond)
      }
    end)
    {:ok, data}
  end

  defp fetch_newsapi(config) do
    api_key = System.get_env(config.config.api_key || "NEWSAPI_KEY")
    keywords = config.config.keywords
    
    case api_key do
      nil -> {:error, "NEWSAPI_KEY not set"}
      key ->
        # Simulate API call
        data = Enum.map(keywords, fn keyword ->
          %{
            headline: "News about #{keyword}",
            sentiment: Enum.random([:positive, :neutral, :negative]),
            timestamp: System.os_time(:millisecond),
            keyword: keyword
          }
        end)
        {:ok, data}
    end
  end

  defp parse_interval(interval_str) when is_binary(interval_str) do
    case String.split(interval_str, "s") do
      [num, ""] -> String.to_integer(num) * 1000
      _ -> 60_000  # Default 1 minute
    end
  end

  defp parse_interval(_), do: 60_000

  defp now, do: System.os_time(:millisecond)
end
