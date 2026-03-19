#!/bin/bash
echo "Linting code for Waks stack..."

# Rust
[ -f "Cargo.toml" ] && cargo fmt -- --check && cargo clippy -- -D warnings

echo "Linting completed for Waks stack!"
