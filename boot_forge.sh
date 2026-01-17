#!/bin/bash
# Forge Distributed AI Platform - Boot Script
# Starts all Zenoh-powered services for the distributed AI system

set -e

echo "🏭 FORGE AI PLATFORM BOOT SEQUENCE"
echo "==================================="
echo ""

echo "Checking Zenoh router..."
ZENOH_FOUND=false

# Check for full-featured zenohd (with REST bridge)
if [ -x /usr/local/bin/zenohd-full ]; then
    echo "✅ Full-featured zenohd found (with HTTP REST bridge)"
    echo "   Supports both curl/HTTP and Zenoh native protocols"
    ZENOH_FOUND=true
    ZENOH_MODE="full"
# Check for basic cargo zenohd
elif command -v zenohd &> /dev/null; then
    echo "✅ Basic zenohd found (cargo installed)"
    echo "   Supports Zenoh native protocol only"
    echo "   HTTP REST bridge requires full build from source"
    ZENOH_FOUND=true
    ZENOH_MODE="basic"
else
    echo "❌ Zenohd not found!"
    echo ""
    echo "📦 INSTALL ZENOHD FIRST (choose one):"
    echo ""
    echo "🔧 RECOMMENDED: Build with all features:"
    echo "   git clone https://github.com/eclipse-zenoh/zenoh.git"
    echo "   cd zenoh && cargo build --release --all-features"
    echo "   sudo cp target/release/zenohd /usr/local/bin/zenohd-full"
    echo ""
    echo "⚡ FAST: Basic install (no HTTP bridge):"
    echo "   cargo install zenohd"
    echo ""
    echo "Then set up systemd user service:"
    echo "   mkdir -p ~/.config/systemd/user"
    echo "   cp zenohd.service ~/.config/systemd/user/"
    echo "   systemctl --user daemon-reload && systemctl --user enable zenohd"
    echo ""
    echo "See: ZENOHD_SERVICE_SETUP.md for full instructions"
    echo ""
    exit 1
fi

# Check if systemd user service is set up
if ! systemctl --user list-unit-files | grep -q zenohd.service; then
    echo "⚠️  zenohd user service not set up!"
    echo ""
    echo "💡 SETUP SERVICE ALWAYS:"
    echo "  1. mkdir -p ~/.config/systemd/user"
    echo "  2. cp zenohd.service ~/.config/systemd/user/"
    echo "  3. systemctl --user daemon-reload"
    echo "  4. systemctl --user enable zenohd"
    echo ""
    echo "See: ZENOHD_SERVICE_SETUP.md"
    echo ""
    exit 1
fi

if [ "$ZENOH_MODE" = "full" ]; then
    echo "✅ Full zenohd with HTTP REST bridge ready"
    echo "   Use curl for simple HTTP API or zimage_client for optimal performance"
else
    echo "✅ Basic zenohd ready (Zenoh native only)"
    echo "   Use './zimage_client' commands - HTTP endpoints not available"
fi

echo ""
echo "🌐 Starting Zenoh Router (systemd user service)..."
systemctl --user start zenohd
if [ $? -eq 0 ]; then
    echo "Zenoh router service started successfully"
    if [ "$ZENOH_MODE" = "full" ]; then
        echo "REST API bridge enabled: http://localhost:7447/@config"
        echo "HTTP service endpoints at: http://localhost:7447/apis/"
    fi
elseif systemctl --user is-active --quiet zenohd; then
    echo "Zenoh router service was already running"
    if [ "$ZENOH_MODE" = "full" ]; then
        echo "REST API endpoints available at: http://localhost:7447/apis/"
    fi
else
    echo "❌ Failed to start zenohd service!"
    echo "Check logs: journalctl --user -u zenohd"
    exit 1
fi

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
systemctl --user status zenohd --no-pager
echo ""

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
echo "🎛️  Network Monitor:         systemctl --user status zenohd"
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
    systemctl --user stop zenohd 2>/dev/null || true
    echo "✅ All services stopped"
    exit 0
}

echo "Ready for AI requests! 🎯"
echo ""

# Keep running to show status - check systemd service status
while true; do
    sleep 10
    echo "🔄 System check (every 10s)..."
    if ! systemctl --user is-active --quiet zenohd; then
        echo "⚠️  Zenoh router service died!"
        read -t 10 -p "Restart router? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl --user restart zenohd
        fi
    fi

    # Check if zimage or dashboard have died
    if ! kill -0 $ZIMAGE_PID 2>/dev/null; then
        echo "⚠️  zimage AI service died!"
        cd zimage && uv run python inference_service.py &
        ZIMAGE_PID=$!
        cd ..
    fi

    if ! kill -0 $CLIENT_DASHBOARD_PID 2>/dev/null; then
        echo "⚠️  Dashboard died!"
        cd zimage-client && ./zimage_client --dashboard &
        CLIENT_DASHBOARD_PID=$!
        cd ..
    fi
done
