# Chill Town 0.5.0

Build a medieval village, connect roads, train workers, and grow a self-running economy.
Four lessons introduce the production chains. The free village adds town milestones,
repeatable trade contracts and gradual tree regrowth. Choose a peaceful village from
Menu → Missions if you prefer to build without soldiers or raids.

## Browser build

Upload `Chill_Town_0.5.0_web.zip` as an HTML game on itch.io and select **This file will
be played in the browser**. The ZIP has `index.html` at its root. Use a resizable
1280×720 embed and enable fullscreen. Thread support is disabled, so this build
does not require cross-origin isolation headers. Test a real phone before advertising
mobile compatibility. Changing hosts does not automatically transfer browser saves.

## Linux / Steam Deck build

Extract `Chill_Town_0.5.0_linux.zip` with its executable and `.pck` in the same folder.
Run `chill-town.x86_64`. If your extraction tool drops its executable permission,
run `chmod +x chill-town.x86_64` once.

On Steam Deck, switch to Desktop Mode, extract the ZIP, and add `chill-town.x86_64`
to Steam as a non-Steam game. Return to Gaming Mode and select a standard Gamepad
layout. You can optionally use Steam Input to map the right trackpad to Mouse
and trackpad click to Left Mouse Click. The native Linux executable does not need
Proton. This build is a Steam Deck candidate: physical-device performance,
suspend/resume, touchscreen and audio testing remain required. It has no Valve
Verified status and is not a Steam store release.

| Control | Action |
| --- | --- |
| Left stick | Pan camera |
| Right stick | Move visible cursor |
| A or R2 | Select; hold while moving the cursor to draw a road |
| B | Cancel placement / close panels |
| X / Y | Build / train menus |
| R3 | Road tool |
| L1 / R1 | Rotate camera |
| L3 | Recenter village |
| D-pad up / down | Zoom |
| D-pad left / right | Scroll panel under cursor |
| Menu / View | Settings / pause |

Mouse, keyboard and touch controls remain available. Menu → Lighting offers a
bright daytime view for readability. Export Save downloads a portable JSON save;
Import Save loads it on another device or host. A valid import preserves the current
village in the manual save slot first. Startup resumes the newest valid manual or
automatic save, including backups. Mission identity and progress are preserved.

## Timing at 1×

A village day lasts 17 minutes 30 seconds. Training one worker takes about 50 seconds
and 1 gold, with housing and a connected school required. After a company is raised,
the first raid is about 10 minutes away; following raids are about 15 minutes apart.
Hunger is intentionally slow for relaxed building: initial workers first need a meal
after roughly 2 hours 47 minutes; a meal lasts about 67 minutes. Tree regrowth renews one harvested
tree every 20 minutes in free play. Faster simulation speeds shorten these times.

## Build and publish

Use Godot 4.7.2 plus matching Web and Linux export templates:

```sh
python3 tools/dev.py test --godot /path/to/godot
python3 tools/dev.py export-web --godot /path/to/godot
python3 tools/dev.py export-linux --godot /path/to/godot
python3 tools/package_release.py
```

The source of truth is `main`. The CI workflow tests pull requests and builds both
platforms; only a push or manual run on `main` may deploy GitHub Pages. Make `main`
the repository default and permit it in the `github-pages` environment settings.
For itch.io, create a draft project under OuterHeavenX, attach the Web ZIP for browser
play and the Linux ZIP as a Linux download, inspect the draft, then publish it.
Keep the MIT code license and CC BY 4.0 asset credits supplied in both archives.

## Suggested itch.io listing

**Title:** Chill Town  
**Short description:** A relaxed medieval village builder with autonomous workers,
four guided lessons, and an expanding economy.  
**Status:** In development  
**Genre:** Simulation  
**Tags:** city-builder, medieval, relaxing, strategy, singleplayer  
**Platforms:** HTML5 and Linux  
**Price:** Free / optional donations, subject to the creator's preference.

Chill Town is an English-language fork of The Free Game by Lucas Marques, from Shiva.
Build roads and workshops, teach villagers new professions, and watch supplies move
through your town. Grow grain into bread, grapes into wine, and ore into swords.
Play the guided lessons, pursue milestones in a free village, or choose peaceful play.
Browser saves stay on your device; portable save export lets you move your town.
Controller support is included in the Linux build, with Steam Deck hardware testing
still pending.
