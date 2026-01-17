#!/bin/bash
# Forge Distributed AI Platform - Boot Script
# Starts FlatBuffers/Zenoh native services only

echo "🏭 FORGE AI PLATFORM BOOT SEQUENCE"
echo "==================================="
echo ""

echo "Checking Zenoh router..."

# Check if systemd service is configured and running
if systemctl --user list-unit-files | grep -q zenohd.service; then
    echo "✅ Zenohd service configured"

    # Check if service is running
    if ! systemctl --user is-active --quiet zenohd; then
        echo "   Starting zenohd service..."
        systemctl --user start zenohd
    fi

    if systemctl --user is-active --quiet zenohd; then
        echo "✅ Zenohd service running"
    else
        echo "❌ Zenohd service failed to start"
        echo "   Check: systemctl --user status zenohd"
        exit 1
    fi

else
    echo "⚠️  Zenohd service not configured"
    echo "   Configure service first:"
    echo "   mkdir -p ~/.config/systemd/user"
    echo "   cp zenohd.service ~/.config/systemd/user/"
    echo "   systemctl --user daemon-reload && systemctl --user enable zenohd"
    echo ""
    echo "   Then restart this script."
    exit 1
fi

echo ""

# Start Python AI service (FlatBuffers/Zenoh native)
echo "🚀 Starting Python AI Service (zimage)..."
cd zimage
if ! uv --version &>/dev/null; then
    echo "❌ uv not found! Install from https://github.com/astral-sh/uv"
    exit 1
fi

# Start AI service in background
uv run python inference_service.py &
ZIMAGE_PID=$!
echo "✅ zimage started (PID: $ZIMAGE_PID)"
cd ..

echo ""
echo "⏳ Giving services time to initialize..."
sleep 2

echo ""
echo "🔍 System Status:"
echo "=================="
echo "Zenohd:     $(systemctl --user is-active zenohd)"
echo "AI Service: $(kill -0 $ZIMAGE_PID 2>/dev/null && echo "Running (PID: $ZIMAGE_PID)" || echo "Not responding")"
echo ""

echo "🎨 Forge is ready for FlatBuffers/Zenoh communication!"
echo "======================================================"
echo ""
echo "Generate AI images:"
echo "  ./zimage-client/zimage_client 'sunset mountains'"
echo ""
echo "Monitor system:"
echo "  ./zimage-client/zimage_client --dashboard"
echo "  systemctl --user status zenohd"
echo ""

# Trap for clean shutdown
trap cleanup INT TERM
cleanup() {
    echo ""
    echo "🛑 Shutting down..."
    kill $ZIMAGE_PID 2>/dev/null || true
    systemctl --user stop zenohd 2>/dev/null || true
    echo "✅ Shutdown complete"
    exit 0
}

echo "Services running - press Ctrl+C to exit"
echo ""

# Keep running for monitoring
while true; do
    sleep 10

    # Check if services are still running
    if ! systemctl --user is-active --quiet zenohd; then
        echo "⚠️  Zenohd service stopped"
        exit 1
    fi

    if ! kill -0 $ZIMAGE_PID 2>/dev/null; then
        echo "⚠️  AI service stopped"
        exit 1
    fi
done
