# TrailBeacon

A World of Warcraft: Forever addon for placing, customizing, sharing, and navigating to custom map/minimap markers.

## Target Environment

- **Game**: World of Warcraft: Forever
- **Beta build tested against**: 1.60.1.69893
- **API family**: Retail/Midnight-era API (confirmed via Blizzard's WoW UI Discord statement, Sept 16 2026: "WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5"). This is **not** the Classic Era API. Use `C_Map`, `C_Timer`, `C_AddOns`, etc. — the namespaced modern API, not legacy globals like `GetPlayerMapPosition` (global, pre-namespace form).
- **Source reference**: `https://github.com/Gethe/wow-ui-source/tree/forever` — this branch has been cloned and verified to contain real, current API documentation stubs at `Interface/AddOns/Blizzard_APIDocumentationGenerated/`. Consult this first for any function signature question rather than assuming from general WoW addon knowledge, since Forever's API surface is new and may not match prior WoW versions' conventions in Claude's training data.

### Confirmed available API (verified against the branch above)

- `C_Map.GetPlayerMapPosition(uiMapID, unitToken)` → returns `vector2` position (`Vector2DMixin`). Only works for player and party members.
- `C_Map.GetWorldPosFromMapPos(uiMapID, mapPosition)` → returns `continentID, worldPosition` (yard-based). **This is the conversion to use for distance calculations** — do not compute distance from raw 0–100% map coordinates, since zone scale varies.
- `C_Map.GetMapPosFromWorldPos(continentID, worldPosition, overrideUiMapID)` → inverse of the above.
- `C_Map.GetBestMapForUnit(unitToken)` → returns current `uiMapID` for a unit.
- `C_Map.SetUserWaypoint(point)` / `C_Map.GetUserWaypoint()` / `C_Map.ClearUserWaypoint()` — Blizzard's native waypoint system exists in this build. **Evaluate whether to build the tracking arrow on top of this native system rather than fully from scratch** before writing custom projection/rotation math.
- `C_Timer` namespace confirmed present (multiple `*TimerDocumentation.lua` files found in the branch).
- `C_AddOns` namespace confirmed present (`AddOnsDocumentation.lua`).

### Secret values — known constraint, already designed around

Forever includes Blizzard's "Midnight addon disarmament" system, including secret-wrapped values. Relevant predicate confirmed in source: `SecretOnRestrictedMaps` — *"Guarded APIs and events produce secret values when the player is on an addon-restricted map such as a dungeon or raid."*

**Design decision**: rather than attempt to detect or work around secret values on a case-by-case basis, **the tracking arrow feature must be fully disabled while the player is inside an instance (dungeon or raid)**, full stop — no partial function, no silent failure, no attempted fallback math. Detect instance state (e.g. `IsInInstance()` or equivalent current API) and hide/disable the arrow frame entirely when true, re-enabling automatically on exit. Do not show the arrow in a broken or stale state.

**Markers themselves (map/minimap placement, viewing, editing) are NOT affected by this restriction** and must work normally inside instances — only the tracking arrow's live direction/distance math is gated by instance state.

Avoid building anything that could be construed as a "computational addon" (per Blizzard's Kotaku interview confirming these are restricted) — this project does not calculate combat outcomes, rotations, or similar, and should stay that way.

## Feature Spec

### 1. Minimap Button
- Small icon attached to the outer edge of the minimap.
- Draggable around the minimap's circumference to any position the player chooses; position persists in SavedVariables.
- Left-click opens the main map marker interface (see below).
- Right-click opens the marker list/browser panel (see Feature 5).
- **Removed (2026-09-17)**: the coordinate-display expandable state and its Shift + Right-click toggle. The Forever beta added a native coordinate readout to the bottom of the minimap itself, making TrailBeacon's own copy redundant.

### 2. Map View — Marker Toolbar (bottom bar)
- Centered instructional text above the icon row, e.g. "Click an icon, then click on the map to place it."
- Row of selectable marker icon types (art TBD, provided by project owner later).
- Interaction: click an icon type to "arm" it, then click a location on the map to place a marker of that type there.
- Clicking an **existing** placed marker (when not in manual-select mode — see toolbar #3) opens a small context menu with:
  - Increase size / decrease size
  - Change color
  - Delete
  - Toggle lock (see "Locking" below)

### 3. Map View — Share Toolbar (top bar)
- **Select All** — selects all currently visible/filtered markers for sharing.
- **Deselect All** — clears selection.
- **Manual Select** (toggle) — while active, clicking a marker selects/deselects it for sharing instead of opening the edit context menu from toolbar #2. This mode automatically toggles OFF whenever the map is closed (`OnHide` handler) — never persist manual-select state across map close/reopen.
- **Copy** — generates a shareable export string from the currently selected markers (serialize marker data → compressed/encoded string, similar in spirit to WeakAuras/ElvUI-style export strings). Display in a copyable edit box.
- **Import** — accept pasted strings in the TomTom-style `/way` coordinate format (widely used across WowHead, guides, other addons) in addition to TrailBeacon's own native export format. A pasted `/way` string should create a marker with default styling at the given zone/coordinates.
- **Auto-share toggle** (optional setting, off by default) — when enabled, newly placed markers are automatically broadcast to the player's current party/group in real time, similar to how "Map Pin - Auto Party Share" works. This is separate from the manual Copy/Import flow.

### 4. Marker Categories & Filtering
- Each marker can be tagged with a category (category list should be easy to extend). **Finalized 2026-09-17**: Herb, Ore, Quest, Danger, Trash Mob (raid/dungeon filler mobs between bosses), Heal, Food, Cooking, Home, Marker (general-purpose, no specific use) — final icon art in `Media/Icons/`, mapped in `Modules/Markers.lua`'s `TB.ICON_TYPES`. Replaces the original placeholder set (Herb, Ore, Quest, Custom).
- Filter UI allows **multi-select**: any combination of categories can be shown/hidden simultaneously (e.g., a player can show Herb + Ore at once, not just one category at a time). This is a deliberate requirement — do not implement as a single-select/radio-style filter.
- Filter selection state persists between sessions via SavedVariables.

### 5. Marker List/Browser Panel
- Scrollable list of all saved markers, showing name, zone, and coordinates for each.
- Clicking a list entry should: jump the map view to that marker's zone/location, and/or allow selecting/tracking/deleting it directly from the list without needing to visually locate it on the map first.

### 6. Marker Tracking Arrow
- Shift-click a marker in map view toggles it as the "tracked" marker. Shift-click the same marker again clears tracking.
- Only one marker may be tracked at a time — selecting a new tracked marker replaces the previous one.
- The arrow is a freestanding screen frame, independently player-draggable (not attached to minimap or character), position persisted in SavedVariables.
- Rotates in real time to point toward the tracked marker's direction relative to the player.
- Distance value displayed **below** the rotating arrow icon (deliberate UX ordering: direction first, distance second — distance is meaningless without direction, per project owner's stated preference).
- Distance is calculated via `C_Map.GetWorldPosFromMapPos` (yard-based world position), converting both player and marker positions before computing straight-line distance. **Do not calculate distance from raw percentage-based map coordinates directly** — this produces inconsistent results across differently-sized zones.
- Distance is 2D only (flat map plane) — no elevation/vertical component. This is an accepted, permanent limitation, not a bug to fix later.
- Distance is displayed as a plain number only — no unit label. Value should increase as the player moves away and decrease as they approach. It does not need to map to any real-world or in-game unit the player would recognize as "yards" on screen — it's an internal-consistency measure only.
- Update frequency should be throttled (e.g., ~4–5 times/second), not per-frame, to avoid visual flicker in both rotation and distance text.
- **Disabled entirely while the player is in an instance** (see Secret Values section above) — hide/disable the whole arrow frame, do not attempt partial operation.
- If the tracked marker is on a different map/zone than the player (and not due to being in an instance), the arrow should indicate a "wrong zone" state rather than attempting to point through zone boundaries.

### 7. Arrow Options Window
- Opened via Shift + Right-click directly on the arrow frame itself (distinct gesture from the minimap button's Shift + Right-click — these are two separate frames and must not conflict).
- Standard popup frame, draggable by the player.
- Default open position: to the right of the arrow, slightly below its center line, so the tracking arrow itself remains visible/usable while the options window is open.
- Contents, top to bottom:
  1. Preview pane showing the currently selected arrow style/color/grayscale state at full size.
  2. Style selection row: smaller versions of each available arrow shape, with the currently active one visually highlighted/bordered. (Simple triangular shapes — final art TBD, to be provided by project owner.)
  3. Color/tint picker.
  4. Grayscale toggle.

### 8. Locking
- Each marker has a lock toggle (accessible from the marker's edit context menu — see toolbar #2).
- When locked, a marker cannot be accidentally dragged, moved, or deleted until unlocked.

## Arrow Art / Rendering Notes

**Updated 2026-09-17** — final art supplied (7 racial-themed arrow/spear designs plus the addon icon), replacing the original "simple triangular placeholder" assumption below.

**Updated again 2026-09-17** — project owner re-exported the source art with a proper background-removal tool (`ArrowImages/ArrowsNoBG/*-removebg.png`) and manually squared each canvas (content centered, transparent-padded so width == height), fixing both the fake-checkerboard-background issue and the icon's glow-halo artifact from the first pass. Game-ready versions in `Media/Arrows/*.{png,tga}` and `Media/Icon/*.{png,tga}` were regenerated from these: alpha edges smoothed (the bg-removal tool left a hard/jagged binary cutout, ~95-97% of alpha values pure 0 or 255 with almost no anti-aliasing — a small Gaussian blur on the alpha channel only fixed this), cropped to content with a small margin preserving the square, resized to 512px (256px for the icon) via Lanczos. **Arrow textures are square now** — `TB.ARROW_STYLES` in `Modules/TrackingArrow.lua` no longer carries per-style aspect ratios, and both it and `Modules/ArrowOptions.lua` just use fixed square `SetSize` calls.

**Updated 2026-09-18** — replaced the 7 detailed racial arrows with 3 simpler ones after they lost too much detail at the arrow's small on-screen size: `BasicArrow` (white fill, black border), `DragonArrow`, `GoldArrow`. `TrailBeaconIcon` was also redone with a solid background disc (it read as transparent on the minimap before). Same processing pipeline as before; old racial-arrow sources and generated files removed. Saved arrow-style settings pointing at a removed style fall back to Basic and are rewritten to it on load.

- All 3 arrows point "up" (tip/head at top) by convention, confirmed in the final art.
- `DragonArrow` and `GoldArrow` are full-color painted/shaded designs, **not** flat silhouettes — the original plan below (tint via `SetVertexColor`) will muddy/discolor them since it multiplies the texture's existing colors. `BasicArrow` is a white fill with a black border, which tints cleanly (white multiplies to the chosen color; the black border stays black). Default color is white (no-op tint).
- Grayscale toggle via `SetDesaturated(true)` still works on any of these regardless of color — no change needed there.
- Rotation via `SetRotation(angle)` on the single texture — do not pre-render directional frames.

Original placeholder-era notes (superseded above, kept for context):
- Arrow shapes were assumed to be plain white/light-gray silhouette images, source as PNG, convert to `.tga`/`.blp` for the addon.
- Color customization at runtime via `SetVertexColor(r, g, b)` — assumed flat silhouettes; see caveat above.
- Marker icon art and arrow style art were placeholder/TBD as of the original spec. Build the system to accept arbitrary texture files per style/type rather than hardcoding a fixed small set (still true — now 3 arrow styles instead of a hypothetical "simple triangle").

## SavedVariables Schema (draft — refine as needed during implementation)

Per marker:
- `id`
- `mapID`
- `x`, `y` (map-relative coordinates)
- `iconType`
- `size`
- `color`
- `category` (supports one or more tags)
- `locked` (bool)
- `tracked` (bool) — should only ever be true for at most one marker globally

Per-player/global settings:
- Minimap button: angle/position around minimap ring, coordinate-display toggle state
- Arrow: screen position (draggable), selected style, color/tint, grayscale toggle state
- Filter state: which categories are currently shown/hidden (persisted)
- Auto-share toggle state (on/off, default off)

## Distribution

- Version control: GitHub
- Distribution target: CurseForge
- Addon name: **TrailBeacon** (verified no naming collision on CurseForge as of this spec's writing)

## Explicit Non-Goals / Things Not To Build

- No true 3D world-space floating icons above marker locations in the actual game world — this was investigated and found to not be feasible via the public addon API (no supported way to anchor a custom billboard/texture to an arbitrary static world coordinate the way nameplates anchor to units). The directional tracking arrow (see Feature 6) is the intentional substitute for this idea — do not attempt to revisit or hack around this.
- No combat-math, rotation-solving, or other "computational addon" functionality, per Blizzard's stated restrictions on that category in Forever.
- No elevation/vertical component in distance calculations (2D only, by design).
- No partial/degraded operation of the tracking arrow inside instances — it must be a clean full disable, not an attempt to work around secret values.
