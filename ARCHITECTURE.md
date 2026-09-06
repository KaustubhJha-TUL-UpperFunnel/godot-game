# DESCENT — architecture map

Where everything lives, and why it lives there.

DESCENT is a pure GDScript + scene Godot 4.7 project. There is no native code:
every actor, effect, and HUD element is a node you can open, select, and edit in
the editor. This document is the index.

---

## 1. The three scenes

The whole game is three top-level scenes. Everything else is instanced inside
one of them. `SceneRouter` is the only thing that swaps between them.

| Scene | Script | Role |
| :--- | :--- | :--- |
| `descent/scenes/boot.tscn` | `scripts/ui/boot_screen.gd` | Title splash; warms the resource cache, then routes to the menu |
| `descent/scenes/main_menu.tscn` | `scripts/ui/main_menu.gd` | Start a run, spend echoes, quit |
| `descent/scenes/gameplay.tscn` | `scripts/systems/gameplay_controller.gd` | The entire run loop |

### `gameplay.tscn` node tree

This is the map worth memorising. Node names here are load-bearing: the
controller reaches for them by path.

```
Gameplay                        GameplayController — the run state machine
├── LevelHost                   holds this floor's level scene from assets/scenes/levels/
├── Doors                       hidden until a room is cleared
│   ├── Loot                    room_door.tscn + data/doors/loot.tres
│   ├── Danger                  room_door.tscn + data/doors/danger.tres
│   └── Shop                    room_door.tscn + data/doors/shop.tres
├── Actors                      draw order: hazards under enemies under bolts
│   ├── Hazards                 Hazard instances, spawned and freed per room
│   ├── Enemies                 EnemyBase instances, spawned and freed per room
│   ├── Player                  player.tscn
│   └── Projectiles             Projectile instances
├── FxDirector                  parents every burst and damage number
├── Camera                      Camera2D + CameraShake
├── HitStop                     squeezes Engine.time_scale on heavy hits
├── Systems
│   ├── SpawnDirector           decides the encounter
│   ├── UpgradeCatalog          run-upgrade pool and effects
│   └── ShopCatalog             merchant pricing and purchases
├── Timers
│   ├── IntroTimer              room intro beat
│   └── ClearedTimer            room-cleared beat
├── UI                          CanvasLayer
│   ├── Hud                     vitals, run counters, upgrade list, boss bar
│   ├── Hotbar                  the six ability slots
│   ├── DoorPrompt              "PRESS E TO ENTER"
│   ├── ShopPanel               merchant storefront
│   ├── Announcement            floor intro and room-cleared banner
│   ├── UpgradeSelection        the three reward cards
│   ├── ToastLayer              one-line status messages
│   ├── TouchControls           twin virtual sticks, touch devices only
│   ├── PauseMenu               also owns the pause key
│   └── RunSummary              end-of-run report
└── TransitionLayer             CanvasLayer, layer 5
    └── FloorTransition         the fall-to-the-next-floor wipe
```

### The room loop

```
begin_room()
   │
   ├─ shop room ──────────────► SHOP ──────────────┐
   │                                               │
   └─ everything else ─► INTRO ─► COMBAT ─► CLEARED┤
                                                   │
                          loot room ─► REWARD ─────┤
                                                   │
                                                   ▼
                                                 DOORS
                                                   │
                                                   ▼
                                             TRANSITION ─► begin_room()
```

Two states sit outside that cycle: `FINISHED` (death, victory, or abandon, which
shows `RunSummary`) and the boss room, which skips doors entirely and goes
straight to `FINISHED` on the Warden's death.

---

## 2. Directory map

