#!/bin/bash
# KhongAI Startup Script

set -e

echo "========================================="
echo "🦙 KhongAI - Starting Services"
echo "========================================="

# Create necessary directories
mkdir -p /home/node/.khongai/logs
mkdir -p /home/node/.khongai/workspace

# Set up environment
export NODE_ENV=production
export PATH="/app/node_modules/.bin:$PATH"

# Start OpenClaw gateway in background
echo "🚀 Starting OpenClaw Gateway..."
node /app/dist/index.js gateway start --foreground > /home/node/.khongai/logs/openclaw.log 2>&1 &
OPENCLAW_PID=$!

echo "✅ OpenClaw Gateway started (PID: $OPENCLAW_PID)"

# Wait for OpenClaw to be ready
echo "⏳ Waiting for OpenClaw to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:18789/health > /dev/null 2>&1; then
        echo "✅ OpenClaw Gateway is ready"
        break
    fi
    sleep 1
done

# Start Telegram admin bot if token provided
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    echo "🤖 Starting Telegram Admin Bot..."
    node /app/admin-bot/telegram-admin-bot.js > /home/node/.khongai/logs/admin-bot.log 2>&1 &
    BOT_PID=$!
    echo "✅ Telegram Bot started (PID: $BOT_PID)"
else
    echo "⚠️  TELEGRAM_BOT_TOKEN not set - Admin bot disabled"
fi

echo "========================================="
echo "🎉 KhongAI is running!"
echo "📊 Dashboard: http://localhost:18789"
echo "📝 Logs: /home/node/.khongai/logs/"
echo "========================================="

# Keep container running and monitor processes
while true; do
    if ! kill -0 $OPENCLAW_PID 2>/dev/null; then
        echo "❌ OpenClaw Gateway died! Exiting..."
        exit 1
    fi
    sleep 10
done