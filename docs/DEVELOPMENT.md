# waksAI Development Guide

## Quick Start
```bash
./scripts/setup.sh    # One-time setup
./scripts/dev.sh      # Start development
./scripts/test.sh     # Run tests ```
## Project Structure
 - lua/waksAI/ - Neovim plugin interface
 - rust/waks_ai_backend/ - AI processing backend
 - scripts/ - Automation tools
 - .github/ - CI/CD and templates

# Development Workflow
 - Make changes to Rust or Lua code
 - Test with ./scripts/test.sh
 - Commit changes (pre-commit hooks run automatically)
 - Push to trigger CI/CD
