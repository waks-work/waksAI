#!/bin/bash
echo "🔧 Starting waksAI development..."

# Check if Rust backend exists
if [ ! -d "rust/waks_ai_backend" ]; then
    echo "❌ Rust backend not found at rust/waks_ai_backend/"
    exit 1
fi

echo "🦀 Starting Rust backend in development mode..."
cd rust/waks_ai_backend
cargo watch -x run &
RUST_PID=$!

echo ""
echo "🎉 Development servers started!"
echo "🧩 Lua plugin: $(pwd)/../lua/waksAI"
echo "🦀 Rust backend: Running on PID $RUST_PID"
echo ""
echo "💡 Test in Neovim with:"
echo "   :lua require('waksAI').some_function()"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for Ctrl+C
trap "kill $RUST_PID; exit" INT
wait $RUST_PID
