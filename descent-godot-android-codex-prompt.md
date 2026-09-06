# DESCENT — Codex Build Prompt for Godot and Android

## Role

You are Codex acting as a senior Godot gameplay engineer, mobile game developer, technical designer, and QA owner.

Work directly inside the current workspace and build a polished, playable vertical slice of the game described below. Do not stop after writing a plan or explaining how the game could be built. Create the project files, scenes, native C++ sources, resources, controls, UI, and Android export configuration; run the project; test the complete loop; and fix errors you discover.

Use **Godot 4.7.2**, **C++17**, **GDExtension**, and a compatible revision of **godot-cpp**. Implement gameplay and application logic in native C++; do not use GDScript or C#. Godot scenes and resources may remain text-based `.tscn` and `.tres` files. Build both the Linux editor library and the Android libraries needed by the export preset. Keep the extension boundary small, register native classes centrally, and expose designer-facing values with `ClassDB::bind_method`, properties, and signals.

## Before implementation

1. Inspect the current directory.
2. Read any **AGENTS.md**, **README**, or repository-specific instructions before editing.
3. If **project.godot** already exists, preserve the existing project structure and work within it.
4. If no Godot project exists, create one in the current workspace.
5. Preserve unrelated user files and existing changes.
6. Determine which Godot executable is installed, such as **godot4** or **godot**.
7. Determine whether a C++ compiler, Python 3, SCons, a compatible `godot-cpp`, Android export templates, Java, and the Android SDK/NDK are configured.
8. Use the installed stable Godot 4.7.2 version and APIs supported by that version. Pin or record the selected `godot-cpp` revision so builds are reproducible.
9. Compile and load the Linux GDExtension before building gameplay scenes on top of it. Rebuild after native API changes and stop on compiler or extension-loading errors.

Do not ask for minor gameplay, visual, naming, or balancing decisions. Make sensible decisions independently and document them.

---

# Game: DESCENT

## High concept

DESCENT is a fast 2D top-down action roguelite designed for Android.

The player travels downward through a ruined underground machine, one floor at a time. Every floor is a single-screen arena. The player enters, the exits lock, enemies spawn, and the room must be cleared.

After the encounter, three physical doors become available:

- **LOOT:** Lower risk and a guaranteed upgrade choice
- **DANGER:** Harder enemies or hazards with substantially better rewards
- **SHOP:** A safe room where run currency can be spent

The player can enter only one door. The selected door determines the next room, then the player drops immediately to the next floor.

A successful run contains eight floors and should take approximately 3–6 minutes. Death ends the current run and returns the player to Floor 1, but permanent currency and unlocked content remain.

The defining rhythm is:

> Enter room → fight → clear room → inspect three doors → choose risk and reward → descend immediately.

The door decision is the main addictive beat. Give it as much clarity and feedback as the combat.

---

# Scope and completion priority

Build a complete vertical slice, not a collection of disconnected systems.

If time or tooling becomes constrained, preserve the following priority:

## Priority 0 — Must be complete

- Android-friendly movement, aiming, firing, and dash controls
- Player health, damage, death, and restart
- Three working enemy types
- Single-screen room encounters
- Room-clear detection
- Exactly three functional doors
- Loot, Danger, and Shop destinations
- Floor progression
- Run reset
- Persistent Echo currency and save data

## Priority 1 — Required vertical-slice content

- Eight-floor run
- Boss on Floor 8
- Run upgrades
- Shop purchases
- Permanent upgrades
- Multiple room layouts
- Difficulty scaling
- Death and victory summaries
- Android export preset

## Priority 2 — Polish

- Particles
- Screen shake
- Hit stop
- Door animations
- Strong transition effects
- Optional audio and haptics

Simplify visual decoration before cutting core gameplay. Do not leave several elaborate but unfinished systems.

---

# Target platform

## Primary target

- Android phones
- Landscape orientation
- Touch-first interface
- Target 60 FPS on a typical mid-range Android device
- Playable at wide and tall phone aspect ratios
- No network connection required
- No unnecessary Android permissions

Use Godot's **Compatibility renderer** unless the existing project has a working mobile renderer configuration that is clearly more appropriate. Avoid effects that exclude common Android devices.

