# Flux Worker-Based Data Pipeline Architecture

## System Overview

Flux is a **declarative worker-based DAG framework** for real-time financial data aggregation, processing, and analysis. Workers are configured in `config/workers.yaml` and form a data pipeline where each worker consumes input streams and produces output streams.

```
┌─────────────────────────────────────────────────────────┐
│                  External Data Sources                  │
│         (Binance, Kraken, NYSE, Forex APIs)             │
└────────────────────────┬────────────────────────────────┘
                         │ WebSocket Streams
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Elixir Orchestration Layer                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ StreamSupervisor (Live Data Ingestion)             │ │
│  │  ├── CryptoStream (Binance BTCUSDT)                │ │
│  │  ├── ForexStream (EURUSD)                          │ │
│  │  └── StockStream (NYSE Ticker)                     │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ DataStore (In-Memory Cache & Normalization)        │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ WebSocketHandler (Client Subscriptions)            │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
         │                          │                  │
         ├─ NIF Calls ─────────────►│                  │
         │                          ▼                  │
         │              ┌──────────────────────┐       │
         │              │  Rust Data Cruncher  │       │
         │              │                      │       │
         │              │ • Indicator Calc     │       │
         │              │ • Stream Processing  │       │
         │              │ • Statistical Calcs  │       │
         │              └──────────────────────┘       │
         │                          ▲                  │
         │                          │ JSON Results     │
         │                          │                  │
         └──────────────────────────┴──────────────────┘
                           │
                    ┌──────┴──────┐
                    ▼             ▼
         ┌─────────────────┐ ┌──────────────────┐
         │  Redis Cache    │ │ Python Strategy  │
         │  (Pub/Sub)      │ │ Engine           │
         └─────────────────┘ └──────────────────┘
                    ▲             ▲
                    │             │
                    └─────────────┘
                    Notifications
```

## Component Details

### 1. **Elixir Orchestration** (`/elixir`)
- **Purpose**: Central command center for data aggregation and client communication
- **Key Modules**:
  - `Application`: Entry point, starts all supervisors
  - `StreamSupervisor`: Manages all live data streams
  - `CryptoStream`: Example live WebSocket connection to Binance
  - `DataStore`: In-memory cache with pub/sub support
  - `WebSocketHandler`: Cowboy handler for client connections

**Live Stream Example**: 
- Connects to Binance WebSocket (`wss://stream.binance.com:9443/ws/btcusdt@trade`)
- Receives real-time trade data
- Normalizes to uniform format
- Stores in DataStore
- Sends to Rust for heavy computations
- Broadcasts results to subscribers

### 2. **Rust Data Crunching** (`/rust`)
- **Purpose**: High-performance numerical computations and data processing
- **Key Functions**:
  - `calculate_indicators`: Computes momentum, volatility, weighted prices
  - `process_price_stream`: Statistical analysis (mean, stddev, min, max)
  - Integrated with Elixir via Rustler NIF (Native Implemented Functions)

**Performance**: Runs at microsecond-level precision for calculations

### 3. **Python Strategies** (`/python`)
- **Purpose**: Algorithmic trading logic and strategy implementations
- **Example Strategies**:
  - `MomentumStrategy`: Buys on uptrend, sells on downtrend
  - `MeanReversionStrategy`: Buys oversold, sells overbought
  - Extensible base `StrategyEngine` class

### 4. **Docker Orchestration** (`/docker`)
- Multi-container setup for development and production
- Services:
  - `flux_orchestrator`: Elixir service (port 4000)
  - `redis`: Caching and pub/sub (port 6379)
  - `flux_strategies`: Python strategy engine

## Data Flow

1. **Ingestion**: External WebSocket → Elixir Stream
2. **Normalization**: Raw data → Uniform schema (exchange, symbol, price, quantity, timestamp)
3. **Computation**: Elixir → Rust (NIF calls for heavy calculations)
4. **Storage**: Result → Redis cache + in-memory DataStore
5. **Broadcasting**: Result → All subscribed WebSocket clients
6. **Analysis**: Python strategies consume normalized data for signals

## Adding a New Data Source

### Step 1: Create a new stream module
```elixir
defmodule Flux.Streams.ForexStream do
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Connect to your API
    {:ok, connect_to_stream()}
  end
end
```

### Step 2: Add to StreamSupervisor
```elixir
children = [
  {Flux.Streams.CryptoStream, []},
  {Flux.Streams.ForexStream, []}  # Add new stream
]
```

### Step 3: Data gets automatically:
- Normalized
- Cached
- Sent to Rust for processing
- Broadcast to clients

## Configuration

Create `.env` file in project root:
```
# .env
BINANCE_WS_URL=wss://stream.binance.com:9443/ws
REDIS_URL=redis://localhost:6379
RUST_LOG=debug
```

## Quick Start

### Development (with Docker)
```bash
cd docker
docker-compose up --build
```

### Manual Setup

**Elixir**:
```bash
cd elixir
mix deps.get
mix compile
iex -S mix
```

**Rust**:
```bash
cd rust
cargo build --release
```

**Python**:
```bash
cd python
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python strategies.py
```

## WebSocket Client Connection

Connect to orchestrator at `ws://localhost:4000`:

```javascript
const ws = new WebSocket('ws://localhost:4000');

ws.onopen = () => {
  ws.send(JSON.stringify({
    action: 'subscribe',
    exchange: 'binance',
    symbol: 'BTCUSDT'
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Trade update:', data);
};
```

## Performance Characteristics

- **Data Latency**: Sub-second (Elixir WebSocket + Rust processing)
- **Throughput**: Handles 1000+ trades/sec per stream
- **Memory**: Configurable cache with Redis overflow
- **Scalability**: Add streams horizontally, compute vertically (Rust)