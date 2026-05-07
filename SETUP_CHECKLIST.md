# Flux Setup Checklist

## Phase 1: Installation ✅

- [x] Cloned/created Flux project
- [x] Created directory structure
- [x] Created configuration files
- [x] Created Elixir modules
- [x] Created worker implementations
- [x] Created example algorithm

## Phase 2: Before First Run

### Prerequisites
- [ ] Elixir 1.14+ installed: `elixir --version`
- [ ] Erlang/OTP installed: `erl -version`
- [ ] PostgreSQL with TimescaleDB available
- [ ] Redis available
- [ ] API keys available:
  - [ ] Alpha Vantage key (alphavantage.co)
  - [ ] NewsAPI key (newsapi.org)

### Setup
```bash
# Install dependencies
cd elixir
mix deps.get
mix compile

# Copy environment file
cd ..
cp .env.example .env

# Edit .env with your values
# - ALPHAVANTAGE_KEY=your_key
# - NEWSAPI_KEY=your_key
# - DATABASE_URL=postgres://...
# - REDIS_URL=redis://localhost:6379
```

### Verify Dependencies
```bash
# In elixir directory
iex
> :application.loaded_applications()
# Should show: phoenix_pubsub, yaml_elixir, rustler, etc.
```

## Phase 3: Database Setup

### Option A: Docker (Easiest)
```bash
# Start TimescaleDB
docker run -d \
  --name flux-db \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=password \
  timescale/timescaledb:latest-pg14

# Verify connection
psql -h localhost -U postgres -d postgres -c "SELECT version();"
```

### Option B: Local PostgreSQL + TimescaleDB
```bash
# Install TimescaleDB extension
psql -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"

# Create flux database
psql -c "CREATE DATABASE flux;"
```

### Create Tables
```bash
# The database.ex module creates these:
psql -d flux -c "
  CREATE TABLE stocks_raw (
    time TIMESTAMP NOT NULL,
    symbol TEXT NOT NULL,
    price NUMERIC NOT NULL,
    quantity NUMERIC NOT NULL
  );
  SELECT create_hypertable('stocks_raw', 'time', if_not_exists => TRUE);
  
  CREATE TABLE news_raw (
    time TIMESTAMP NOT NULL,
    headline TEXT NOT NULL,
    sentiment TEXT NOT NULL
  );
  SELECT create_hypertable('news_raw', 'time', if_not_exists => TRUE);
"
```

## Phase 4: Configuration

### Edit config/workers.yaml
- [ ] Review worker definitions
- [ ] Verify input/output streams match
- [ ] Check adapter names match your setup
- [ ] Set symbols list (stocks)
- [ ] Set API keywords (news)

### Verify .env
```bash
cat .env | grep -E "(ALPHAVANTAGE|NEWSAPI|DATABASE|REDIS)"
# Should show your configured values
```

## Phase 5: First Run

### Start Application
```bash
cd elixir
iex -S mix run
```

### Verify Startup
You should see:
```
[info] Initializing Flux Worker Supervisor
[info] Loaded worker config from config/workers.yaml
[info] Worker graph built with 8 workers
[info] Started worker: source_stocks
[info] Started worker: source_news
[info] Started worker: save_raw_stocks
[info] Started worker: save_raw_news
[info] Started worker: agg_stocks_news
[info] Started worker: save_aggregated
[info] Started worker: algorithm_sentiment_technical
[info] Started worker: save_results
```

### Monitor Data Flow
In another terminal:
```bash
# Watch database inserts
watch "psql -d flux -c 'SELECT COUNT(*) FROM stocks_raw;'"

# Or check tables directly
psql -d flux -c "SELECT COUNT(*) as stocks FROM stocks_raw;"
psql -d flux -c "SELECT COUNT(*) as news FROM news_raw;"
psql -d flux -c "SELECT COUNT(*) as aggregated FROM stocks_news_aggregated;"
psql -d flux -c "SELECT COUNT(*) as results FROM analysis_results;"
```

## Phase 6: Verify Data Pipeline

### Check Raw Data
```bash
psql -d flux -c "SELECT * FROM stocks_raw LIMIT 3;"
psql -d flux -c "SELECT * FROM news_raw LIMIT 3;"
```