Use a logical viewport around 1280×720 or an equivalent 16:9 reference size. Configure stretching and anchors so wider or taller devices expose additional background space without stretching gameplay or clipping UI.

Respect display cutouts and safe areas. Important HUD elements and touch controls must not sit underneath notches, rounded corners, or gesture-navigation regions.

## Secondary target

The game must remain playable in the desktop editor for development and automated testing.

Desktop controls:

- **WASD or arrow keys:** Move
- **Mouse:** Aim
- **Left mouse button:** Fire
- **Space:** Dash
- **E:** Interact or purchase
- **Escape:** Pause
- **Android Back action:** Pause, return, or show exit confirmation depending on context

---

# Android touch controls

Create a responsive mobile control scheme rather than mapping touch events directly to keyboard input.

## Left side

Implement a floating or fixed virtual joystick for movement:

- Appears beneath the left thumb or remains in a configurable anchored position
- Dead zone prevents accidental movement
- Movement magnitude can be analog
- Thumb indicator remains inside the joystick radius
- Releases cleanly if the touch is cancelled or the application loses focus

## Right side

Implement a right-side aim zone or virtual aim stick:

- Drag direction controls aim
- Holding the stick beyond its dead zone continuously fires
- Releasing stops firing
- Aim direction remains stable when the touch pointer changes
- Mild, configurable aim assistance may select the closest enemy within a narrow cone
- Aim assistance must never rotate toward an enemy behind the player's intended direction

## Action buttons

Provide:

- A large dash button near the right thumb
- A contextual interact/purchase button
- A pause button

Requirements:

- Use sufficiently large touch targets.
- Show pressed, disabled, and cooldown states.
- Support simultaneous movement, aiming, and dashing with multiple touch pointers.
- Track touch pointers by index or ID so one finger cannot steal another control.
- Do not fire when the player touches menus, upgrade cards, shop offers, or pause UI.
- Hide or dim controls when gameplay input is disabled.
- Keep desktop input and touch input behind one player-intent interface.

---

# Visual identity

The player is descending through an enormous ruined machine or buried tower.

Use an asset-light visual language that Codex can build entirely inside Godot:

- Dark charcoal and blue-black rooms
- Copper and muted-gold machinery
- Cyan player, projectiles, and positive effects
- Red enemies, danger telegraphs, and hostile projectiles
- Gold Loot doors
- Red Danger doors
- Cyan Shop doors
- Clean geometric silhouettes
- Strong contrast around interactive objects
- Subtle particles and light pulses
- Screen-space downward transitions between floors

Create placeholder art with Godot-native nodes and resources such as:

- Polygon2D
- Sprite2D with generated SVG or simple textures
- Line2D
- GradientTexture2D
- PointLight2D where affordable
- GPUParticles2D or CPUParticles2D with mobile-safe amounts
- AnimationPlayer
- Tweens
- CanvasModulate

Do not depend on purchased assets, external asset stores, or an internet connection. Do not leave broken resource paths if an optional effect is unavailable.

---

# Core gameplay

## Player

Use **CharacterBody2D** for the player.

Implement:

- Smooth top-down movement
- Acceleration and deceleration
- Analog movement support
- Configurable speed
- 100 starting health
- Configurable collision
- Aim direction independent of movement
- Ranged projectile weapon
- Approximately four shots per second initially
- Dash with a short burst of movement
- Brief dash invulnerability
- Dash cooldown
- Brief invulnerability after taking damage
- Damage flash
- Small knockback response
- Death signal and state
- Input locking while transitions or menus are active

The player must not move, shoot, dash, purchase, or select doors when the current game state disallows it.

## Weapon

The starting weapon should feel responsive:

- Fast, clearly visible cyan projectile
- Moderate damage
- Moderate projectile speed
- Small muzzle flash
- Impact flash or particles
- Configurable fire rate
- Configurable projectile lifetime
- Collision with walls and enemies
- No friendly fire

Use object pooling for projectiles. Avoid repeatedly instantiating and freeing projectiles during combat when a small reusable pool is sufficient.

## Health and damage

Create a reusable health component or composition-based C++ class that supports:

- Maximum and current health
- Damage
- Healing
- Invulnerability windows
- Death signal
- Health-changed signal
- Optional hit flash
- Optional knockback

