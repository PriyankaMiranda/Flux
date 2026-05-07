# Flux - Worker-Based Data Pipeline Framework

## What's This?

Flux is a **declarative, worker-based DAG (Directed Acyclic Graph)** framework for building real-time financial data pipelines. 

Instead of writing code to connect components, you define workers in `config/workers.yaml` and the framework automatically:
- Loads your configuration
- Starts workers in dependency order
- Routes data between workers via pub/sub
- Handles persistence to TimescaleDB

## The Pipeline Concept

Define workers like building blocks:

```yaml
workers:
  source_stocks:        # Fetch top 20 S&P stocks
    type: source
    outputs: [stock_data]
  
  source_news:          # Fetch market news
    type: source
    outputs: [news_data]
  
  save_raw_stocks:      # Save to DB
    type: transcriber
    inputs: [stock_data]
  
  agg_stocks_news:      # Join by time
    type: aggregation
    inputs: [stock_data_saved, news_data_saved]
  
  algorithm_analysis:   # Analyze
    type: algorithm
    inputs: [aggregated_data]
```

Data flows automatically: sources → transcribers → aggregation → transcriber → algorithm → transcriber.

## Worker Types

| Type | Purpose | Example |
|------|---------|---------|
| **Source** | Fetch external data | Stock prices, news feeds |
| **Transcriber** | Save to DB + pass through | Persist data, validate |
| **Aggregation** | Join multiple streams | Time-match stocks + news |
| **Algorithm** | Process through Rust/Elixir | Technical analysis, sentiment |

## Example: Stock Sentiment Analysis

```
┌─────────────┐         ┌─────────────┐
│ S&P Stocks  │         │ Market News │
└──────┬──────┘         └──────┬──────┘
       │                       │
       ▼                       ▼
   [Save Raw]──────────────[Save Raw]
       │                       │
       └───────────┬───────────┘
                   ▼
            [Time-Matched Join]
                   │
                   ▼
              [Save Agg]
                   │
                   ▼
          [Sentiment Analysis]
                   │
                   ▼
           [Save Results]
```

## Core Features

✅ **Declarative Configuration** - Define pipelines in YAML
✅ **Automatic Orchestration** - Workers start in correct order
✅ **Pub/Sub Routing** - Efficient data flow between workers
✅ **Time-Matching** - Join streams with configurable windows
✅ **Downsampling** - Reduce data volume automatically
✅ **TimescaleDB** - Optimized time-series storage
✅ **Extensible** - Add custom workers and algorithms
✅ **Observable** - Full logging of data flow

## Quick Start

### 1. Install Dependencies
```bash
cd elixir
mix deps.get
```

### 2. Set Environment
```bash
export ALPHAVANTAGE_KEY=demo
export NEWSAPI_KEY=demo
export DATABASE_URL=postgres://localhost/flux
export REDIS_URL=redis://localhost:6379
```

### 3. Start Application
```bash
iex -S mix run
```

The app loads `config/workers.yaml`, builds the worker graph, and starts all workers.

### 4. View Data
```bash
# Check logs to see workers:
# [info] Started worker: source_stocks
# [info] Started worker: source_news
# [info] Started worker: agg_stocks_news
# ...
```

## Configuration File

See `config/workers.yaml` for the full example. Key concepts:

```yaml
workers:
  my_worker:
    type: source|transcriber|aggregation|algorithm
    enabled: true|false
    inputs: [input_streams]      # What this worker reads
    config:
      # Worker-specific config
    outputs: [output_streams]    # What this worker produces
```

## Directory Structure

```
Flux/
├── config/
│   └── workers.yaml                 # Worker definitions
├── elixir/lib/flux/
│   ├── application.ex               # Entry point
│   ├── worker.ex                    # Worker behavior
│   ├── worker_graph.ex              # Config loader & DAG builder
│   ├── worker_supervisor.ex         # Main supervisor
│   ├── pubsub.ex                    # Pub/Sub routing
│   ├── database.ex                  # TimescaleDB integration
│   ├── workers/
│   │   ├── source_worker.ex         # Fetches external data
│   │   ├── transcriber_worker.ex    # Saves to DB
│   │   ├── aggregation_worker.ex    # Joins streams
│   │   └── algorithm_worker.ex      # Processes data
│   └── algorithms/
│       └── sentiment_technical.ex   # Example algorithm
├── rust/
│   └── src/lib.rs                   # Rust algorithms (NIFs)
└── docker/
    └── docker-compose.yml
```

## Creating Custom Workers

### 1. Write worker module
```elixir
defmodule Flux.Workers.MyWorker do
  use Flux.Worker
  
  @impl Flux.Worker
  def worker_type, do: :my_type
  
  # ... implement handle_info for your logic
end
```

### 2. Register in worker_graph.ex
```elixir
defp worker_module("my_type"), do: Flux.Workers.MyWorker
```

### 3. Use in config
```yaml
my_worker:
  type: my_type
  inputs: [stream]
  config: {}
  outputs: [result_stream]
```

## Creating Custom Algorithms

```elixir
defmodule Flux.Algorithms.MyAnalysis do
  def analyze(data) do
    # Process data
    {:ok, result}
  end
end
```

Use in worker config:
```yaml
algorithm_worker:
  type: algorithm
  config:
    algorithm_module: Flux.Algorithms.MyAnalysis
```

## Data Persistence

Workers automatically save data to TimescaleDB hypertables:
- `stocks_raw` - Raw stock prices
- `news_raw` - Raw news articles
- `stocks_news_aggregated` - Time-matched aggregated data
- `analysis_results` - Algorithm outputs

## Performance

- **Latency**: ~100-500ms end-to-end (source → algorithm → save)
- **Throughput**: ~1000 events/sec per worker
- **Memory**: Configurable with cache windows
- **Storage**: TimescaleDB compression ~80% reduction

## What Makes This Different

**Traditional Approach:**
```
Code ← Manually orchestrate ← External data
```

**Flux Approach:**
```
Config File → Automatic orchestration → Data pipeline
```

Just define `config/workers.yaml` with your workers and connections. Flux handles everything else.

## Docs

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed design
- [DEVELOPMENT.md](DEVELOPMENT.md) - Dev guide
- [ROADMAP.md](ROADMAP.md) - Future plans

## License

MIT
