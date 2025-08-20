# WaksAI

WaksAI is a full-stack AI chatbot system with a **Lua frontend** and **Rust backend**, designed for real-time interaction, AI processing, and smooth UI experience. It is modular, dynamic, and optimized for cross-platform use. This README contains **everything needed** to run, develop, and extend WaksAI in a single file.

---

## Table of Contents

1. [Features](#features)  
2. [Requirements](#requirements)  
3. [Installation & Setup](#installation--setup)  
4. [Usage](#usage)  
5. [Commands & Shortcuts](#commands--shortcuts)  
6. [Development Notes](#development-notes)  
7. [Extending AI Models](#extending-ai-models)  
8. [Contributing](#contributing)  
9. [License](#license)  

---

## Features

- Real-time AI chat interface  
- Dynamic UI built with Lua  
- Rust backend for AI logic, processing, and API handling  
- Modular architecture: UI, input, state management, backend communication  
- Cross-platform: Linux, Windows, macOS  
- Session management with automatic context preservation  
- Easy extension for new AI models or features  

---

## Requirements

### Lua Frontend
- Lua 5.4+  
- Lua runtime (Love2D optional)  
- No additional dependencies  

### Rust Backend
- Rust 1.70+ with Cargo  
- Recommended: stable toolchain  

### System
- Linux, Windows, or macOS  
- Terminal or GUI environment  
- Network access for optional model updates  

---

## Installation & Setup

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/waksAI.git
cd waksAI
2. Build Rust backend
bash
Copy
Edit
cd rust/waks_ai_backend
cargo build --release
Binary will be at target/release/waks_ai_backend.

3. Run WaksAI
Open two terminals:

Terminal 1 – Run Rust backend:

bash
Copy
Edit
cd rust/waks_ai_backend
cargo run --release
Terminal 2 – Run Lua frontend:

bash
Copy
Edit
cd lua
lua waksAI/init.lua
UI will open, ready for chat.

Input messages and press Enter to send.

Usage
Chat dynamically adjusts to screen size

AI responses are real-time

Sessions are automatically managed

Reset session with /reset

Commands & Shortcuts
Command	Description
/reset	Reset session and context
/help	Show help message
/exit	Close UI
/status	Show backend connection status
/model <name>	Switch AI model dynamically

Development Notes
Frontend

init.lua – Main entry point

ui.lua – Chat interface & rendering

input.lua – User input handling

state.lua – Session/context management

api.lua – Communicates with backend

Backend

main.rs – AI logic & server

Cargo.toml – Dependencies and Rust package

Running in Debug Mode

bash
Copy
Edit
# Backend
cargo run
# Frontend
lua waksAI/init.lua
Modular design allows adding new commands, UI elements, and AI logic easily

Extending AI Models
Add new models in backend Rust logic

Update API functions in api.lua

Use /model <name> to switch dynamically

Contributing
Fork the repository

Create a feature branch: git checkout -b feature-name

Commit changes: git commit -am 'Add feature'

Push branch: git push origin feature-name

Open a pull request

License
WaksAI is released under the MIT License. See LICENSE file for details.

Developed with ❤️ by the WaksAI Team

yaml
Copy
Edit

---

This is **one single, fully integrated README.md** file. You don’t need separate files for structure, usage, commands, or development notes. Everything is in **one place**, ready to copy.  

If you want, I can **also embed a small ASCII diagram** showing the **Frontend ↔ Backend ↔ AI flow** inside this README for extra clarity.  

Do you want me to add that diagram?