Do not duplicate health logic separately across every actor.

---

# Enemies

Use **CharacterBody2D** for moving enemies and data-driven resources for configurable stats.

Implement at least three normal archetypes.

## 1. Chaser

- Moves toward the player
- Deals contact damage
- Low health
- Fast enough to force movement

## 2. Shooter

- Tries to maintain a preferred range
- Displays a clear warning before firing
- Fires red projectiles
- Medium health
- Repositions if the player becomes too close

## 3. Charger

- Faces the player
- Pauses during a visible wind-up
- Locks its charge direction
- Charges rapidly
- Cannot sharply turn during the charge
- Deals high damage
- Has a recovery period after missing

## Navigation

Enemies must navigate room obstacles reliably.

Use one of these approaches based on what works most robustly in the project:

- NavigationRegion2D and NavigationAgent2D with navigation data prepared for each handcrafted room
- A lightweight grid or steering system appropriate for small single-screen arenas

Do not accept enemies becoming permanently trapped behind common room obstacles. Add recovery behavior if an enemy makes no progress for a short period.

## Boss

Floor 8 contains a boss or substantial miniboss:

- Large readable silhouette
- Visible boss health bar
- At least two attack patterns
- Clearly telegraphed attacks
- A second phase or increased pressure below 50% health
- Summons minions or creates temporary hazard zones
- Cannot damage the player during room transition or victory state
- Defeating it triggers the victory flow

All enemies require:

- Configurable health, movement speed, damage, and rewards
- Damage feedback
- Death effect
- Coin or reward drops
- Signals for death and room tracking
- Floor-based difficulty scaling

---

# Combat-room state

A normal combat floor must follow this exact sequence:

1. The room scene is prepared.
2. Player appears at a valid spawn point.
3. Doors and exits remain locked.
4. A short **FLOOR X** banner appears.
5. Enemies become active.
6. The room remains locked while tracked enemies are alive.
7. The final enemy dies.
8. A brief pause emphasizes the final kill.
9. A satisfying **ROOM CLEARED** effect plays.
10. Exactly three destination doors become active.
11. Player evaluates the choices.
12. Player confirms one door.
13. All other doors lock immediately.
14. A downward transition plays.
15. The next floor loads.

Room completion must be event-driven. Do not use an unreliable global search for enemies every frame.

Prevent:

- Multiple room-complete events
- Multiple door selections
- Double floor increments
- Damage after combat has ended
- Old room enemies or projectiles surviving into the next room
- Input during transition

---

# Door-choice system

The three-door decision is the defining feature of DESCENT.

After clearing a combat room, reveal three physical doors along the lower side of the arena.

Each door displays:

- Type
- Icon or simple symbol
- Strong identifying color
- Short description
- Expected reward
- Risk level

Example text:

## LOOT

> Choose one of three upgrades.  
> Low risk / guaranteed power.

## DANGER

> Elite enemies. Double rewards.  
> High risk / high reward.

## SHOP

> Spend coins and recover.  
> Safe utility floor.

When the player approaches or taps a door:

- Highlight the door.
- Increase its glow or scale slightly.
- Show a compact preview card.
- Keep all three options readable before confirmation.

Door confirmation should work through either:

- Approaching a door and pressing the contextual interact button
- Tapping a door, then tapping a clear confirmation control

Do not let an accidental touch instantly commit the player without readable feedback.

When confirmed:

- Store the selected destination.
- Lock all doors.
- Play the selected door animation.
- Play a downward screen wipe or camera transition.
- Increment the floor exactly once.
- Load the next room according to the selected type.

The player cannot reroll the choices.

Normally present one Loot, one Danger, and one Shop door. Keep the system data-driven so other combinations can be added later.

---

# Floor types

## Standard combat floor

- Normal enemy encounter
- Coins and occasional healing drops
- Three doors after completion

## Loot floor

Create a lower-threat encounter followed by three upgrade cards.

- Player may choose exactly one upgrade.
- Cards must show name, icon or symbol, description, and rarity.
- Disable gameplay controls while the cards are open.
- Run upgrades reset at the end of the run.

Include at least:

