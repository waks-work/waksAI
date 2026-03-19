#!/bin/bash

# Standardized Waks Project Development Script
PROJECT_ROOT=$(pwd)
BACKEND_DIR="rust/waks_ai_backend"
LUA_DIR="lua/waksAI"

echo "[WaksAI] Initializing development environment..."

# Verification Logic
if [ ! -d "$BACKEND_DIR" ]; then
    echo "Error: Rust backend not found at $BACKEND_DIR/"
    exit 1
fi

# Cleanup Function (Ensures no zombie processes)
cleanup() {
    echo -e "\n Stopping services..."
    kill $RUST_PID 2>/dev/null
    exit
}
trap cleanup INT TERM

# 3. Execution
echo "Starting Rust backend with cargo watch..."
cd "$BACKEND_DIR" || exit
cargo watch -x run &
RUST_PID=$!

echo -e "\n Development servers active!"
echo "---------------------------------"
echo " Lua Module Path: $PROJECT_ROOT/$LUA_DIR"
echo " Rust Backend PID: $RUST_PID"
echo "---------------------------------"
echo " Usage: Test in Neovim with :lua require('waksAI').some_function()"
echo " Press Ctrl+C to stop."

# Keep script running
wait $RUST_PID
