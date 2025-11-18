#!/bin/bash
echo "🔍 Linting code for Waks stack..."

# Rust
[ -f "Cargo.toml" ] && cargo fmt -- --check && cargo clippy -- -D warnings

# C/C++
[ -f ".clang-format" ] && find src/ -name "*.cpp" -o -name "*.hpp" -o -name "*.c" -o -name "*.h" | xargs clang-format -i
[ -f "CMakeLists.txt" ] && cmake-format -i CMakeLists.txt 2>/dev/null || true

# TypeScript/JavaScript
[ -f "package.json" ] && npx eslint . --fix 2>/dev/null || true

# Python
[ -f "requirements.txt" ] && black . 2>/dev/null || true

# Lua
[ -f "*.lua" ] && find . -name "*.lua" -exec luacheck {} \; 2>/dev/null || true

echo "✅ Linting completed for Waks stack!"