- Increased weapon damage
- Increased attack speed
- Increased projectile speed
- One additional projectile
- Increased movement speed
- Reduced dash cooldown
- Increased maximum health with partial healing
- One level of projectile piercing
- Chance to ricochet
- Small healing after clearing a room

## Danger floor

Danger floors must be visibly and mechanically distinct:

- More enemies, elite enemies, hazards, or a modifier
- Modifier announced before combat
- Approximately double normal coins
- Additional Echoes
- Increased rare-upgrade chance

Implement several possible modifiers:

- Faster enemies
- Additional enemy projectiles
- Periodic floor spikes
- Reduced visibility
- Moving hazard
- Elite aura that strengthens nearby enemies

Avoid unfair combinations, unavoidable damage, and hazards appearing underneath the player without warning.

## Shop floor

Create a safe room containing three offers:

- Health restoration
- Current-run maximum health
- Displayed upgrade
- Random discounted upgrade
- One-use revive

Requirements:

- Show prices clearly.
- Disable unaffordable offers visibly.
- Confirm purchases through touch or the interact action.
- Deduct currency exactly once.
- Apply effects immediately.
- Prevent repeat purchase unless the offer is explicitly repeatable.
- Coins reset when the run ends.
- Three destination doors become available after shopping.

---

# Room variety

Build at least eight handcrafted room scenes or layouts:

1. Open arena
2. Central pillar
3. Four-corner obstacles
4. Narrow crossing lanes
5. Circular or ring path
6. Split room with two passages
7. Hazard-grid arena
8. Dense-cover room

Represent rooms as reusable **PackedScene** resources with explicit markers for:

- PlayerSpawn
- EnemySpawns
- DoorSpawns
- RewardSpawn
- HazardSpawns
- Navigation region or navigation data
- Camera or arena bounds if required

Room selection should combine:

- Layout
- Enemy composition
- Spawn pattern
- Hazard
- Floor type
- Accent color
- Optional modifier

Do not repeat the same room layout on consecutive floors.

Validate spawn positions so the player, enemies, rewards, and doors never appear inside walls, hazards, or each other.

Prefer intentional handcrafted room scenes over fully procedural geometry. Variety should come from combining layouts, encounters, hazards, and modifiers.

---

# Run structure and balance

Target eight floors:

- **Floors 1–2:** Introductory encounters
- **Floors 3–4:** Mixed enemy groups
- **Floors 5–6:** Hazards and elite enemies
- **Floor 7:** Difficult pre-boss encounter
- **Floor 8:** Boss

The chosen doors determine the route.

Target timings:

- Normal combat room: 20–35 seconds
- Danger room: 30–45 seconds
- Loot decision: 5–10 seconds
- Shop visit: 10–20 seconds
- Complete successful run: 3–6 minutes

Scale difficulty through:

- Enemy count
- Enemy composition
- Movement speed within reasonable limits
- Attack frequency
- Damage
- Elite variants
- Hazards
- Room modifiers

Do not scale only enemy health. Avoid turning later floors into slow damage sponges.

Use a seeded RandomNumberGenerator for run generation where practical. Store the current run seed and provide a development option to replay it.

---

# Progression and save data

Use two currencies.

## Coins

- Earned during the current run
- Spent in shops
- Lost when the run ends

## Echoes

- Permanent currency
- Awarded after death and victory
- Increased by reaching deeper floors
- Increased by completing Danger rooms
- Saved between application launches

After death, show:

- Floor reached
- Enemies defeated
- Coins collected
- Danger rooms completed
- Echoes earned
- Total Echoes
- Restart button
- Permanent-upgrade button
- Main-menu button

Create at least five permanent unlocks:

- +5 starting maximum health
- +5% starting weapon damage
- +5% starting movement speed
- Unlock the Ricochet run upgrade
- Unlock a once-per-run Second Wind revive

## Save system

Use a small versioned JSON save file under Godot's **user://** location, such as:

> user://descent_save_v1.json

Requirements:

- Include a schema version.
- Handle a missing file.
- Validate loaded field types and ranges.
- Handle malformed or corrupted JSON safely.
- Fall back to defaults instead of crashing.
- Never save current-run upgrades as permanent unlocks.
- Write to a temporary file and replace the main save where practical to reduce corruption risk.
- Save when a permanent purchase is made and when a run ends.
- Handle application pause or shutdown safely.
- Include a development-only reset-save function.

