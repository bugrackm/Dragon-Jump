# TASK-001: M1 — Core Prototype

## ROLE
You are a Godot 4 game developer. Build a minimal playable prototype of a Doodle Jump-like vertical platformer.

## GOAL
Create a working Godot 4.7 project where a dragon character auto-jumps upward across procedurally generated one-way platforms, with score tracking and game-over on falling.

## WHY THIS TASK EXISTS
First vertical slice. Prove the core loop works before adding gameplay variety (M2), polish (M3), and monetization (M4).

## RELEVANT PROJECT CONTEXT

### Tech
- Engine: Godot 4.7.1 (already installed at ~/Godot/)
- Language: GDScript
- Renderer: Compatibility
- Project root: /home/xaden/Desktop/Dragon-Jump/

### Game Design
- Doodle Jump-like vertical platformer
- Dragon character auto-jumps when landing on platform
- Procedural endless platform generation going upward
- Score = max altitude reached (not current position)
- Game over when player falls below camera/screen bottom
- Horizontal movement: tap left/right half of screen + keyboard arrows (desktop)
- Wrap-around: player exits one screen edge, enters from other
- One-way platforms: player passes through from below, lands on top

### Architecture (from docs/ai/ARCHITECTURE.md)
- RunSession: state (READY→PLAYING→GAME_OVER), score, RNG seed
- ProfileStore: high score, ConfigFile save/load (user://profile.cfg)
- Player: CharacterBody2D + AnimatedSprite2D (placeholder color rect) + CollisionShape2D
- Platform: one-way StaticBody2D + Sprite2D (placeholder) + CollisionShape2D
- PlatformManager: seeded procedural spawn, reachability guarantee, instantiate/free
- Camera2D: follows player upward
- HUD: score label + high score label
- Main: root scene

### Platform Physics
- Platforms = one-way StaticBody2D (solid from top, pass-through from below)
- Player = CharacterBody2D
- Collision: player only collides with platform when moving downward
- Collision layers: player (layer 1, mask 2), platforms (layer 2, mask 1)

### Procedural Generation Rules
- Seeded RNG (deterministic)
- Max vertical gap = jump_height * 0.8
- Max horizontal gap = screen_width * 0.7
- Safe starting region: first 10 platforms, no gaps larger than 80% jump height
- Each platform reachable from previous landing position
- Score = max altitude (Y position at highest point)

### Input
- Touch: tap left half = move left, tap right half = move right
- Keyboard: left/right arrows = horizontal movement (desktop fallback)
- No tilt, no double jump, no glide, no fire in M1 (M2 adds these)

## REQUIRED SOURCE DOCUMENTS
- docs/ai/ARCHITECTURE.md
- docs/ai/REQUIREMENTS.md

## FILES OWNED
All files in res:// (the Godot project)

## FILES THAT MUST NOT BE TOUCHED
- docs/ (design documents)
- .git/
- .hermes-ops/

## EXACT ACCEPTANCE CHECKS
1. Project opens in Godot 4.7.1 editor without errors
2. F5 runs the game
3. Dragon (placeholder colored rectangle) auto-jumps on platform contact
4. Platforms generate procedurally going upward
5. Player can move left/right with keyboard arrows
6. Player can move left/right with touch (tap left/right half)
7. Wrap-around works (exit right edge, enter left edge)
8. One-way collision works (pass through from below, land on top)
9. Score = max altitude, displayed in HUD
10. Game over when player falls below screen
11. High score saved to user://profile.cfg and loaded on restart
12. Seeded RNG: same seed = same platform layout
13. All platforms reachable (no impossible gaps)

## ALLOWED COMMANDS
- Create/edit GDScript (.gd) files
- Create/edit scene (.tscn) files
- Create/edit project.godot
- Run Godot headless for verification: ~/Godot/Godot_v4.7.1-stable_linux.x86_64 --headless
- Run Godot editor for project import: ~/Godot/Godot_v4.7.1-stable_linux.x86_64 --editor --quit (to validate project loads)

## SAFETY LIMITS
- Do not install packages
- Do not modify system files
- Do not create Android export configs (M1.5)
- Do not add ads, billing, or audio (M3/M4)
- Keep placeholder graphics (colored rectangles, no sprite assets needed)
- Do not add power-ups, enemies, coins, or abilities (M2)

## REQUIRED COMPLETION REPORT
- Result summary
- Files created (list with paths)
- Scene tree structure
- Collision setup explanation
- Procedural generation algorithm summary
- Input handling summary
- Save/load implementation summary
- Any issues encountered
- Acceptance check status (pass/fail for each of the 13 checks)