```
descent/
├── assets/
│   ├── game/           pixel art PNGs (knight, enemies, doors, hotbar icons)
│   ├── maps/           the fifty painted room backdrops
│   └── scenes/levels/  one Level scene per map, generated then hand-reviewed
├── data/               .tres gameplay data, grouped by kind
│   ├── difficulty/     one per floor: enemy count, pressure, elite chance
│   ├── doors/          the three door destinations
│   ├── enemies/        per-archetype base stats
│   ├── shop/           merchant offers
│   └── upgrades/       the ten run upgrades
├── resources/
│   ├── fx/             soft_circle.tres, hard_circle.tres (shared gradient textures)
│   └── ui/             descent_theme.tres (fonts, buttons, panels)
├── scenes/
│   ├── boot.tscn  main_menu.tscn  gameplay.tscn
│   ├── actors/         player, four enemies, projectile
│   ├── fx/             blob shadow, impact burst, damage number, floor transition
│   ├── ui/             every Control scene
│   └── world/          doors and props
└── scripts/            mirrors scenes/, plus autoload/, components/, data/, systems/
```

Scripts sit in the folder matching their scene, so the script for
`scenes/world/room_door.tscn` is `scripts/world/room_door.gd`. The extra
`scripts/` folders — `autoload/`, `components/`, `data/` — hold code with no
scene of its own.

---

## 3. Autoloads

Registered in `project.godot`, available everywhere.

| Autoload | Script | Owns |
| :--- | :--- | :--- |
| `SaveManager` | `scripts/autoload/save_manager.gd` | Echoes and the five permanent tracks; disk I/O |
| `RunState` | `scripts/autoload/run_state.gd` | Everything scoped to one run: floor, coins, upgrades, room type |
| `EventBus` | `scripts/autoload/event_bus.gd` | Presentation-only signals (toast, shake, hitstop, damage number, burst) |
| `SceneRouter` | `scripts/autoload/scene_router.gd` | The only place that changes the top-level scene |

The split matters: `SaveManager` survives runs, `RunState` does not, and
`EventBus` never affects rules. If a signal changes what happens in the game it
belongs on a node, not on `EventBus`.

---

## 4. The player

`descent/scenes/actors/player.tscn`, script `scripts/actors/player_avatar.gd`.

```
Player                    CharacterBody2D, group "player"
├── CollisionShape2D      17px circle
├── Shadow                blob_shadow.tscn
├── Facing                mirrored on X so left-facing reuses the same art
│   └── Body              tweened for the attack lunge
│       ├── Slash         knight_slash.png — the crescent arc
│       └── Sprite        knight.png — the AnimationPlayer target
├── MeleeHitbox           Area2D + a Cone CollisionPolygon2D, live only mid-swing
├── Health                HealthComponent
├── Mana                  ManaComponent
├── Flash                 HitFlash
├── Input                 PlayerInput — keyboard, mouse, and touch in one place
├── DashCooldown / FireCooldown / IceCooldown    Timers
├── DashTrail             CPUParticles2D
└── AnimationPlayer       "idle", "walk"
```

Two rules keep the animation system from fighting the gameplay code:
`AnimationPlayer` only ever touches `Facing/Body/Sprite`, and gameplay motion
(the lunge) only ever tweens `Facing/Body`.

The six hotbar slots are one enum, `PlayerAvatar.Slot`. A key press, a click on
the hotbar, and a thumb on a touch button all end up in `activate_slot(index)`,
so there is exactly one code path per ability.

### Components

Small nodes under `scripts/components/`, droppable under any actor:

- `health_component.gd` — hit points, invulnerability window, `depleted` signal
- `mana_component.gd` — regenerating spell resource
- `hit_flash.gd` — modulate flash on hit
- `melee_hitbox.gd` — the sword's swing volume

---

## 5. Enemies

All four extend `EnemyBase` (`scripts/actors/enemy_base.gd`), which owns stats,
movement, anti-stuck steering, hit reactions, and death payout. A subclass only
implements `_steer()`.

