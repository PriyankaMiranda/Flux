# Flux: Quick Reference Guide

## The New Architecture (Worker-Based DAG)

Flux uses **declarative workers** defined in `config/workers.yaml`. Each worker does one job and connects via pub/sub.

## Your S&P + News Example

```yaml
workers:
  # ┌─ SOURCES
  source_stocks:
    type: source
    adapter: alphavantage
    config:
      symbols: [AAPL, MSFT, GOOGL, ...]  # Top 20
      interval: 60s
    outputs: [stock_data]
  
  source_news:
    type: source
    adapter: newsapi
    config:
      keywords: [market, stocks, earnings]
      interval: 30s
    outputs: [news_data]
  
  # ┌─ PERSIST RAW
  save_raw_stocks:
    type: transcriber
    inputs: [stock_data]
    config:
      table: stocks_raw
    outputs: [stock_data_saved]
  
  save_raw_news:
    type: transcriber
    inputs: [news_data]
    config:
      table: news_raw
    outputs: [news_data_saved]
  
  # ┌─ AGGREGATE (join with time-matching)
  agg_stocks_news:
    type: aggregation
    inputs: [stock_data_saved, news_data_saved]
    config:
      time_window_ms: 60000      # Join within 60s
      downsample_factor: 2       # Skip every 2nd to reduce volume
    outputs: [aggregated_data]
  
  # ┌─ PERSIST AGGREGATED
  save_aggregated:
    type: transcriber
    inputs: [aggregated_data]
    config:
      table: stocks_news_aggregated
    outputs: [aggregated_data_saved]
  
  # ┌─ ANALYZE
  algorithm_sentiment_technical:
    type: algorithm
    inputs: [aggregated_data_saved]
    config:
      algorithm_module: Flux.Algorithms.SentimentTechnical
      cache_window: 100
    outputs: [analysis_results]
  
  # ┌─ SAVE RESULTS
  save_results:
    type: transcriber
    inputs: [analysis_results]
    config:
      table: analysis_results
```

## Worker Types

| Type | Input | Output | Job | Example |
|------|-------|--------|-----|---------|
| **source** | None | Stream | Fetch external data | Get stock prices from API |
| **transcriber** | Stream | Same stream | Save to DB, pass through | Persist raw data |
| **aggregation** | 2+ streams | 1 stream | Join data with time-matching | Combine stocks + news |
| **algorithm** | Stream | Stream | Process through analysis | Run sentiment + technical analysis |

## Data Flow (Your Pipeline)

```
Every 60s: source_stocks fetches AAPL, MSFT, GOOGL...
  ↓ Publishes to: stock_data
  ↓
save_raw_stocks subscribes, saves to DB, republishes to: stock_data_saved
  ↓
agg_stocks_news buffers this data

Every 30s: source_news fetches news articles
  ↓ Publishes to: news_data
  ↓
save_raw_news subscribes, saves to DB, republishes to: news_data_saved
  ↓
agg_stocks_news now has both! Joins by time within 60s window, publishes to: aggregated_data
  ↓
save_aggregated subscribes, saves to DB, republishes to: aggregated_data_saved
  ↓
algorithm_sentiment_technical subscribes, analyzes (combines sentiment + price movement), publishes to: analysis_results
  ↓
save_results subscribes, saves final results to DB
```

## Getting Started

### 1. Install
```bash
cd elixir
mix deps.get
```

### 2. Configure
```bash
cp .env.example .env
# Edit .env: set ALPHAVANTAGE_KEY and NEWSAPI_KEY
```

### 3. Set Up Database
```bash
# Option A: Docker
docker run -d -p 5432:5432 \
  -e POSTGRES_PASSWORD=password \
  timescale/timescaledb:latest-pg14

# Option B: Local PostgreSQL + TimescaleDB extension
psql -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
```

### 4. Run
```bash
iex -S mix run
```

You should see:
```
[info] Started worker: source_stocks
[info] Started worker: source_news
[info] Started worker: save_raw_stocks
[info] Started worker: save_raw_news
[info] Started worker: agg_stocks_news
[info] Started worker: save_aggregated
[info] Started worker: algorithm_sentiment_technical
[info] Started worker: save_results
```

Data will automatically flow through the pipeline!

## Adding Another Algorithm

The framework calls your algorithm with aggregated data. Example:

```elixir
# elixir/lib/flux/algorithms/my_custom_algo.ex
defmodule Flux.Algorithms.MyCustom do
  def analyze(data_points) do
    # data_points = [
    #   %{
    #     stock_data_saved: %{symbol: "AAPL", price: 150.25, ...},
    #     news_data_saved: %{headline: "...", sentiment: :positive, ...},
    #     timestamp: 1234567890
    #   },
    #   ...
    # ]
    
    result = data_points
      |> extract_signals()
      |> calculate_confidence()
    
    {:ok, result}
  end
  
  defp extract_signals(data) do
    # Your logic here
  end
  
  defp calculate_confidence(signals) do
    # Your logic here
  end
end
```

