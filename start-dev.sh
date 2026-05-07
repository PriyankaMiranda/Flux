#!/bin/bash
# Flux Quick Start Script
# Runs all components for local development

echo "🚀 Starting Flux Framework"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down Flux Framework..."
    pkill -f "iex"
    pkill redis-server
    kill $PYTHON_PID 2>/dev/null
    wait
    echo "✅ Shutdown complete"
}

trap cleanup EXIT

# Check if Redis is running
if ! command -v redis-server &> /dev/null; then
    echo "⚠️  Redis not found. Install with: brew install redis"
    exit 1
fi

# Start Redis in background
echo "📊 Starting Redis..."
redis-server --port 6379 &
REDIS_PID=$!
sleep 2

# Start Elixir
echo "🎯 Starting Elixir Orchestrator..."
echo "   (Press Ctrl+C when done)"
echo ""

cd elixir
iex -S mix run &
ELIXIR_PID=$!

# Start Python strategies
echo ""
echo "🐍 Starting Python Strategy Engine..."
cd ../python
source venv/bin/activate 2>/dev/null || true
python strategies.py &
PYTHON_PID=$!

# Keep running
wait $ELIXIR_PID
