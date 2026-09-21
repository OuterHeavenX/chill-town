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
repository's default branch deploy. To publish from another branch, add it under
Settings → Environments → `github-pages` → Deployment branches; otherwise the deploy
job fails immediately with no logs to explain why.

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
| Sound on / off | M | Menu → Sound |

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
- Barracks take recruits plus a weapon. Army mode sets a company objective.
- The day turns. A village day lasts about seven minutes at normal speed; the light
  arcs from a cold morning through a brief amber dusk into a blue moonlit night,
  when the windows come alight and lanterns burn at the main building, the inn
  and the market. Chimneys smoke while someone is working inside, hearths and
  forge mouths throw real firelight, and a finished building kicks up dust.
- Houses are what let the village grow. The school makes nobody the village cannot
  house: seventeen start with room for four more, and each finished house shelters
  four. A queue that has outgrown the roofs waits and says so.
- Once you have a company, the camp answers. Every few minutes a party marches on
  your main building; a horn sounds when it sets out. Stop it, or it walks off with
  gold, food, wood and stone from the store and rejoins the garrison, stronger. A
  village that never arms itself is never raided.
- An enemy camp sits across the bridge, in a different place each game. Scout it, take
  it with your company, and its stores come home to your village as loot. The garrison
  stays hidden until one of your soldiers actually sees it.
- The iron chain is the long way to a better soldier: a charcoal burner turns trunks
  into charcoal, a mine digs ore from the northern seam, a foundry smelts the two into
  iron, and the forge makes swords. A swordsman hits about twice as hard as militia with
  an axe and carries more. Recruits take the best weapon in the store.
- A market turns surplus wine, loaves and grapes into gold. It only sells what the
  village can spare, so the inn and the winery are never emptied to fund the school.
- Menu → **Missions** lists four lessons. Each unlocks one more production chain and
  locks the ones it has not taught yet; the free village has everything from the start.
- The **Buildings** report lists every structure, how many you have standing or under
  way, what each one takes in and makes ("Takes 2 ore + 1 charcoal · makes 1 iron every
  30 s"), its cost and the worker it needs. Its **Resources** page is the legend: for every
  ware, who makes it from what and who uses it for what — charcoal comes from the
  charcoal burner and goes to the foundry and the forge. Tapping a resource in the top
  bar gives the same two lines. All of it is read off the recipe tables the game runs on,
  so it cannot go stale.
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
- Added a legend. The Buildings report gained a Resources page and every building card a
  "takes → makes" line, and tapping a counter explains the ware. It is computed from the
  simulation's own recipe, cost and kit tables rather than written by hand, and a test
  holds every ware to having a place in it.
- Added a day–night cycle and the small things that make a place feel worked:
  chimney smoke tied to who is actually at work, firelight at every hearth and
  forge mouth, lanterns that answer the dark, self-lit embers, lit windows at
  night, a dust burst when a building finishes, and wind in the trees — every
  canopy sways on its own phase, told apart from its trunk by colour and height
  in the shader, since the tree meshes carry no separate leaf surface. All of it runs on the
  Compatibility renderer the web build uses — CPU particles, a few omni lights and
  additive billboards, no post-processing — so phones are not asked for more.
- Gave the game a gothic cast: a cold overcast light, a slate sky, heavier mist,
  darker moorland ground and river, and a charcoal-and-burgundy interface with aged
  gold. The buildings keep their terracotta and teal, so the village reads as warm
  life under a grim sky. The loading screen is dark to match.
- Gave the loading screen a picture of the game: a built-out village at dusk,
  windows lit and chimneys smoking, photographed inside the engine by
  `game/tests/render_splash.gd` rather than painted. Re-run that script under a
  display (`xvfb-run` is enough) whenever the buildings or the light change.
- Made houses matter. The population cap was a label nothing read; the school now
  stops at the roof and says why.
- Let the camp raid back, so a company has something to defend against. The
  raiding party is visible on the road, and the village keeps the ledger honest
  when it loses goods.
- Fixed a save bug older than any of this: a game that had recruited a single
  soldier could never be loaded again, because the validator insisted a village
  in the default mode had no army.
- Gave the village a soundscape. There were no audio files and one synthesised chime;
  now wind and the river play under everything, birds call now and then, and every
  job has its own sound — the axe, the saw, the quarry chisel, the builder's hammer,
  the anvil — fading with distance from where the camera is looking. Buildings ding
  when they finish, blows ring in a fight, and taking the camp earns a fanfare. Every
  sound is still synthesised in code, so the download did not grow and nothing needs
  a licence. Menu → Sound (or M) turns it off, and the choice is remembered.
- Made the army visible. The battle simulation was complete — soldiers, fog of war,
  orders and camp capture all worked — but the scene the game actually loads drew none
  of it, so you commanded a company you could not see. Soldiers, the enemy camp and the
  objective marker are now rendered, with team rings and surcoats telling the sides apart.
- Turned the fixed enemy camp into a raid: it moves between games, its garrison exists
  whether or not you have an army (it used to spawn empty), and taking it pays loot into
  your store.
- Added the iron chain from the original art catalog, which was drawn but never built:
  charcoal burner, iron mine, foundry and weapon forge, each modelled from its plate.
  Weapons now have tiers that matter in a fight, where before every soldier was identical.
- Added a market and a merchant, so gold is produced rather than only spent. Before
  this the village started with fifty coins, no way to earn more, and the school
  eventually stopped for good.
- Added three more missions and real objective types: produce an amount, reach a
  stock level, grow the population, train a role, or keep the village running for a
  time. Counted objectives show progress, not just a checkbox.
- Added a village buildings report: counts per structure and what each one offers, so you
  do not have to tap buildings one by one to find out. Reached from the dock on wide
  screens and from the menu everywhere else.
- Added a headless test for the touch HUD and the deposit markers (`game/tests/test_touch_hud.gd`).
- Added a GitHub Actions workflow that runs the simulation tests, exports the web
  build with Godot 4.7.2, and deploys it to GitHub Pages.

## License and credit

Code, tools and documentation are MIT licensed (see [LICENSE](LICENSE)). Original
artwork is CC BY 4.0 (see [LICENSE-ASSETS.md](LICENSE-ASSETS.md)). Engine notices are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

> Original artwork: Lucas Marques, from Shiva — The Free Game.
> CC BY 4.0. Changes: renamed to Chill Town, English default, touch controls.
