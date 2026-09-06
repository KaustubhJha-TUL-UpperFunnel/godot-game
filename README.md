# DESCENT — 2D Top-Down Action Roguelite

**DESCENT** is a high-performance native C++ GDExtension top-down action roguelite built for **Godot 4.7**. 

Featuring pixel-art dark fantasy aesthetics, you play as an armored knight battling squishy hopping slimes, dual-dagger goblins, sorcerers, and stone golems with melee broadsword slashes, elemental fire/ice spells, and a 6-slot action hotbar. Clear single-screen chambers, choose between three arched doorways (Loot, Shop, Danger), and plunge down the central descent shaft to conquer all 8 floors.

---

## Table of Contents
1. [Repository Setup & Cloning](#repository-setup--cloning)
2. [Linux Setup & Run Guide](#linux-setup--run-guide)
3. [Windows Setup & Run Guide](#windows-setup--run-guide)
4. [Controls & Gameplay Mechanics](#controls--gameplay-mechanics)
5. [Automated Testing & Validation](#automated-testing--validation)
6. [Architecture & Project Structure](#architecture--project-structure)
7. [Troubleshooting & FAQ](#troubleshooting--faq)

---

## Repository Setup & Cloning

> **Important:** This repository uses the official `godot-cpp` bindings as a Git submodule. Always clone with `--recurse-submodules`!

### Clone the `descent_gemini` Branch:

```bash
git clone -b descent_gemini --recurse-submodules https://github.com/RoDE22183/godot-game.git
cd godot-game
```

*(If you already cloned without `--recurse-submodules`, initialize the submodules manually:)*
```bash
git submodule update --init --recursive
```

---

## Required Software

Every developer needs:
1. **Godot Engine 4.7.2 Standard** (64-bit, standard edition — do **not** use the .NET edition): [Download Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/)
2. **Git**: [Download Git](https://git-scm.com/downloads)
3. **Python 3 (64-bit)**: [Download Python](https://www.python.org/downloads/)
4. **SCons build system**: `pip install scons`
5. **C++17 Compiler**: GCC/Clang on Linux, MSVC (Visual Studio 2022) on Windows.

---

## Linux Setup & Run Guide

### 1. Install Dependencies

**Ubuntu / Debian / Linux Mint:**
```bash
sudo apt update
sudo apt install -y git build-essential python3 python3-pip scons
```

**Fedora / RHEL:**
```bash
sudo dnf install -y git gcc-c++ python3 scons
```

**Arch Linux:**
```bash
sudo pacman -S --needed git gcc python scons
```

### 2. Compile the C++ GDExtension

From the root of the cloned repository:
```bash
scons -j4 platform=linux arch=x86_64 target=template_debug
```
*This compiles the Godot C++ bindings and the game logic into `descent/bin/libdescent.linux.template_debug.x86_64.so`.*

### 3. Run the Game

Make your Godot binary executable and point it to the project folder:
```bash
chmod +x /path/to/Godot_v4.7.2-stable_linux.x86_64
/path/to/Godot_v4.7.2-stable_linux.x86_64 --path .
```

*(Tip: You can create a symlink in the project root named `godot.bin` for quick access:)*
```bash
ln -sf /path/to/Godot_v4.7.2-stable_linux.x86_64 ./godot.bin
./godot.bin --path .
```

To open the project in the **Godot Editor**:
```bash
/path/to/Godot_v4.7.2-stable_linux.x86_64 --editor --path .
```

---

## Windows Setup & Run Guide

### 1. Install Required Tools

1. **Git for Windows**: [git-scm.com/download/win](https://git-scm.com/download/win)
2. **Python 3 (64-bit)**: [python.org/downloads/windows](https://www.python.org/downloads/windows/)
   - *Ensure you check **"Add python.exe to PATH"** during installation.*
3. **Visual Studio 2022 Community** or **Build Tools for Visual Studio 2022**: [visualstudio.microsoft.com/downloads](https://visualstudio.microsoft.com/downloads/)
   - In the Visual Studio Installer, enable the **"Desktop development with C++"** workload.
4. **Godot 4.7.2 Standard (Win64)**: [godotengine.org/download/archive/4.7.2-stable](https://godotengine.org/download/archive/4.7.2-stable/)
   - Extract the `.zip` archive to a folder (e.g. `C:\Godot\Godot_v4.7.2-stable_win64.exe`).

### 2. Install SCons

Open the **"x64 Native Tools Command Prompt for VS 2022"** (search for it in the Windows Start Menu) and run:
```bat
py -m pip install scons
```

Verify your compilers are available:
```bat
cl
py --version
scons --version
```

### 3. Compile the C++ GDExtension

In the **x64 Native Tools Command Prompt**, navigate to the project root:
```bat
cd path\to\godot-game
scons -j4 platform=windows arch=x86_64 target=template_debug
```
*This produces `descent\bin\libdescent.windows.template_debug.x86_64.dll`.*

### 4. Run the Game

From the command prompt:
```bat
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --path .
```

To open in the **Godot Editor**:
```bat
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --editor --path .
```

---

## Controls & Gameplay Mechanics

| Action | PC Controls (Keyboard & Mouse) | Mobile Touch |
| :--- | :--- | :--- |
| **Move Knight** | `W`, `A`, `S`, `D` or Arrow Keys | Left Virtual Joystick |
| **Aim Direction** | Mouse Cursor | Right Virtual Joystick |
| **Broadsword Slash** | `Left Click` or Key `1` | Tap Right Stick / Attack Button |
| **Fireball Spell** | Key `2` (Cost: 15 Mana, explodes on impact) | Tap Hotbar Slot 2 |
| **Frost Nova Spell**| Key `3` (Cost: 20 Mana, circular freeze blast) | Tap Hotbar Slot 3 |
| **Evasion Dash** | `Spacebar`, `Shift`, or Key `4` | Tap DASH Button / Slot 4 |
| **Health Potion** | Key `5` (Restores 35 HP, 2 charges per floor) | Tap Hotbar Slot 5 |
| **Mana Elixir** | Key `6` (Restores 35 Mana & gives +40% Speed) | Tap Hotbar Slot 6 |
| **Interact / Enter Door** | Walk into door or press `E` / Click Offer | Tap INTERACT Button |
| **Pause / Resume** | `Escape` or `P` | Tap Top-Right Pause Icon |

### Combat & Combo System
- **3-Hit Broadsword Combo**: Rapid left-clicking performs a three-tier melee combo. The 3rd hit unleashes an empowered, large golden crescent slash dealing **+50% finisher damage**.
- **Slime Hop Physics**: Slimes hop dynamically in 3 phases (crouch $\to$ vertical leap with scaling ground shadow $\to$ splat), swapping to an angry grimace when attacked.
- **Goblin Charger**: Dual-dagger goblins sprint toward the knight in a low combat stance and lunge with swift double-dagger strikes.

### Debug Hotkeys (Debug Builds Only)
- `F1`: Instantly clear current combat room
- `F2`: Damage player (-20 HP)
- `F3`: Heal player (+30 HP)
- `F4`: Add 50 gold coins
- `F5`: Add 25 permanent Echoes
- `F6`: Skip directly to next floor
- `F7`: Reset permanent progression save

---

## Automated Testing & Validation

The game includes built-in test runners for CI and headless testing:

### 1. Fast Native Smoke Tests (22 assertions)
```bash
/path/to/godot --headless --path . -- --smoke-test
```
*Validates health clamping, damage formulas, floor generation, door generation, shop transactions, archetype configurations, and save file integrity.*

### 2. Full 8-Floor Automated Run Test
```bash
/path/to/godot --headless --path . -- --flow-test
```
*Runs an automated AI player through all 8 dungeon floors, loot rooms, danger rooms, shops, the boss battle, and victory, asserting 0 memory or Resource ID (RID) leaks.*

---

## Architecture & Project Structure

- `project.godot`: Engine settings, Compatibility renderer, 1280×720 viewport.
- `SConstruct`: Cross-platform build script targeting Linux, Windows, and Android.
- `godot-cpp/`: Pinned official C++ GDExtension bindings for Godot 4.7.
- `descent/gdextension/`: Extension manifest (`descent.gdextension`).
- `descent/include/descent/`:
  - `descent_game.hpp`: Main game controller, state machine, room manager, and HUD.
  - `player_avatar.hpp`: Knight controller, physics, 3-hit combo, dash, and spells.
  - `enemy_actor.hpp`: Slime hopping, goblin dashing, and sorcerer AI.
  - `descent_art.hpp`: High-res sprite loaders, animations, and particle renderers.
  - `health_component.hpp`: Unified health, damage, and invulnerability component.
- `descent/src/`: C++ implementation files.
- `descent/assets/game/`: High-resolution pixel-art sprites, HUD frames, hotbar icons, and dungeon backgrounds.
- `descent/data/`: `.tres` resources defining difficulty curves, enemy stats, and upgrade tracks.

---

## Troubleshooting & FAQ

- **Error: `godot-cpp/SConstruct: No such file or directory`**:
  You cloned without submodules. Run `git submodule update --init --recursive` in the project root.
- **Error: `GDExtension library not found: libdescent...`**:
  You must compile the C++ extension first using `scons -j4` before opening Godot.
- **Windows: `cl: command not found`**:
  Make sure you are building inside the **x64 Native Tools Command Prompt for VS 2022**, not standard PowerShell or CMD.
- **Save File Location**:
  - Linux: `~/.local/share/godot/app_userdata/DESCENT/descent_save_v1.json`
  - Windows: `%APPDATA%\Godot\app_userdata\DESCENT\descent_save_v1.json`
  *(You can press `F7` during gameplay to reset the save file).*
