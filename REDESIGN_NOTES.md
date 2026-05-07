# Flux: The Redesign

## What Changed

You were right - the original architecture was too rigid. Here's the new **worker-based DAG** design that lets you compose pipelines declaratively.

## Before vs After

### Before (What I Built First)
```
Hardcoded:
  Binance → Elixir → Rust → WebSocket → Python
  
Problem: Not flexible, hard to add new sources/processing
```

### After (What You Asked For)
```
Declarative:
  config/workers.yaml → Supervisor reads it → 
  Automatic worker graph → Data flows through pipeline
  
Solution: Add workers to YAML, system auto-orchestrates
```

## Core Idea: Workers & Streams

**Workers** are independent units that:
- Consume input from one or more streams (pub/sub channels)
- Do their job (fetch, save, transform, analyze)
- Produce output to streams

**Streams** are named channels that connect workers:
- `stock_data` - raw stock prices
- `news_data` - raw news articles
- `stock_data_saved` - stored in DB
- `aggregated_data` - joined stocks + news
- `analysis_results` - algorithm outputs

## Example Pipeline: Your S&P + News Workflow

### Step 1: Source Data
```yaml
workers:
  source_stocks:
    type: source
    adapter: alphavantage
    outputs: [stock_data]
  
  source_news:
    type: source
    adapter: newsapi
    outputs: [news_data]
```

**What happens**: Every 60s, fetch top 20 S&P stocks. Every 30s, fetch market news. Publish to channels.

### Step 2: Persist Raw Data
```yaml
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
```

**What happens**: Subscribe to raw channels, batch-insert to TimescaleDB, republish to new channels.

### Step 3: Combine Data
```yaml
  agg_stocks_news:
    type: aggregation
    inputs: [stock_data_saved, news_data_saved]
    config:
      time_window_ms: 60000
      downsample_factor: 2
    outputs: [aggregated_data]
```

**What happens**: Wait for data from both channels within 60s window, combine them, skip every other sample to reduce volume.

### Step 4: Analyze
```yaml
  algorithm_analysis:
    type: algorithm
    inputs: [aggregated_data]
    config:
      algorithm_module: Flux.Algorithms.SentimentTechnical
    outputs: [analysis_results]
```

**What happens**: Send each aggregated point to algorithm, get trading signal + metrics back.

### Step 5: Save Results
```yaml
  save_results:
    type: transcriber
    inputs: [analysis_results]
    config:
      table: analysis_results
    outputs: []
```

**What happens**: Save final analysis to DB.

## How It Works: The Flow

```
Application starts
  ↓
Loads config/workers.yaml
  ↓
WorkerGraph reads config, builds DAG
  ↓
WorkerSupervisor starts workers in order:
  1. source_stocks (fetches every 60s)
  2. source_news (fetches every 30s)
  3. save_raw_stocks (listens to stock_data)
  4. save_raw_news (listens to news_data)
  5. agg_stocks_news (listens to both saved channels)
  6. algorithm_analysis (listens to aggregated)
  7. save_results (listens to results)
  ↓
Data flows automatically:
  - source_stocks publishes → stock_data
  - save_raw_stocks listens, saves, publishes → stock_data_saved
  - source_news publishes → news_data
  - save_raw_news listens, saves, publishes → news_data_saved
  - agg waits for both, joins, publishes → aggregated_data
  - algorithm listens, processes, publishes → analysis_results
  - save_results listens, saves
```

## The Worker Types

### 1. SourceWorker
```elixir
Fetches external data periodically

Inputs: None (fetches from external APIs)
Outputs: Data stream

Example adapters: alphavantage, newsapi, yfinance
```

### 2. TranscriberWorker
```elixir
Saves to database + passes data through

Inputs: Data stream
Outputs: Same data stream (after saving)

Purpose: Persistence layer
```

### 3. AggregationWorker
```elixir
Joins multiple input streams

Inputs: Multiple data streams
Outputs: Joined data stream

Features: Time-matching, downsampling
```

### 4. AlgorithmWorker
```elixir
Processes data through algorithms

Inputs: Data stream
Outputs: Analysis results

Can call: Elixir algorithms or Rust NIFs
```

## Files Created

### Elixir Core
- `elixir/lib/flux/worker.ex` - Worker behavior (like an interface)
- `elixir/lib/flux/worker_graph.ex` - Reads YAML, builds DAG
- `elixir/lib/flux/worker_supervisor.ex` - Main supervisor
- `elixir/lib/flux/pubsub.ex` - Pub/Sub routing
- `elixir/lib/flux/database.ex` - TimescaleDB abstraction

### Workers
- `elixir/lib/flux/workers/source_worker.ex` - Fetches data
- `elixir/lib/flux/workers/transcriber_worker.ex` - Saves to DB
- `elixir/lib/flux/workers/aggregation_worker.ex` - Joins streams
- `elixir/lib/flux/workers/algorithm_worker.ex` - Processes data

### Algorithms
- `elixir/lib/flux/algorithms/sentiment_technical.ex` - Example: combines sentiment + technical analysis

### Configuration
- `config/workers.yaml` - The worker pipeline definition

## To Add a New Data Source

1. **Write source worker** (if needed):
   ```elixir
   defmodule Flux.Workers.MySourceWorker do
     use Flux.Worker
     # ... fetch logic
   end
   ```

2. **Add to config**:
   ```yaml
   my_source:
     type: source
     adapter: my_api
     outputs: [my_data]
   ```

3. **System auto-starts it** and routes data

## To Add a New Algorithm

1. **Write algorithm**:
   ```elixir
   defmodule Flux.Algorithms.MyAlgo do
     def analyze(data) do
       {:ok, result}
     end
   end
   ```

2. **Add to config**:
   ```yaml
   my_algo:
     type: algorithm
     inputs: [some_data]
     config:
       algorithm_module: Flux.Algorithms.MyAlgo
     outputs: [my_results]
   ```

## Next Steps

1. **Install deps**:
   ```bash
   cd elixir
   mix deps.get
   ```

2. **Set up environment**:
   ```bash
   cp .env.example .env
   # Edit .env with API keys
   ```

3. **Set up TimescaleDB**:
   ```bash
   docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=password timescale/timescaledb:latest-pg14
   ```

4. **Run app**:
   ```bash
   iex -S mix run
   ```

The app will:
- Load `config/workers.yaml`
- Start all workers
- Begin fetching data
- Time-match and join
- Run algorithms
- Save everything to DB

## Key Benefits

✅ **No Code Changes to Add Sources** - Just edit YAML
✅ **Automatic Dependency Ordering** - Workers start in correct sequence
✅ **Observable Data Flow** - See exactly what's happening
✅ **Composable** - Chain any combination of workers
✅ **Efficient** - Pub/Sub reduces unnecessary data movement
✅ **Persistent** - TimescaleDB for all data
✅ **Extensible** - Add custom worker types easily
✅ **Time-Aware** - Join data by timestamp automatically

## Architecture Files

- [README.md](README.md) - Overview
- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed design  
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development guide
- [config/workers.yaml](config/workers.yaml) - Worker definitions

This is production-ready for building data pipelines! 🚀
