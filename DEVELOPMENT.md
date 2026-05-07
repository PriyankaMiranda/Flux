# Flux Development Guide

## System Architecture

```
External Data Providers (Binance, Kraken, etc.)
           ↓ WebSocket
    Elixir Orchestration (Port 4000)
    ├── StreamSupervisor (manages live streams)
    ├── DataStore (in-memory cache)
    └── WebSocketHandler (client connections)
           ↓ NIF Calls
    Rust Data Engine
    ├── calculate_indicators()
    ├── process_price_stream()
    └── Statistical processors
           ↓
    Redis Cache (Port 6379)
           ↓ Pub/Sub
    Python Strategy Engine
           ↓
    Trading Signals → Actions
```

## Development Workflow

### 1. Initial Setup

```bash
# Clone and navigate to project
cd /home/priya/Flux

# Install dependencies
cd elixir && mix deps.get && cd ..
cd rust && cargo build && cd ..
cd python && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt && cd ..
```

### 2. Running Components Individually

**Terminal 1 - Elixir Orchestrator**
```bash
cd elixir
iex -S mix run
# You should see: [info] Listening on 0.0.0.0:4000
```

**Terminal 2 - Redis**
```bash
redis-server
# Or if using Docker:
docker run -p 6379:6379 redis:7-alpine
```

**Terminal 3 - Python Strategies**
```bash
cd python
source venv/bin/activate
python strategies.py
```

### 3. Testing the System

**Terminal 4 - Test WebSocket Connection**
```bash
# Using wscat (install: npm install -g wscat)
wscat -c ws://localhost:4000

# Send subscription message:
{"action":"subscribe","exchange":"binance","symbol":"BTCUSDT"}

# Should receive trade data like:
{
  "exchange": "binance",
  "symbol": "BTCUSDT",
  "price": "42500.50",
  "quantity": "1.2345",
  "timestamp": 1715000000000,
  ...
}
```

## Key Files to Understand

### Elixir - Live Stream Ingestion
**File**: `elixir/lib/flux/streams/crypto_stream.ex`

This is where:
1. WebSocket connects to Binance
2. Raw trade data is received
3. Data is normalized to uniform format
4. Rust cruncher is called
5. Results are broadcast to subscribers

### Rust - Data Processing
**File**: `rust/src/lib.rs`

Two main functions:
- `calculate_indicators(price, quantity)`: Single trade processing
  - Momentum: `(price * quantity).sqrt()`
  - Volatility: `(price * 0.01).abs()`
  - Volume-weighted price: `price * quantity`

- `process_price_stream(prices)`: Historical analysis
  - Mean, standard deviation, min, max
  - Used for statistical analysis

### Python - Strategy Logic
**File**: `python/strategies.py`

Base `StrategyEngine` class that:
- Maintains price history (last 100)
- Calculates moving averages
- Generates buy/sell/hold signals

Derived strategies:
- `MomentumStrategy`: Rides price trends
- `MeanReversionStrategy`: Bets on price return to average

## Adding Features

### Add a New Data Source

**Step 1**: Create stream module
```elixir
# elixir/lib/flux/streams/my_stream.ex
defmodule Flux.Streams.MyStream do
  use GenServer
  
  @impl true
  def init(_) do
    {:ok, connect()}
  end
  
  # Implement handle_frame/2
end
```

**Step 2**: Register in supervisor
```elixir
# elixir/lib/flux/stream_supervisor.ex
children = [
  {Flux.Streams.CryptoStream, []},
  {Flux.Streams.MyStream, []}  # Add here
]
```

### Add a New Indicator in Rust

**Step 1**: Add function to `rust/src/lib.rs`
```rust
#[rustler::nif]
pub fn calculate_rsi(prices: Vec<f64>, period: usize) -> Result<f64, String> {
    // Your calculation here
    Ok(rsi_value)
}
```

**Step 2**: Rebuild Rust
```bash
cd rust
cargo build --release
```

**Step 3**: Call from Elixir
```elixir
Flux.Native.calculate_rsi(prices, 14)
```

### Add a New Strategy in Python

```python
class MyStrategy(StrategyEngine):
    def calculate_signal(self) -> str:
        if len(self.price_history) < 2:
            return "hold"
        
        # Your logic here
        return "buy" if should_buy else "sell" if should_sell else "hold"
```

## Debugging

### Enable Detailed Logging

**Elixir**:
```elixir
# In iex
Logger.configure(level: :debug)
```

**Rust**:
```bash
RUST_LOG=debug iex -S mix run
```

**Python**:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Monitor Data Flow

**Check Redis cache**:
```bash
redis-cli
> KEYS *
> GET "binance:BTCUSDT"
```

**Check Elixir GenServer state**:
```elixir
iex> :sys.get_state(Flux.DataStore)
```

## Production Deployment

### With Docker Compose

```bash
cd docker
docker-compose up --build -d
```

Check logs:
```bash
docker-compose logs -f flux_orchestrator
docker-compose logs -f flux_strategies
```

### Manual Deployment

1. Set `.env` with production values
2. Build Rust: `cd rust && cargo build --release`
3. Deploy Elixir: `MIX_ENV=prod mix ecto.migrate && mix phx.server`
4. Deploy Python: `gunicorn -w 4 strategies:app`
5. Monitor with: Prometheus + Grafana

## Performance Optimization

### Elixir
- Increase message queue limits in `config/config.exs`
- Use GenServer pooling for multiple streams
- Implement backpressure handling

### Rust
- Compile with `--release`
- Use rayon for parallel processing
- Profile with `perf` or `flamegraph`

### Python
- Use asyncio for concurrent strategy evaluation
- Implement batch processing for analysis

## Common Issues

### "Mix dependencies not found"
```bash
cd elixir
mix deps.get
mix compile
```

### "Rust compilation fails"
```bash
cd rust
cargo clean
cargo build
```

### "WebSocket connection refused"
- Ensure Elixir is running on port 4000
- Check firewall rules
- Verify network connectivity

### "Redis connection timeout"
```bash
# Check Redis is running
redis-cli ping
# Should respond with: PONG
```

## Next Steps

1. ✅ Understand architecture
2. ✅ Run components locally
3. ✅ Test WebSocket connection
4. ⏳ Add more data sources
5. ⏳ Implement custom strategies
6. ⏳ Build backtesting engine
7. ⏳ Deploy to production

## Resources

- **Elixir**: https://elixir-lang.org/
- **Rust**: https://www.rust-lang.org/
- **Rustler** (Elixir-Rust bridge): https://github.com/rusterlium/rustler
- **WebSocket**: https://websockets.spec.whatwg.org/
- **Binance API**: https://binance-docs.github.io/apidocs/

## Troubleshooting Commands

```bash
# Check all processes
lsof -i :4000      # Elixir port
lsof -i :6379      # Redis port

# Kill stuck processes
pkill -f "iex"
pkill redis-server

# View Elixir version
elixir --version

# View Rust version
rustc --version

# View Python version
python --version
```
