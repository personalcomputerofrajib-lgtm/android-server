#!/bin/bash
# =============================================
# FILE MANAGER PRO — ONE-CLICK LAUNCHER
# =============================================
# Usage: ./run.sh [backend|flutter|both]

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FLUTTER_DIR="$ROOT_DIR/frontend_flutter"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "${BLUE}════════════════════════════════════════${NC}"
echo "${GREEN}  FILE MANAGER PRO — Launcher${NC}"
echo "${BLUE}════════════════════════════════════════${NC}"
echo ""

MODE=${1:-both}

# Install backend deps
install_backend() {
    echo "${YELLOW}[1/3] Installing backend dependencies...${NC}"
    cd "$BACKEND_DIR"
    pip3 install -q flask flask-cors psutil 2>/dev/null || pip install -q flask flask-cors psutil
    echo "${GREEN}  ✓ Backend ready${NC}"
}

# Start backend
start_backend() {
    echo "${YELLOW}[2/3] Starting backend API server...${NC}"
    cd "$BACKEND_DIR"
    python3 server.py &
    BACKEND_PID=$!
    echo "${GREEN}  ✓ Backend started (PID: $BACKEND_PID)${NC}"
    echo "${BLUE}  → http://127.0.0.1:8000${NC}"
    sleep 2
}

# Start Flutter
start_flutter() {
    echo "${YELLOW}[3/3] Starting Flutter app...${NC}"
    cd "$FLUTTER_DIR"

    if [ ! -d "android" ] && [ ! -d "ios" ] && [ ! -d "web" ]; then
        echo "${YELLOW}  Creating Flutter project structure...${NC}"
        flutter create --org com.filemanager . 2>/dev/null || true
    fi

    flutter pub get
    echo "${GREEN}  ✓ Flutter ready${NC}"
    echo ""
    echo "${BLUE}════════════════════════════════════════${NC}"
    echo "${GREEN}  Run: cd frontend_flutter && flutter run${NC}"
    echo "${BLUE}════════════════════════════════════════${NC}"
}

# Cleanup on exit
cleanup() {
    echo ""
    echo "${YELLOW}Shutting down...${NC}"
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null || true
        echo "${GREEN}  ✓ Backend stopped${NC}"
    fi
}
trap cleanup EXIT

case "$MODE" in
    backend)
        install_backend
        start_backend
        echo "${GREEN}Backend only mode. Press Ctrl+C to stop.${NC}"
        wait
        ;;
    flutter)
        start_flutter
        ;;
    both|*)
        install_backend
        start_backend
        start_flutter
        echo ""
        echo "${GREEN}All services started!${NC}"
        echo "${YELLOW}Press Ctrl+C to stop backend.${NC}"
        wait
        ;;
esac
