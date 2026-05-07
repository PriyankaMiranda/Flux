defmodule Flux.Algorithms.SentimentTechnical do
  @moduledoc """
  Example algorithm: Combines sentiment from news with technical analysis of stock prices.
  
  Uses last 100 aggregated (price + news) points to:
  1. Calculate technical indicators
  2. Analyze news sentiment trend
  3. Generate trading signal
  """

  require Logger

  def analyze(aggregated_data) when is_list(aggregated_data) do
    # aggregated_data contains stock price + news sentiment for each time point
    
    case length(aggregated_data) do
      n when n < 2 ->
        {:error, "Insufficient data"}
      
      _ ->
        # Extract prices and sentiments
        prices = extract_prices(aggregated_data)
        sentiments = extract_sentiments(aggregated_data)
        
        # Calculate indicators
        sma_20 = calculate_sma(prices, 20)
        sentiment_average = calculate_sentiment_score(sentiments)
        momentum = calculate_momentum(prices)
        
        # Generate signal
        signal = generate_signal(momentum, sentiment_average, prices)
        
        {:ok, %{
          signal: signal,
          momentum: momentum,
          sma_20: sma_20,
          sentiment_score: sentiment_average,
          price_current: List.first(prices),
          timestamp: System.os_time(:millisecond)
        }}
    end
  end

  defp extract_prices(data) do
    Enum.map(data, fn item ->
      case item do
        %{stock_data_saved: %{price: price}} -> price
        %{price: price} -> price
        _ -> 0
      end
    end)
  end

  defp extract_sentiments(data) do
    Enum.map(data, fn item ->
      case item do
        %{news_data_saved: %{sentiment: sentiment}} -> sentiment_to_score(sentiment)
        %{sentiment: sentiment} -> sentiment_to_score(sentiment)
        _ -> 0
      end
    end)
  end

  defp sentiment_to_score(sentiment) when is_atom(sentiment) do
    case sentiment do
      :positive -> 1.0
      :neutral -> 0.0
      :negative -> -1.0
      _ -> 0.0
    end
  end

  defp sentiment_to_score(sentiment) when is_binary(sentiment) do
    case String.downcase(sentiment) do
      "positive" -> 1.0
      "neutral" -> 0.0
      "negative" -> -1.0
      _ -> 0.0
    end
  end

  defp sentiment_to_score(_), do: 0.0

  defp calculate_sma(prices, period) when length(prices) >= period do
    prices
    |> Enum.take(period)
    |> Enum.sum()
    |> Kernel./(period)
  end

  defp calculate_sma(_, _), do: 0.0

  defp calculate_sentiment_average(sentiments) do
    case length(sentiments) do
      0 -> 0.0
      n -> Enum.sum(sentiments) / n
    end
  end

  defp calculate_sentiment_score(sentiments) do
    # Recent sentiment weighted more heavily
    sentiments
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {sentiment, index} ->
      weight = 1 + index * 0.1
      sentiment * weight
    end)
    |> Enum.sum()
    |> Kernel./(length(sentiments))
  end

  defp calculate_momentum(prices) when length(prices) >= 2 do
    current = List.first(prices)
    previous = Enum.at(prices, 1)
    (current - previous) / previous
  end

  defp calculate_momentum(_), do: 0.0

  defp generate_signal(momentum, sentiment, prices) when is_list(prices) and length(prices) >= 2 do
    current_price = List.first(prices)
    sma_20 = calculate_sma(prices, 20)
    
    cond do
      # Strong buy: price above SMA, positive momentum, positive sentiment
      current_price > sma_20 and momentum > 0.02 and sentiment > 0.5 ->
        "strong_buy"
      
      # Buy: price above SMA, positive momentum
      current_price > sma_20 and momentum > 0.01 ->
        "buy"
      
      # Strong sell: price below SMA, negative momentum, negative sentiment
      current_price < sma_20 and momentum < -0.02 and sentiment < -0.5 ->
        "strong_sell"
      
      # Sell: price below SMA, negative momentum
      current_price < sma_20 and momentum < -0.01 ->
        "sell"
      
      # Hold: everything else
      true ->
        "hold"
    end
  end

  defp generate_signal(_, _, _), do: "hold"
end
