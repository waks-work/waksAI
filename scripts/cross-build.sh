#!/bin/bash
echo "🏗️ Building cross-language project..."

# Rust + C/C++ FFI projects
if [ -f "Cargo.toml" ] && [ -f "CMakeLists.txt" ]; then
    echo "🔗 Building Rust + C/C++ FFI..."
    
    # Build C/C++ components first
    mkdir -p build
    cd build
    cmake ..
    make -j$(nproc)
    cd ..
    
    # Build Rust components (assuming C libs are linked)
    cargo build --release
    
    echo "✅ Cross-language build complete!"
    exit 0
fi

# Rust + Python projects
if [ -f "Cargo.toml" ] && [ -f "pyproject.toml" ]; then
    echo "🔗 Building Rust + Python bindings..."
    cargo build --release
    maturin develop 2>/dev/null || echo "⚠️ Install maturin for Python bindings: pip install maturin"
    exit 0
fi

echo "ℹ️  No cross-language build configuration detected"
