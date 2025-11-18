# Contributing to waksAI

waksAI is a Neovim plugin with Rust backend located in `~/.config/nvim/waksAI/`.

## Development Setup

```bash

# In the waksAI directory
./scripts/setup.sh
./scripts/dev.sh

```

# Project Structure
 - lua/waksAI/ - Neovim plugin (Lua)
 - rust/waks_ai_backend/ - AI backend (Rust)
 - assets/ - Images and resources

# Testing
 - Lua components: Load in Neovim and test manually
 - Rust components: cd rust/waks_ai_backend && cargo test
 - Integration: Use the provided test scripts