### Check Aggregated Data
```bash
psql -d flux -c "SELECT * FROM stocks_news_aggregated LIMIT 3;"
```

### Check Analysis Results
```bash
psql -d flux -c "SELECT * FROM analysis_results LIMIT 3;"
```

### Expected Flow
```
✅ source_stocks fetches data every 60s
✅ source_news fetches data every 30s
✅ save_raw_* stores to DB
✅ agg joins them within 60s window
✅ algorithm analyzes
✅ save_results stores final output
```

## Phase 7: Troubleshooting

### Issue: "Cannot connect to database"
```bash
# Check connection string
echo $DATABASE_URL

# Test connection manually
psql $DATABASE_URL -c "SELECT 1;"

# Verify PostgreSQL is running
pg_isready -h localhost -p 5432
```

### Issue: "Workers not starting"
```bash
# Check YAML syntax
cd config && cat workers.yaml | head -20

# Verify file exists
ls -la config/workers.yaml

# Check Erlang logs
tail -f iex.log
```

### Issue: "API key not found"
```bash
# Verify .env is loaded
grep ALPHAVANTAGE_KEY .env
grep NEWSAPI_KEY .env

# Check values aren't empty
test -n "$ALPHAVANTAGE_KEY" && echo "Key set" || echo "Key missing"
```

### Issue: "No data flowing"
```bash
# Check logs show workers started
# Look for: "[info] Started worker: ..."

# Monitor one worker
psql -d flux -c "
  SELECT COUNT(*), MAX(time) FROM stocks_raw;
"

# If count not increasing, check:
# 1. API key is valid (get direct test)
# 2. Interval is not too long
# 3. No errors in logs
```

## Phase 8: Customization

### Add New Algorithm
- [ ] Create file: `elixir/lib/flux/algorithms/my_algo.ex`
- [ ] Implement `analyze/1` function
- [ ] Add to `config/workers.yaml`
- [ ] Restart app

### Add New Data Source
- [ ] Create source adapter (or use existing)
- [ ] Add worker to `config/workers.yaml`
- [ ] Add transcriber to save it
- [ ] Restart app

### Add Time-Matched Aggregation
- [ ] Add aggregation worker to config
- [ ] Set `time_window_ms` for join window
- [ ] Set `downsample_factor` if needed
- [ ] Restart app

## Phase 9: Production Readiness

- [ ] Database backups configured
- [ ] API rate limits understood
- [ ] Cache window sizes appropriate
- [ ] Retention policies set
- [ ] Monitoring/logging enabled
- [ ] Error handling tested
- [ ] Load tested with realistic data volume

## Phase 10: Monitoring

### Check System Health
```bash
iex> :observer.start()  # GUI monitoring

# Or check processes
iex> :erlang.processes() |> length()
```

### Database Monitoring
```sql
-- Size of hypertables
SELECT hypertable_name, pg_size_pretty(total_bytes) as size
FROM hypertable_detailed_size;

-- Recent data insertions
SELECT COUNT(*), MAX(time) FROM stocks_raw;
```

### Performance Metrics
```bash
# Latency: Check time between stock and aggregation
# Throughput: Watch records/second
# Memory: Monitor Erlang VM memory usage
```

## Common Commands

```bash
# Start application
iex -S mix run

# Stop application
Ctrl+C (twice)

# Connect to database
psql -d flux

# View logs
tail -f erl_crash.dump

# Recompile after changes
mix compile

# Check dependencies
mix deps.update --all

# Format code
mix format

# Run tests (when added)
mix test
```

## Success Criteria

- [ ] App starts without errors
- [ ] All workers show as started
- [ ] Data accumulates in database
- [ ] Stocks and news both being saved
- [ ] Aggregation is time-matching correctly
- [ ] Algorithm is running and producing results
- [ ] No error logs in console
- [ ] Database queries return data

## Next Steps After Setup

1. Monitor pipeline for 24 hours
2. Verify data quality and completeness
3. Adjust time windows if needed
4. Add more data sources
5. Create custom algorithms
6. Set up production monitoring
7. Deploy to server

---

**You're all set!** Follow this checklist step-by-step. 🚀
