# WaksAI

WaksAI is a text editor plugin built on top of neovim with features that allow for internal ai agents, ai 
features and many other features inside neovim.
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

 - Agentic mode for users inside neovim.
 - Code generation and code edit all inside neovim.
 - Inline and ai chat completion.
 - Allow us to use mutiple models and providers.
 - Intergrate well with external agentic models.

---

## Requirements

### Lua Frontend
We use lua for our user interface and user experience inside neovim.

### Rust Backend
We use rust extensively in our backend handling communications between frontend,
ai backend that handles communication with the ai.

### System
Systems and environment supported currrently are environment that neovim currently runs on.

---

## Installation & Setup

### 1. Clone the repository

```bash
git clone https://github.com/waks-work/waksAI.git
cd waksAI

```

### 2. Build Rust backend
```bash
cd rust/waks_ai_backend
cargo build --release

```

Binary will be at target/release/waks_ai_backend.

### 3. Run WaksAI
Open two terminals:

#### Terminal 1 – Run Rust backend:

```bash
cd rust/waks_ai_backend
cargo run --release

```

#### Terminal 2 – Run Lua frontend:

```bash
cd lua
lua waksAI/init.lua

```

UI will open, ready for chat.

Input messages and press Enter to send.

#### Usage
Chat dynamically adjusts to screen size

AI responses are real-time

Sessions are automatically managed

Reset session with /reset

```bash
Commands & Shortcuts
Command	Description
/reset	Reset session and context
/help	Show help message
/exit	Close UI
/status	Show backend connection status
/model <name>	Switch AI model dynamically

```

Development Notes
### Frontend

 - init.lua – Main entry point into our project
 - ui/ – Chat interface & rendering, inline, events, etc.
 - state/ – Session/context management
 - api/ – Communicates with backend and handle our api interface.
 - history/ - Checks the history and our database communication.
 - context/ - handle all the ai context. 
 - edit/ - allows editting of code editing to happen.

### Backend

 -> main.rs – Entry point of our project.
 -> ai/ - handles all the ai tasks.
 -> storage/ - handle all our storage methods
 -> communication/ - handle communication between components. 

```bash
# Backend
cargo run
# Frontend
lua waksAI/init.lua

```

Modular design allows adding new commands, UI elements, and AI logic easily

## Extending AI Models
Check out: [extending features](docs/EXTENDING.md) for more information.

## Contributing
Check out; [contributing](/docs/CONTRIBUTING.md) for more information.

## License
We are currently under an MIT License.

---

```yaml

waks

```

