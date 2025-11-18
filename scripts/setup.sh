#!/bin/bash
echo "🧩 Setting up waksAI Neovim plugin..."

# Check if we're in the right location
if [ ! -d "lua/waksAI" ]; then
    echo "❌ Error: This doesn't look like the waksAI directory"
    echo "💡 Make sure you're in ~/.config/nvim/waksAI/"
    exit 1
fi

# Setup Rust backend
echo "🦀 Setting up Rust backend..."
cd rust/waks_ai_backend
cargo fetch
if command -v cargo-watch >/dev/null 2>&1; then
    echo "✅ cargo-watch already installed"
else
    cargo install cargo-watch
fi
cd ../..

# Setup git hooks
echo "📝 Setting up git hooks..."
cp .github/hooks/* .git/hooks/ 2>/dev/null || true
chmod +x .git/hooks/* 2>/dev/null || true

echo "✅ waksAI setup complete!"
echo "💡 Start development with: ./scripts/dev.sh"
