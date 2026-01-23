
# 🎯 Goal (Non-Negotiable)

In **≤ 3 months (12 weeks)** you will release:

## ✅ waksAI v1
- Stable Neovim AI assistant  
- Minimal, clean UI  
- Strong backend  
- Fully documented  
- Easy to install  

## ✅ waksManager v1
- Rust-based Arch Linux system manager  
- Replaces core bash functionality  
- Extensible foundation  
- CLI-first and stable  

**No feature creep. No “almost done”.**

---

# ⏱ Time Budget (Fixed)

- **Total:** 26 hrs/week  
- **waksAI:** 16–18 hrs/week  
- **waksManager:** 8–10 hrs/week  

### Over 12 weeks
- **waksAI:** ~200 hours  
- **waksManager:** ~110 hours  

> This is more than enough if scope is controlled.

---

# 🧭 High-Level Strategy

### Rule #1  
**waksAI finishes first** (Weeks 1–8)

### Rule #2  
**waksManager reaches “foundation complete”** (Weeks 1–12)

### Rule #3  
**UI freezes earlier than features**

---

# 📆 3-Month Roadmap (Week by Week)

---

## 🔵 MONTH 1 (Weeks 1–4): Freeze Foundations

### waksAI (Primary Focus)

#### Week 1 — UI Reset & Minimal Canonical UI
**Goal:** Make the UI boring and solid

- [ ] Remove web-style UI experiments  
- [ ] Decide on **one** layout (split or float)  
- [ ] Input via `vim.ui.input`  
- [ ] Output-only chat buffer  
- [ ] Streaming works flawlessly  
- [ ] Limit to 5 core keymaps  
- [ ] No crashes or cursor weirdness  

👉 **End of week:** Usable for 30 minutes without annoyance

---

#### Week 2 — Feature Freeze & Stability
**Goal:** Make it reliable

- [ ] Finalize backend ↔ frontend protocol  
- [ ] Clean error handling  
- [ ] Stable session lifecycle  
- [ ] History persistence verified  
- [ ] Remove dead code and TODO UI paths  

👉 **End of week:** Feature list frozen

---

#### Week 3 — UX Polish (Invisible)
**Goal:** Make it feel native

- [ ] Clean markdown rendering  
- [ ] Spacing & headings only (no decoration)  
- [ ] Highlight groups aligned with theme philosophy  
- [ ] Copy helpers (`yc`, `yy`) stable  
- [ ] Optional minimal Telescope picker  

👉 **End of week:** Feels like a real Neovim plugin

---

#### Week 4 — Documentation & Packaging
**Goal:** Prepare for users

- [ ] README:
  - What it is  
  - Installation  
  - Quick start  
- [ ] Minimal config options  
- [ ] Example screenshots / GIFs  
- [ ] Version tag plan (`v0.1.0` or `v1.0.0`)  

👉 **waksAI = Release Candidate (RC)**

---

### waksManager (Secondary Focus — Month 1)

- [ ] Define Rust core architecture  
- [ ] Identify **must-port** bash scripts  
- [ ] CLI skeleton stable  
- [ ] Config loading working  

---

## 🟣 MONTH 2 (Weeks 5–8): Ship waksAI v1

### waksAI

#### Week 5 — Final QA & Hardening
- [ ] Stress test streaming  
- [ ] Handle network failures  
- [ ] Handle provider/model switching  
- [ ] Fix edge cases  
- [ ] Lock API  

👉 **No new features allowed**

---

#### Week 6 — Release v1.0.0
- [ ] Tag release  
- [ ] Clean repository  
- [ ] Announce (even if small)  
- [ ] Archive experimental UI branches  

🎉 **waksAI v1 SHIPPED**

---

### waksManager (Parallel Focus)

#### Weeks 5–8 — Foundation Complete
- [ ] Rust equivalents for:
  - App launching  
  - Menus  
  - System toggles  
- [ ] Async process runner  
- [ ] Replace 30–40% of bash scripts  
- [ ] Stable CLI UX  

---

## 🟢 MONTH 3 (Weeks 9–12): waksManager v1

### waksManager (Primary Focus)

#### Week 9 — Feature Completion
- [ ] Port remaining **critical** bash scripts  
- [ ] Decide what stays bash (allowed)  
- [ ] Ensure parity with old workflow  

---

#### Week 10 — UX & Reliability
- [ ] CLI help text  
- [ ] Clear error messages  
- [ ] Logging  
- [ ] Config validation  

---

#### Week 11 — Documentation & Packaging
- [ ] README  
- [ ] Arch install instructions  
- [ ] Migration notes from bash  
- [ ] Version tag plan  

---

#### Week 12 — Release v1
- [ ] Cleanup  
- [ ] Tag release  
- [ ] Freeze API  
- [ ] Celebrate  

🎉 **waksManager v1 SHIPPED**

---

# 🚦 Strict Feature Rules (Critical)

## waksAI v1 Includes
- ✅ Chat  
- ✅ Streaming  
- ✅ Code generation  
- ✅ Copy helpers  
- ✅ Sessions  

### Not Included
- ❌ MCP  
- ❌ Multi-agent  
- ❌ Inline chat (post-v1)  
- ❌ Fancy UI  

---

## waksManager v1 Includes
- ✅ Core launcher  
- ✅ Menu system  
- ✅ System controls  
- ✅ Rust performance  

### Not Included
- ❌ Plugin system  
- ❌ GUI / TUI  
- ❌ Remote control  

---
