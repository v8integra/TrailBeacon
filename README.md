# TrailBeacon

A World of Warcraft: Forever addon for placing, customizing, sharing, and navigating to custom map and minimap markers.

## Status

Early development. Currently implemented:

- Minimap button — drag around the minimap ring to reposition; Shift + Right-click toggles a live coordinate readout below the icon; left-click will open the marker map once it exists.
- Map view marker toolbar — bottom bar on the world map with a row of icon-type buttons (Herb/Ore/Quest/Custom placeholders). Click one to arm it, then click the map to drop a marker. Click an existing marker to open its edit menu (increase/decrease size, change color, lock/unlock, delete).
- Map view share toolbar — top bar with Select All / Deselect All / Manual Select (toggle; auto-turns off when the map closes) / Copy / Import, plus an Auto-Share checkbox (setting only — the actual party broadcast isn't wired up yet). Copy opens a popup with a compact export string for selected markers; Import accepts that same string format or a pasted TomTom-style `/way` line (`/way 45.2, 67.8` or `/way #mapID 45.2 67.8`).

Not yet built: the actual auto-share party broadcast, category filtering UI, the marker list/browser panel, the tracking arrow, and the arrow options window. See [CLAUDE.md](CLAUDE.md) for the full feature spec.

**Untested in-game** — the map toolbar and pin rendering use WoW's modern map canvas API (`MapCanvasDataProviderMixin`, custom pin templates, `EasyMenu` context menus). This environment can't launch the WoW client, so this code hasn't been verified against the actual Forever beta build yet. Load it in-game and report any Lua errors so they can be fixed.

Marker icon art and arrow style art are placeholders (stock Blizzard textures) until final art is supplied.

## Installation (development)

Clone or symlink this folder into your WoW `Interface/AddOns` directory as `TrailBeacon`, then enable it at the character select screen.

## Distribution

Targeting CurseForge once a first usable build exists.
