#!/bin/bash
# Flux Project Setup Script

set -e

echo "🚀 Flux Framework Setup"
echo "======================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v elixir &> /dev/null; then
    echo "❌ Elixir not found. Install from: https://elixir-lang.org/install.html"
    exit 1
fi

if ! command -v rustc &> /dev/null; then
    echo "❌ Rust not found. Install from: https://rustup.rs/"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Install Python 3.11+"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites found${NC}"

# Setup Elixir
echo -e "${BLUE}Setting up Elixir...${NC}"
cd elixir
mix local.hex --force
mix local.rebar --force
mix deps.get
mix compile
echo -e "${GREEN}✓ Elixir setup complete${NC}"
cd ..

# Setup Rust
echo -e "${BLUE}Setting up Rust...${NC}"
cd rust
cargo build --release
echo -e "${GREEN}✓ Rust setup complete${NC}"
cd ..

# Setup Python
echo -e "${BLUE}Setting up Python...${NC}"
cd python
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
echo -e "${GREEN}✓ Python setup complete${NC}"
cd ..

# Copy env file
if [ ! -f .env ]; then
    echo -e "${BLUE}Creating .env file...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓ .env created (review and update as needed)${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Flux Framework Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "📚 Next Steps:"
echo "1. Review .env configuration"
echo "2. Read ARCHITECTURE.md for system overview"
echo "3. Read DEVELOPMENT.md for development guide"
echo ""
echo "🚀 Quick Start:"
echo "  Terminal 1: cd elixir && iex -S mix run"
echo "  Terminal 2: redis-server"
echo "  Terminal 3: cd python && source venv/bin/activate && python strategies.py"
echo ""
echo "Or use Docker: cd docker && docker-compose up --build"
echo ""