| Scene | Script | Stats | Animation | Behaviour |
| :--- | :--- | :--- | :--- | :--- |
| `enemy_slime.tscn` | `enemy_slime.gd` | `data/enemies/chaser.tres` | `hop` | Hops toward the player in crouch/leap/splat phases |
| `enemy_goblin.tscn` | `enemy_goblin.gd` | `data/enemies/charger.tres` | `stride` | Telegraphs, then lunges with daggers |
| `enemy_sorcerer.tscn` | `enemy_sorcerer.gd` | `data/enemies/shooter.tres` | `hover` | Keeps range and fires bolts |
| `enemy_boss.tscn` | `enemy_boss.gd` | `data/enemies/boss.tres` | `loom` | Two phases; radial volleys, summons, ground hazards |

Enemies never spawn anything themselves. They emit `shot_requested`,
`summon_requested`, or `hazard_requested`, and `GameplayController` decides what
that means — which is what lets the CROSSFIRE modifier add extra bolts to every
shot in the game without touching a single enemy script.

---

## 6. The world

A room is one **level scene** in `descent/assets/scenes/levels/`, one per painted
map in `descent/assets/maps/`. `Gameplay/LevelHost` (`scripts/world/level_host.gd`)
holds whichever one the run is in and answers every positional question about
it; `scripts/systems/level_library.gd` decides which one a floor gets.

### The two kinds of level

`Level.kind` is the load-bearing field.

| Kind | Camera | Floor | Falling |
| :--- | :--- | :--- | :--- |
| `FLAT` | top-down | the whole `WalkableRegion` rect | impossible; actors are clamped |
| `VERTICAL` | side-on | only where a `LevelPlatform` is | a `DeathZone` under the lowest platform |

Nineteen maps are flat and thirty-one are vertical. Vertical levels are authored
and marked but **not yet in rotation**: the knight still moves top-down with no
gravity or jump, so `LevelLibrary.INCLUDE_VERTICAL` is `false` until platformer
movement lands.

### Level node tree

Positions are authored in the map's own pixel space (1536×1024, origin at the
background's top-left), so a coordinate in the scene is the same coordinate you
would measure in an image editor. The camera zooms out to frame the room.

```
Level                     level.gd — kind, hazard_kind, theme, reviewed
├── Background            Sprite2D, top-left anchored, the map PNG
├── Walls                 StaticBody2D, group "walls", the outer frame
├── Platforms             LevelPlatform children (VERTICAL only)
├── Hazards               HazardZone children — lava, sludge, arcane vents
├── DeathZones            DeathZone children (VERTICAL only)
├── WalkableRegion        Area2D clamp rect (FLAT only)
├── PlayerStart           Marker2D
├── SpawnPoints           Marker2D children
└── DoorAnchors           Loot / Danger / Shop Marker2D
```

`LevelHost` exposes `walkable_bounds()`, `player_start()`, `spawn_positions()`,
`is_blocked()`, and `door_anchor()`, which is everything the spawn director, the
projectiles, and the player's clamp read.

### Generating and reviewing levels

`tools/gen_levels.py` reads each map PNG, finds the ledges, hazard pools, and the
pit with `tools/map_analysis.py`, and writes the scene. Supporting scripts:

| Command | Purpose |
| :--- | :--- |
| `python tools/gen_levels.py` | regenerate all fifty scenes |
| `python tools/gen_levels.py map_01_fire_vertical.png` | regenerate one |
| `python tools/map_debug.py` | draw what the detector found over the art, into `tools/_debug/` |
| `python tools/check_levels.py` | assert the scene contract on all fifty, by reading the `.tscn` text |
| `godot --headless --script res://tools/validate_levels.gd` | load all fifty in the engine and call the accessors the game uses |

Detection is approximate and meant to be corrected by hand. Every level starts
with `reviewed = false`, which shows as a scene warning in the editor; tick it
once the geometry has been checked, and `gen_levels.py` will then skip that level
unless `--force` is passed. `LevelPlatform`, `HazardZone`, and `DeathZone` draw
their volumes in the editor only, so review is a matter of dragging handles.

### Props

