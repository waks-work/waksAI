#!/bin/bash
# scripts/detect-stack.sh

echo "🔍 Detecting Waks development stack..."

[ -f "Cargo.toml" ] && echo "🦀 Rust project"
[ -f "CMakeLists.txt" ] && echo "🔧 C/C++ project" 
[ -f "package.json" ] && echo "🌐 TypeScript project"
[ -f "requirements.txt" ] && echo "🐍 Python project"
[ -f "*.lua" ] && echo "🧩 Lua project"

# Cross-language detection
([ -f "Cargo.toml" ] && [ -f "CMakeLists.txt" ]) && echo "🔗 Rust + C/C++ cross-language"
([ -f "Cargo.toml" ] && [ -f "package.json" ]) && echo "🔗 Rust + TypeScript full-stack"

echo "✅ Stack detection complete"
