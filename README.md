# TrailBeacon

A World of Warcraft: Forever addon for placing, customizing, sharing, and navigating to custom map and minimap markers.

## Status

Early development. Currently implemented:

- Minimap button — drag around the minimap ring to reposition; left-click opens the world map, right-click opens the marker list. (No coordinate readout on the button itself — the Forever beta added a native one to the minimap, so TrailBeacon's own copy was removed.)
- Map view marker toolbar — bottom bar on the world map with a row of icon-type buttons: Herb, Ore, Quest, Danger, Trash Mob, Heal, Food, Cooking, Home, Marker (final art, see "Art assets"). Click one to arm it, then click the map to drop a marker. Click an existing marker to open its edit menu (increase/decrease size, change color, lock/unlock, delete).
- Map view share toolbar — top bar with Select All / Deselect All / Manual Select (toggle; auto-turns off when the map closes) / Copy / Import, plus an Auto-Share checkbox. Copy opens a popup with a compact export string for selected markers; Import accepts that same string format or a pasted TomTom-style `/way` line (`/way 45.2, 67.8` or `/way #mapID 45.2 67.8`).
- Category filtering — a Filters button on the share toolbar opens a checkbox panel (one per icon type). Any combination can be shown/hidden at once; hidden categories are excluded from both pin rendering and Select All. Filter state persists via SavedVariables.
- Marker list/browser panel — right-click the minimap button to open a scrollable window listing every saved marker (icon, name, zone, coordinates). Clicking an entry opens the world map to that marker's zone; each row has a delete button. Minimap button left-click now opens the world map directly (previously a stub).
- Tracking arrow — shift-click a marker pin on the map to track it (shift-click again to untrack; tracked pins get a gold ring, same as the white selection ring but a different color). A freestanding, draggable screen arrow rotates to point at it and shows distance below, throttled to ~5 updates/sec. Fully hidden while in an instance (no partial operation, per the spec's secret-values constraint), and hidden whenever nothing is tracked. Shows a desaturated "Different Zone" state if the tracked marker isn't on the player's current map.
- Arrow options window — shift + right-click the arrow itself to open it: a full-size preview, a row of style thumbnails (one per arrow art file, highlighting the active one), a color picker, and a grayscale toggle.
- Auto-share — when the checkbox is on, every marker *you* place is broadcast over an addon message to your party (or raid, if in one) in real time. Markers you receive this way import silently (with a chat print naming the sender) and are never themselves re-broadcast, so there's no relay/loop risk. Separate from the manual Copy/Import flow, as speced. Only triggers on locally-placed markers — importing a `/way` line or a pasted export string does not auto-share.

Every feature in [CLAUDE.md](CLAUDE.md) now has a first-pass implementation.

Note: the spec's SavedVariables draft didn't define a marker `name` field, only `iconType`/etc. — the browser currently falls back to the icon type's label (e.g. "Herb") as the display name, since there's no naming UI yet. Multiple markers of the same type will show the same name, distinguished by zone/coordinates.

**First in-game test found and fixed a real bug**: `Modules/MapPins.xml` originally loaded before `Modules/MapPins.lua` in the TOC, so the XML pin template's `mixin="TrailBeaconPinMixin"` referenced a Lua table that didn't exist yet — the template silently failed to register, which only surfaced as a runtime error the moment a marker was actually placed. Fixed by reordering the TOC (Lua before XML) and rebuilding the pin mixin from `CreateFromMixins(MapCanvasPinMixin)` in Lua rather than an XML `inherits=` attribute referencing a base template name that couldn't be verified. Still **untested past this fix** — the tracking arrow's rotation math depends on WoW's world-coordinate axis convention and `GetPlayerFacing()`'s bearing convention, neither of which could be verified without a running client. If the arrow spins the wrong way or is off by a fixed amount, see the `ROTATION_SIGN`/`ROTATION_OFFSET` comment at the top of [Modules/TrackingArrow.lua](Modules/TrackingArrow.lua) — that's the one place to adjust rather than reworking the math. Keep reporting Lua errors or wrong-looking behavior as you test further.

The color/tint picker on the arrow options window multiplies the texture's own colors (`SetVertexColor`) — since the arrow art is full-color painted work rather than a flat silhouette, tinting it will shift/muddy its colors rather than cleanly recoloring it. Leaving color at white (the default) avoids this; worth revisiting if that turns out to matter in practice. Marker category icons don't have this problem — see "Art assets" below.

## Art assets

- `ArrowImages/` — first-pass raw source exports (7 racial-themed arrows + the addon icon), kept for reference. Had a fake checkerboard baked into opaque RGB instead of real alpha, and the icon had a glow-halo artifact — both fixed in the next pass.
- `ArrowImages/ArrowsNoBG/` — second-pass source: re-exported with a proper background-removal tool (real alpha this time) and manually squared (content centered, transparent-padded to make width == height).
- `Media/Arrows/*.{png,tga}` and `Media/Icon/*.{png,tga}` — game-ready versions built from the `ArrowsNoBG` sources: alpha edges smoothed (the bg-removal tool left a hard, jagged/aliased cutout with almost no anti-aliasing — confirmed by sampling, then fixed with a small blur on just the alpha channel), cropped to content with a small margin, resized to 512px (256px for the icon) via Lanczos. All square now, matching the source canvases — verified the "narrowing" didn't distort the art (content aspect ratio in the new files matches the old non-square processed versions; the squaring was done by adding side padding, not by squeezing pixels). Both known issues from the first pass are resolved: no checkerboard bleed-through anywhere, and the icon's lantern glow no longer has a halo artifact around it.
- `icons/` — the 10 marker-category icons as supplied (flat, solid black line art, 128x128, real alpha already). Kept as-is for reference.
- `Media/Icons/*.{png,tga}` — the same 10 icons with RGB forced to pure white (alpha untouched). They were solid black, and the marker system's "Change Color" tint (`SetVertexColor`, a multiply) has no effect on black — 0 × anything is still 0. White is the correct base for that mechanism to actually work, and since these were already flat single-color art, converting to white lost no detail. Mapped to categories in `Modules/Markers.lua`'s `TB.ICON_TYPES`: `leaf`→Herb, `pickaxe`→Ore, `star`→Quest, `skull-crossbones`→Danger, `trash`→Trash Mob (marks raid/dungeon filler mobs), `bandage-wound`→Heal, `hamburger-soda`→Food, `knife-kitchen`→Cooking, `home`→Home, `marker`→Marker (general-purpose, no specific use).

## Installation (development)

Clone or symlink this folder into your WoW `Interface/AddOns` directory as `TrailBeacon`, then enable it at the character select screen.

## Distribution

Targeting CurseForge once a first usable build exists.