| Scene | Script | Notes |
| :--- | :--- | :--- |
| `spike_trap.tscn` | `spike_trap.gd` | `retracted` / `thrust`; drop into a level that wants one |
| `torch.tscn` | `torch.gd` | `flicker`; sconce can be hidden to sit over baked lighting |
| `hazard.tscn` | `hazard.gd` | `telegraph` then `erupt`; the runtime-spawned eruption used by SPIKE PULSE and the boss, not the authored `HazardZone` |
| `room_door.tscn` | `room_door.gd` | `idle` / `highlight` / `open`; owns its click target and proximity area |

---

## 7. UI

Every screen is its own scene under `scenes/ui/`, scripts under `scripts/ui/`.

| Scene | Purpose | Animations |
| :--- | :--- | :--- |
| `hud.tscn` | Portrait, health and mana bars, floor and room header, coins, echoes, active upgrades, boss bar | — |
| `stat_bar.tscn` | Reusable bar with a chip layer that trails behind after damage | — |
| `enemy_health_bar.tscn` | Overhead enemy bar (`health_bar.gd`); hidden at full health | — |
| `hotbar.tscn` | Six slots in an `HBoxContainer` | — |
| `hotbar_slot.tscn` | Icon, hotkey, cooldown sweep, charge count | `idle`, `hover`, `use`, `ready` |
| `announcement.tscn` | Floor intro and room-cleared banner | `reveal`, `dismiss` |
| `toast_layer.tscn` | One-line messages, driven by `EventBus.toast_requested` | `pop`, `fade_out` |
| `door_prompt.tscn` | Proximity hint for doors | — |
| `upgrade_selection.tscn` | The three-card reward screen | — |
| `upgrade_card.tscn` | One card; border colour comes from rarity | `deal`, `take` |
| `shop_panel.tscn` | Merchant storefront | — |
| `shop_offer_row.tscn` | One purchasable item | — |
| `permanent_upgrades.tscn` | Between-runs echo shop; rows built from `SaveManager.TRACKS` | — |
| `permanent_upgrade_row.tscn` | One track with level pips | — |
| `pause_menu.tscn` | Pause overlay; also owns the pause key | — |
| `run_summary.tscn` | End-of-run report | — |
| `touch_controls.tscn` | Twin virtual sticks | — |
| `scene_fade.tscn` | Cross-scene fade, owned by `SceneRouter` | — |

`resources/ui/descent_theme.tres` is set as the project-wide theme, so buttons,
panels, and fonts are consistent without per-scene overrides.

---

## 8. Effects

| Scene / node | Script | Animation | Triggered by |
| :--- | :--- | :--- | :--- |
| `fx/impact_burst.tscn` | `fx/impact_burst.gd` | — | `EventBus.burst_requested` |
| `fx/damage_number.tscn` | `fx/damage_number.gd` | `float_up` | `EventBus.damage_number_requested` |
| `fx/floor_transition.tscn` | `fx/floor_transition.gd` | `fall` | Awaited by the controller during `TRANSITION` |
| `fx/blob_shadow.tscn` | — | — | Instanced under actors |
| `Camera` | `systems/camera_shake.gd` | — | `EventBus.shake_requested` |
| `HitStop` | `systems/hit_stop.gd` | — | `EventBus.hitstop_requested` |
| `FxDirector` | `systems/fx_director.gd` | — | Parents bursts and numbers, capped at 90 live effects |

Bursts and damage numbers are parented to `FxDirector`, not to the actor that
caused them, so an enemy freeing itself never takes its own death particles with
it.

---

## 9. Systems

Plain nodes under `Gameplay/Systems`, scripts in `scripts/systems/`.

| Node | Script | Responsibility |
| :--- | :--- | :--- |
| — | `gameplay_controller.gd` | The room state machine; wires actors to UI |
| `SpawnDirector` | `spawn_director.gd` | Encounter size, archetype mix, elite rolls, spawn placement |
| `UpgradeCatalog` | `upgrade_catalog.gd` | The upgrade pool and the one `match` that applies effects |
| `ShopCatalog` | `shop_catalog.gd` | Pricing and purchases |
| — | `resource_directory.gd` | Loads every `.tres` in a folder |

