#!/bin/bash
echo "🧪 Running waksAI tests..."

# Test Rust backend
if [ -d "rust/waks_ai_backend" ]; then
    echo "🦀 Testing Rust backend..."
    cd rust/waks_ai_backend
    cargo test
    cd ../..
else
    echo "⚠️  Rust backend not found"
fi

# Test Lua syntax
if [ -d "lua" ]; then
    echo "🧩 Checking Lua syntax..."
    find lua -name "*.lua" -exec luac -p {} \; && echo "✅ Lua syntax OK"
else
    echo "⚠️  Lua components not found"
fi

echo "✅ waksAI tests completed!"
