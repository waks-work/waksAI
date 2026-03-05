
# Workflow  

> This tracks the work we will be doing through our timeline in the project,
> features and time it takes to work on it.

# Structure to follow in this Workflow
 - Task we had done in the previous session
 - Task we are going to do in this session
 - session: {
      date of the task,
      **task to be done**(in this format),
      task done: Accomplishment and simple documentation of the task
      }
  - Task we have done in this current session
  - Task we will do in the next session

# Task
## 11th February 2026

 > In the previous session before this we had done our project by setting up 
 > our backend in rust and made it stable, with somehow good backend

 > In this session we are going to set up the process of doing tasks and we
 > are going to check the projects to understand how the project works in 
 > the basic sense, from the rust backend to the lua frontend to handle the
 > neovim ui.

 > task done: we were able to go through the whole backend and looked at our
 > architecture implemented for our projects looked at our lua frontend and 
 > we were able to look at the various ui choices and came up with various 
 > suggestions. Suggestion were both in the ui and in the architecture.

 > In the next session we are to add documentation and documentation tests 
 > to our backend.

 **Suggestions from today**
  - Architectural "Triple Redundancy" Sync:
    Ensure the Lua frontend explicitly triggers the Rust StrongHandle to sync 
    memory state to both SQLite and the JSON filesystem mirrors during every "Apply" action.

  - Modular Lua Reorganization: 
    Move away from a flat ui.lua to a directory-based structure 
    (waksAI/ui/, waksAI/state/, waksAI/control/) to support scaling and maintainability.

  - EmmyLua Type Annotations: 
    Implement strict LuaCATS/EmmyLua @class and @param annotations across all Lua
    modules to ensure LSP-level safety and better developer experience.

  - UI Strategy - "The Side-Car & Ghost":
    * Side-Car: Use vertical splits with filetype=markdown for chat to leverage 
    native Tree-sitter syntax highlighting.

  - Ghost Text: 
    Use virt_lines for inline code suggestions to avoid the "flicker" and 
    math complexity of floating windows.

  - Agentic Diff Workflow:
    Use a tabnew + diffthis temporary buffer strategy for code refactors,
    allowing a "Review -> Apply -> Record" cycle.

## 12th February 2026


## 13th February 2026 

 > task done previously: we went through the whole backend and frontend architecture. 
 > Suggestion were made both in the ui and in the backend architecture.

 > task to be done: Implement context.lua with documentation and testing.
 
 > task done:
 >  1. Finalized the Core Logic tier: state, context, api, config and edit.
 >  2. Implemented Treesitter-native node traversal and Ripgrep-powered project context.
 >  3. Enabled session based tracking to sync Neovim activity with Rust/SQLite backend. 
 >  4. Verified with Unit Tests for visual selection, history trimming and API construction. 
 > Finalized the "eyes" of the AI agent. The backend now receives structured context metadata.
 
 >  In the next session we will: Implement the UI Tier(picker -> code_change), Utility layer to 
 >  consolidate helpers(utils), Final link entry point to expose commands and keymap to user(init).

## 15th February 2026

 > task done previously: we improved the init, code_change, picker, and other files.
 
 > task done: 
 >  1. Infrastructure: The single-instance Rust backend is operational on port 11500.
 >  2. Database: is documented and supports session tracking, code changes, and hardware diagnostic logs.
 >  3. Neovim: We identified the LSP attachment conflict between rust-tools and the manual rust_analyzer setup.
 > Finalized our major file refactor and setup of our backend db to connect to our frontend.

 > task we will do in the next session: In the next session continue with the refactor of our backend.