The three catalogs read their contents from `descent/data/` at runtime rather
than from hand-listed arrays in the scene, so adding a data file is enough to
register it.

---

## 10. Data resources

Script classes in `scripts/data/`, instances in `descent/data/`.

| Class | Folder | Fields |
| :--- | :--- | :--- |
| `EnemyData` | `enemies/` | health, speed, damage, coin reward |
| `UpgradeData` | `upgrades/` | `upgrade_id`, name, description, rarity, value |
| `ShopOfferData` | `shop/` | kind, name, description, base price |
| `DifficultyData` | `difficulty/` | `floor_number`, enemy count, pressure, elite chance |
| `DoorDestinationData` | `doors/` | destination type, name, risk copy, accent colour |

`UpgradeData.upgrade_id` is the stable key tying a `.tres` to its effect:

| id | Upgrade | Effect |
| :--- | :--- | :--- |
| 0 | Copper Bore | +25% weapon damage |
| 1 | Rapid Relay | +22% attack speed |
| 2 | Accelerator | +25% projectile speed |
| 3 | Split Chamber | +1 projectile |
| 4 | Fleet Gears | +12% move speed |
| 5 | Dash Coils | −18% dash cooldown |
| 6 | Vital Casing | +20 max health, partial heal |
| 7 | Phase Needle | +1 pierce |
| 8 | Ricochet Core | 25% ricochet — locked behind a permanent track |
| 9 | Recovery Loop | Heal after each cleared room |

---

## 11. Physics layers

Defined in `project.godot`; `Projectile` picks its layer and mask from its
`friendly` flag, which is why one scene covers both directions of fire.

| Bit | Layer | Used by |
| :--- | :--- | :--- |
| 1 | `player` | `Player` |
| 2 | `enemies` | Every `EnemyBase` |
| 3 | `walls` | Level perimeter walls and every `LevelPlatform` |
| 4 | `player_attacks` | Melee hitbox, friendly projectiles |
| 5 | `enemy_attacks` | Hostile projectiles, `Hazard`, `HazardZone`, `DeathZone` |
| 6 | `interactables` | Door proximity areas |

---

## 12. Controls

| Action | Keyboard / mouse | Touch |
| :--- | :--- | :--- |
| Move | `WASD` / arrows | Left stick |
| Aim | Mouse | Right stick |
| Sword | `LMB` or `1` | Hold right stick |
| Fireball | `2` | Hotbar slot 2 |
| Frost Nova | `3` | Hotbar slot 3 |
| Dash | `Space` or `4` | Hotbar slot 4 |
| Health potion | `5` | Hotbar slot 5 |
| Mana elixir | `6` | Hotbar slot 6 |
| Interact | `E` | Tap the door |
| Pause | `Esc` | — |

Debug shortcuts, active in debug builds only: `F1` clear room, `F2` hurt,
`F3` heal, `F4` coins, `F5` echoes, `F6` next floor, `F7` reset save.

---

## 13. Common changes

**Add an enemy.** Duplicate an enemy scene, point it at a new `EnemyData`, write
a script extending `EnemyBase` that implements `_steer()`, then add it to
`SpawnDirector._scene_for()`.

**Add a run upgrade.** Drop a new `UpgradeData` `.tres` into `data/upgrades/`
with an unused `upgrade_id`, add a `match` arm in `UpgradeCatalog.apply()`, and
add the stat hook to `PlayerAvatar` if it needs one. The pool picks it up
automatically.

**Add a level.** Drop the map PNG into `descent/assets/maps/` following the
`map_NN_theme_descriptor_(vertical|flat)` convention, then run
`python tools/gen_levels.py`. `LevelLibrary` picks it up from the folder.

**Retune difficulty.** Edit the `.tres` files in `data/difficulty/` — no code.

**Resize the play area.** Move the `WalkableRegion` shape in that level's scene.
Everything that clamps to the floor reads from it.

**Add a screen effect.** Emit the matching `EventBus` signal from wherever the
event happens. Nothing needs a reference to the camera or the HUD.
