# Chill Town

An open medieval village-building game for desktop and mobile browsers. Plan roads
and buildings, train workers, and watch the village work on its own. Built with
Godot 4.7.2 and GDScript.

Chill Town is an English-language fork of
[The Free Game](https://github.com/LucasMarquesShiva/the-free-game) by
**Lucas Marques, from Shiva**, with touch controls and a phone-sized interface.

## Play

The GitHub Actions workflow in this repository exports the game and publishes it to
GitHub Pages on every push. Once Pages is enabled for the repository (Settings →
Pages → Source: **GitHub Actions**), the game is live at:

`https://<your-user>.github.io/chill-town/`

Enabling Pages also creates a `github-pages` environment that only lets the
repository's default branch deploy. If you deploy from another branch, add it under
Settings → Environments → `github-pages` → Deployment branches, or the deploy job
fails immediately with no logs.

There is no account, server, or API key. Saves stay in the browser that made them.

## Controls

| Action | Mouse and keyboard | Touch |
| --- | --- | --- |
| Move the camera | Drag the ground, or WASD / arrow keys | Drag with one finger (two fingers while drawing roads) |
| Zoom | Mouse wheel | Pinch, or the **+** / **−** buttons |
| Rotate the view | Q / E | Twist with two fingers, or the rotate buttons on the camera pad |
| Recenter on the village | Home, or the **Village** button | The crosshair button on the camera pad |
| Select or build | Click | Tap |
| Draw roads | R, then drag | **Roads**, then drag with one finger |
| Pause, speed | Space, 1 / 2 / 4 | **Pause**, **1×** button cycles speed |
| Save / load | F5 / F9 | Menu |

The camera pad appears automatically on touch screens. Two fingers do everything
at once: pinch to zoom, twist to rotate, drag to pan, even while drawing a road.

On narrow screens the HUD switches to a compact layout. It keeps as many resource
counters as the bar can hold, and the Army button replaces Help once a barracks is
standing. Panels are laid out inside the device safe area, so nothing hides under a
status bar, a notch, or the home indicator.

## What is playable

This is a browser beta, not a finished commercial release. It begins with a main
building, an instructor school, a plaza, and villagers. You draw roads, place
buildings, train professions, and expand the economy.

- Civilians accept tasks automatically and gather in the plaza when idle.
- Servants deliver materials; builders construct buildings and road tiles.
- The school spends gold and trains new people.
- Woodcutters harvest the nearest tree they can reach; the sawmill turns trunks into timber; quarries need a stone deposit.
- Grain goes through mill and bakery to loaves; workers eat at the inn.
- Barracks take recruits plus axes or bows. Army mode sets a company objective.
- Menu → first lesson locks the farm/wine chain until school, inn, woodcutter and quarry exist.
- Manual saves and autosaves are local to each browser and device.

## Develop

1. Install the standard **Godot 4.7.2** editor from the
   [official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
2. In Godot choose **Import**, select `game/project.godot`, and open it.
3. Press **F5** to run the main scene (`scenes/approved.tscn`).

Optional command line (Python 3.10+):

```sh
python3 tools/dev.py doctor        # check the Godot version
python3 tools/dev.py run           # launch the game
python3 tools/dev.py test          # headless simulation tests
python3 tools/dev.py export-web    # needs the 4.7.2 web export templates
python3 tools/dev.py serve --port 8000
```

Pass `--godot /path/to/Godot` or set `GODOT_BIN` if Godot is not on your PATH.
The web export goes to `builds/web/`; serve it over HTTP rather than opening the
file directly. See [docs/WEB.md](docs/WEB.md) for hosting notes.

## Language

The game starts in English. Portuguese (Brazil) and Simplified Chinese can be
chosen from the in-game menu; the choice is remembered per device. Source strings
in the code are Portuguese keys translated through `game/locale/en.json`.

## Repository layout

| Folder | Contents |
| --- | --- |
| `game/` | Complete editable Godot project |
| `game/simulation/` | Civilian autonomy, roads, building, production, saves |
| `game/presentation/` | 3D scene, terrain, people, procedural building models |
| `game/ui/` | HUD, training, build menus, touch camera pad |
| `game/assets/` | Runtime images, textures, mesh resources, shaders, previews |
| `game/tests/` | Simulation checks and development render harnesses |
| `art/` | Original art, concept sheets, visual specifications |
| `tools/` | Development commands and the browser loading screen |
| `docs/` | Architecture, customization and publication guides |
| `.github/workflows/` | Web export and GitHub Pages deployment |

## Changes from The Free Game

- Renamed to Chill Town (project name, loading screen, in-game brand, save folder).
- English is the default language; 144 missing English strings were added.
- The worker "working" animation now matches translated status text, not only Portuguese.
- Touch controls: two-finger pinch, twist-to-rotate and pan; an on-screen camera pad
  (zoom, rotate, recenter); and a phone layout for the HUD that respects the device
  safe area and adapts the counter row to the width available.
- Panels scroll from a drag anywhere inside them. Buttons used to swallow the drag,
  so on a phone you could only scroll by catching a gap between two cards.
- The stone deposit is now visible as granite outcrops south of the main building, and its
  cells are highlighted while the quarry tool is active (it was invisible before).
- Woodcutters pick the nearest tree they can actually stand beside. They used to take the
  closest trunk and stall for good when it was walled in by the middle of a grove.
- Added a headless test for the touch HUD and the deposit markers (`game/tests/test_touch_hud.gd`).
- Added a GitHub Actions workflow that runs the simulation tests, exports the web
  build with Godot 4.7.2, and deploys it to GitHub Pages.

## License and credit

Code, tools and documentation are MIT licensed (see [LICENSE](LICENSE)). Original
artwork is CC BY 4.0 (see [LICENSE-ASSETS.md](LICENSE-ASSETS.md)). Engine notices are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

> Original artwork: Lucas Marques, from Shiva — The Free Game.
> CC BY 4.0. Changes: renamed to Chill Town, English default, touch controls.
