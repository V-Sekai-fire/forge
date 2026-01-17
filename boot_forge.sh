#!/bin/bash
# Forge Distributed AI Platform - Boot Script
# Starts all Zenoh-powered services for the distributed AI system

set -e

echo "🏭 FORGE AI PLATFORM BOOT SEQUENCE"
echo "==================================="
echo ""

echo "Checking Zenoh router..."
if ! command -v zenohd &> /dev/null; then
    echo "❌ zenohd not found!"
    echo ""
    echo "📦 INSTALL ZENOHD FIRST:"
    echo "  • cargo install zenohd"
    echo "  • curl -L https://zenoh.io/download/#prebuilt -o zenohd.tar.gz; tar -xzf zenohd.tar.gz; sudo cp zenohd /usr/local/bin/"
    echo ""
    echo "Without zenohd, services cannot communicate!"
    exit 1
fi
echo "✅ zenohd available"

echo ""
echo "🌐 Starting Zenoh Router..."
cd zenoh-router
./zenoh_router start &
ROUTER_PID=$!
echo "Router started with PID: $ROUTER_PID"
cd ..

echo ""
echo "💻 Checking Universal AI Service (zimage)..."
cd zimage
if ! uv --version &> /dev/null; then
    echo "❌ uv not found! Install uv: uv-lang.github.io"
    echo "Manual: cd zimage && uv sync && uv run python inference_service.py"
    exit 1
fi
echo "✅ uv available"

echo "🚀 Starting Python AI Service (zimage)..."
uv run python inference_service.py &
ZIMAGE_PID=$!
echo "zimage started with PID: $ZIMAGE_PID"
cd ..

echo ""
echo "🎛️  Checking AI Client Dashboard..."
cd zimage-client
if ! mix --version &> /dev/null; then
    echo "❌ Elixir/Mix not found! Install Erlang OTP and Elixir"
    echo "Manual: cd zimage-client && mix deps.get && mix escript.build && ./zimage_client --dashboard"
    exit 1
fi
echo "✅ Elixir/Mix available"

echo "📊 Starting AI Client Dashboard..."
mix escript.build >/dev/null 2>&1
./zimage_client --dashboard &
CLIENT_DASHBOARD_PID=$!
echo "Dashboard started with PID: $CLIENT_DASHBOARD_PID"
cd ..

echo ""
echo "⏳ giving services time to boot..."
sleep 3

echo ""
echo "🔍 Checking system health..."
echo "Zenoh router status:"
./zenoh-router/zenoh_router status

echo ""
echo "🎨 Testing AI generation:"
cd zimage-client
echo "→ Generating test image..."
./zimage_client "a beautiful sunset" --width 512 --height 512 &
GENERATION_PID=$!
cd ..

echo ""
echo "✨ FORGE AI SYSTEM SUCCESSFULLY BOOTED!"
echo "======================================="
echo ""
echo "📁 Live Dashboard:          zimage-client dashboard"
echo "🎨 AI Generation:           zimage-client \"your prompt\""
echo "🎛️  Network Monitor:         zenoh-router status"
echo "💡 REST API Health:         curl http://localhost:7447/@config/status"
echo ""
echo "⚡ Press Ctrl+C to shut down all services"

# Wait for interrupt
trap cleanup SIGINT SIGTERM
cleanup() {
    echo ""
    echo "🛑 Shutting down Forge services..."
    kill $GENERATION_PID 2>/dev/null || true
    kill $CLIENT_DASHBOARD_PID 2>/dev/null || true
    kill $ZIMAGE_PID 2>/dev/null || true
    ./zenoh-router/zenoh_router stop 2>/dev/null || true
    kill $ROUTER_PID 2>/dev/null || true
    echo "✅ All services stopped"
    exit 0
}

echo "Ready for AI requests! 🎯"
echo ""

# Keep running to show status
while true; do
    sleep 10
    echo "🔄 System check (every 10s)..."
    if ! kill -0 $ROUTER_PID 2>/dev/null; then
        echo "⚠️  Router died - restarting..."
        kill $CLIENT_DASHBOARD_PID $ZIMAGE_PID 2>/dev/null || true
        exit 1
    fi
done