Do not use absolute desktop paths for save data; the same code must work in an Android export.

---

# Godot project structure

Keep the root **project.godot** in the project root. Organize game content beneath:

> res://descent/

Recommended structure:

- **assets/**
  - generated/
  - icons/
  - audio/
- **autoload/**
- **data/**
- **scenes/**
  - actors/
  - enemies/
  - rooms/
  - ui/
  - effects/
- **src/**
  - actors/
  - combat/
  - rooms/
  - progression/
  - ui/
  - utilities/
  - register_types.cpp
- **include/descent/**
  - actors/
  - combat/
  - rooms/
  - progression/
  - ui/
  - utilities/
- **gdextension/**
  - descent.gdextension
- **bin/**
  - platform-specific extension libraries generated by SCons
- **third_party/godot-cpp/** or **godot-cpp/**
  - a pinned compatible `godot-cpp` checkout
- **SConstruct**
- **tests/**

Create a small scene structure:

- **boot.tscn**
- **main_menu.tscn**
- **gameplay.tscn**

The gameplay scene should retain the run-level systems and replace only the current room instance. Do not make a separate top-level scene for every floor.

## Suggested autoloads

Use only the autoloads that are genuinely useful:

- **GameFlow:** High-level state transitions and scene routing
- **RunState:** Floor, run seed, coins, upgrades, and run statistics
- **SaveManager:** Permanent data loading and saving
- **AudioManager:** Optional global sound control

Avoid turning every component into a global singleton.

## Suggested gameplay responsibilities

- **GameFlow:** State machine and high-level transitions
- **RunState:** Current run data and reset
- **RoomManager:** Current room, tracked enemies, and completion
- **RoomSelector:** Layout and encounter selection
- **DoorChoiceController:** Door generation and selection lock
- **PlayerController:** Movement and player intent
- **PlayerCombat:** Firing and combat modifiers
- **HealthComponent:** Reusable damage, healing, and death
- **Enemy C++ classes:** Individual behavior while sharing reusable components
- **RewardManager:** Coins, healing, and upgrade drops
- **ShopController:** Offers and purchases
- **MetaProgression:** Permanent upgrade rules
- **SaveManager:** Versioned persistence
- **HUD:** Run-state presentation
- **CameraEffects:** Shake and impact feedback

Use Godot signals for discrete events such as:

- health_changed
- actor_died
- enemy_spawned
- enemy_defeated
- room_cleared
- door_selected
- coins_changed
- upgrade_selected
- run_ended

Connect signals deliberately. Avoid polling the scene tree every frame or repeatedly calling broad node searches.

## Data-driven content

Use custom Godot **Resource** classes and .tres assets for:

- EnemyData
- UpgradeData
- RoomData
- DoorDestinationData
- ShopOfferData
- DifficultyData

Use exported typed properties for values designers should tune.

All custom nodes and resources must be registered through the GDExtension initialization entry point. The `.gdextension` file must map the Linux editor/runtime library and Android libraries for the exported architectures. Do not commit generated object files. Do not hide essential game logic in scene-embedded scripts.

---

# Game-state model

Implement an explicit enum or equivalent state model:

- BOOT
- MAIN_MENU
- ROOM_INTRO
- COMBAT
- ROOM_CLEARED
- DOOR_SELECTION
- TRANSITION
- SHOP
- UPGRADE_SELECTION
- PAUSED
- PLAYER_DEAD
- VICTORY

Every input path must respect the current state, including:

- Desktop controls
- Touch controls
- Door selection
- Shop purchase
- Pause
- Android Back action

State changes must be centralized enough to prevent contradictory states, but the implementation should remain simple and readable.

---

# User interface

Build UI using **Control** nodes under **CanvasLayer** where appropriate.

The gameplay HUD must show:

- Health
- Floor
- Coins
- Echoes earned during the current run
- Dash cooldown
- Current room type
- Current danger modifier
- Boss health when applicable

Additional screens:

- Main menu
- Permanent-upgrade menu
- Pause menu
- Run-upgrade selection
- Shop interface
- Death summary
- Victory summary
- Optional first-run control hint

Mobile UI requirements:

- Use anchors and containers.
- Respect safe-area padding.
- Avoid tiny text.
- Use large touch targets.
- Do not place important labels behind touch controls.
- Keep the center of the arena visually clear.
- Scale appropriately across common Android aspect ratios.
- Prevent touch events from passing through menus into gameplay.
- Give buttons visible focus, pressed, selected, disabled, and cooldown states.

Pause gameplay when the application loses focus or moves to the background. Resume through a clear pause overlay rather than immediately returning to combat.

---

# Performance requirements

Target a stable 60 FPS on a mid-range Android device.

Use practical budgets:

- Approximately 25 active normal enemies at maximum
- Approximately 80 active projectiles at maximum
- Modest particle counts
- Minimal full-screen transparent overdraw
- No unnecessary real-time shadows

Requirements:

- Pool player projectiles, enemy projectiles, coins, and frequently used effects.
- Avoid allocations in per-frame hot paths.
- Avoid repeated get_nodes_in_group calls inside _process or _physics_process.
- Cache frequently used node references with onready variables.
- Use physics processing only where required.
- Remove or disable off-state processing.
- Keep collision shapes simple.
- Configure collision layers and masks intentionally.
- Avoid dozens of expensive PointLight2D nodes.
- Keep shaders mobile-safe.

Use the Godot profiler where available and document any obvious bottleneck discovered.

---

# Feel and polish

Even with placeholder assets, implement:

- Responsive player acceleration and deceleration
- Brief hit stop on important impacts
- Player and enemy damage flashes
- Enemy knockback where appropriate
- Muzzle flash
- Projectile impact effects
- Configurable camera shake
- Coin collection animation
- Door hover or selection animation
- Room-introduction banner
- Room-clear animation
- Downward floor transition
- Clear enemy attack telegraphs
- Subtle low-health warning

Optional:

- Short generated sound effects
- Device vibration for damage, dash, boss death, and door confirmation

If haptics are implemented, keep them brief, optional, and disabled on unsupported platforms. Do not request broad device permissions.

Polish systems must fail gracefully if an optional audio stream, material, particle effect, or vibration feature is unavailable.

---

# Development and debugging tools

Add development-only shortcuts or a debug panel for:

- Instantly clearing the room
- Damaging or healing the player
- Adding coins
- Adding Echoes
- Jumping to a floor
- Forcing door selection
- Replaying a run seed
- Resetting save data

Ensure these are hidden or disabled in non-debug exports.

---

# Android configuration and export

Configure the project for Android:

- Landscape orientation
- Touch input enabled
- Compatibility or appropriate mobile renderer
- Sensible stretch and safe-area behavior
- Application name: DESCENT
- A valid prototype package identifier
- No unnecessary permissions
- Debuggable development export
- App icon generated from simple project artwork if practical

If the Android SDK and Godot export templates are available:

1. Create or update **export_presets.cfg**.
2. Export a debug APK.
3. Place it under:

   **builds/android/descent-debug.apk**

4. Report the exact APK path and export command.

If Android tooling is unavailable:

- Do not pretend the APK was built.
- Still create a valid Android export preset where possible.
- Report the precise missing dependency or configuration.
- Document the shortest commands or editor steps needed to finish the export.

Do not embed secrets, signing passwords, personal keystores, or machine-specific SDK paths in committed project files.

---

# Testing

Create lightweight tests or a deterministic smoke-test harness without adding a third-party testing dependency.

At minimum, verify:

- New run initializes Floor 1 exactly once.
- Player receives both desktop and touch intent correctly.
- Player cannot move or shoot while paused.
- Damage and invulnerability windows work.
- Each enemy can spawn, attack, take damage, and die.
- Room clears only when all tracked enemies are dead.
- Exactly three doors appear.
- Door choice commits only once.
- Each door type produces the correct destination behavior.
- Floor increments only once per transition.
- Same room does not repeat consecutively.
- Upgrade selection permits exactly one choice.
- Shop purchase checks price and deducts coins once.
- Run upgrades reset after death.
- Permanent upgrades persist.
- Corrupted save data falls back safely.
- Boss death triggers victory.
- Android Back action behaves correctly.
- Touch UI does not fire through menu controls.

Use headless validation where supported. Locate the actual Godot executable first, then run the equivalent of:

    godot --headless --path . --editor --quit

Also launch the main scene or a smoke-test scene headlessly when practical. Capture extension-loading errors, missing resources, invalid node paths, native error messages, and runtime exceptions. Fix them before declaring completion.

Do not claim that touch behavior was tested on physical hardware unless it actually was. Clearly distinguish editor simulation, headless validation, emulator testing, and real-device testing.

---

# Implementation order

Follow this order:

1. Inspect repository instructions and existing project state.
2. Establish the Godot project and Android-compatible project settings.
3. Create folders, input actions, collision layers, autoloads, and data resources.
4. Implement player movement, aiming, firing, dash, health, and camera.
5. Implement desktop controls and Android touch controls through the same intent interface.
6. Implement projectile pooling and shared health/damage behavior.
7. Implement Chaser, Shooter, and Charger enemies.
8. Implement one complete combat room and room-clear flow.
9. Implement the three-door decision and downward transition.
10. Implement Loot, Danger, and Shop behavior.
11. Add all room layouts, encounter variation, and difficulty scaling.
12. Implement run upgrades.
13. Implement death, restart, victory, Echoes, saving, and permanent progression.
14. Implement the Floor 8 boss.
15. Complete responsive UI and Android lifecycle handling.
16. Add visual feedback and mobile-safe polish.
17. Run headless validation and complete-loop smoke tests.
18. Configure Android export and build a debug APK if tooling is available.
19. Write project documentation.

Validate after every major stage. Do not build more features on top of compiler errors, GDExtension loading errors, or broken scene references.

---

# Acceptance criteria

The task is complete only when all applicable requirements below pass:

- The project opens in the installed Godot 4.x version.
- The native extension compiles without errors and loads without unresolved symbols or missing-library errors.
- No required scene or resource references are missing.
- The configured main scene starts a new game.
- The game works with desktop controls in the editor.
- Touch controls support simultaneous move, aim/fire, and dash.
- UI touches do not leak into gameplay.
- The player can move, aim, shoot, dash, take damage, heal, and die.
- Three distinct normal enemy types function.
- Combat rooms lock and clear correctly.
- Exactly three readable doors appear after applicable rooms.
- Loot, Danger, and Shop choices create meaningfully different outcomes.
- A selected door cannot be triggered twice.
- Floor progression does not duplicate or skip floors.
- Room layouts do not repeat consecutively.
- Run upgrades affect gameplay and reset after the run.
- Coins can be earned and spent and reset after the run.
- Echoes and permanent upgrades survive a game restart.
- Missing or malformed save data does not crash the game.
- The death screen reports run results.
- Floor 8 contains a functioning boss.
- Boss defeat produces a victory screen.
- Android Back pauses or navigates safely.
- Application backgrounding does not leave combat running.
- A complete run can be played from menu to death or victory without editor intervention.
- Ordinary gameplay produces no runtime errors.
- UI remains usable at multiple phone aspect ratios.
- Performance-sensitive objects are pooled.
- An Android export preset exists.
- A debug APK is produced when the required local Android tooling is available.

---

# Required documentation

Create **README.md** at the project root containing:

- Game overview
- Controls for Android and desktop
- Godot version
- How to open and run the project
- Main scene
- Project structure
- Architecture overview
- How to add a room
- How to add an enemy
- How to add an upgrade
- How to tune difficulty
- Save-data location and schema
- How to reset development save data
- How to run validation
- How to export the Android APK
- Known limitations

Also create **descent/IMPLEMENTATION_STATUS.md** containing:

- Completed features
- Incomplete features
- Tests executed
- Test results
- Android export result
- Any precise blockers

---

# Final Codex response

When implementation is complete, provide a concise report with:

1. What was created
2. Main scene to run
3. Android and desktop controls
4. Important architecture decisions
5. Validation and tests actually executed
6. Debug APK path, if built
7. Exact Android export blocker, if an APK could not be built
8. Remaining limitations

Do not report planned work as completed work. Do not claim tests or device validation that were not actually performed.

Make reasonable decisions independently. Prioritize a complete, enjoyable, mobile-playable vertical slice over unfinished breadth or unnecessary abstractions.