Then add to `config/workers.yaml`:
```yaml
my_algorithm:
  type: algorithm
  inputs: [aggregated_data_saved]
  config:
    algorithm_module: Flux.Algorithms.MyCustom
  outputs: [my_results]

save_my_results:
  type: transcriber
  inputs: [my_results]
  config:
    table: my_analysis_results
```

Done! Your algorithm automatically gets called and results saved.

## Adding Another Data Source

1. Create source (or use existing adapter):
```yaml
source_crypto:
  type: source
  adapter: binance  # or create custom
  config:
    symbols: [BTC, ETH]
    interval: 30s
  outputs: [crypto_data]
```

2. Add transcriber to save it:
```yaml
save_raw_crypto:
  type: transcriber
  inputs: [crypto_data]
  config:
    table: crypto_raw
  outputs: [crypto_data_saved]
```

3. Add to aggregation (optional):
```yaml
agg_stocks_crypto:
  type: aggregation
  inputs: [stock_data_saved, crypto_data_saved]
  config:
    time_window_ms: 60000
  outputs: [stocks_crypto_agg]
```

That's it! System auto-orchestrates.

## Key Concepts

### Streams
Named channels connecting workers. Think of them as queues:
- `stock_data` - raw stock prices
- `stock_data_saved` - stock prices after saving to DB
- `aggregated_data` - combined stocks + news

### Time-Matching
When you join streams in aggregation worker, it waits for data from both inputs within a time window:
```
stock at 10:00:00
news at 10:00:15  ← within 60s window, so they join
combined result published
```

### Downsampling
Skip samples to reduce data volume:
```
downsample_factor: 2  means: take 1st, skip 2nd, take 3rd, skip 4th...
```

### Caching in Algorithms
Algorithms keep last N data points:
```yaml
algorithm:
  config:
    cache_window: 100  # Keep last 100 points
```

This lets you do moving averages, momentum calculations, etc.

## File Locations

| Path | Purpose |
|------|---------|
| `config/workers.yaml` | Worker definitions (edit this!) |
| `.env` | API keys, database URL |
| `elixir/lib/flux/workers/` | Worker types |
| `elixir/lib/flux/algorithms/` | Your algorithms |
| `elixir/lib/flux/database.ex` | DB integration |
| `elixir/lib/flux/pubsub.ex` | Pub/Sub routing |

## Common Tasks

### Check Database
```bash
psql -d flux
SELECT * FROM stocks_raw LIMIT 5;
SELECT * FROM analysis_results LIMIT 5;
```

### View Worker Logs
```bash
iex -S mix run  # All logs shown in console
```

### Restart After Config Change
```bash
Ctrl+C to stop
# Edit config/workers.yaml
iex -S mix run  # Reload
```

### Add Custom Worker Type
1. Create `elixir/lib/flux/workers/my_worker.ex`
2. Implement `Flux.Worker` behavior
3. Register in `worker_graph.ex`
4. Use `type: my_type` in config

### Call Rust from Algorithm
```elixir
# In your algorithm
Flux.Native.my_calculation(prices, data)
```

## Production Checklist

- [ ] Set real API keys in `.env`
- [ ] Configure `DATABASE_URL` for production Postgres
- [ ] Set `REDIS_URL` for production Redis
- [ ] Configure database retention policies
- [ ] Set up monitoring (Prometheus metrics)
- [ ] Enable logging to file/ELK
- [ ] Set appropriate buffer sizes
- [ ] Test with production data volume
- [ ] Set up backup strategy
- [ ] Deploy with Docker or Kubernetes

## Example Queries

```sql
-- Get latest stock prices
SELECT symbol, price, timestamp FROM stocks_raw 
WHERE timestamp > now() - INTERVAL '1 hour'
ORDER BY timestamp DESC;

-- Get analysis signals
SELECT * FROM analysis_results
WHERE signal IN ('buy', 'sell')
ORDER BY timestamp DESC;

-- Average sentiment over time
SELECT 
  time_bucket('1 hour', timestamp) as hour,
  AVG(CAST(sentiment AS numeric)) as avg_sentiment
FROM news_raw
GROUP BY hour
ORDER BY hour DESC;
```

## What Makes This Special

Traditional: Write code to wire everything
```
if stock_data arrives:
  save_to_db(stock_data)
  if news_data also arrived:
    join them
    run algorithm
    save results
```

Flux: Declare once, system handles it
```yaml
source_stocks → save → 
source_news → save →
  aggregate → save → algorithm → save
```

Add a new source? Just add to YAML. System auto-routes data.

---

**Ready to go!** Start with `iex -S mix run` 🚀
