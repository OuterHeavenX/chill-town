# Chill Town 🍇

A cozy top-down browser game: stroll through a small vineyard-valley town, pick grapes, help the townsfolk get the harvest festival ready, then relax on a bench and watch the day turn to night.

Plain HTML, CSS and JavaScript. No dependencies, no build step. Works on desktop and mobile.

## Play

Open `index.html` in any modern browser, or serve the folder with any static file server:

```bash
npx http-server .        # then open http://localhost:8080
# or
python3 -m http.server   # then open http://localhost:8000
```

## Controls

| Action | Keyboard | Touch |
| --- | --- | --- |
| Walk | WASD or arrow keys | Drag on the left half of the screen (virtual joystick) |
| Talk / pick grapes / sit | E, Space or Enter | A button (bottom right) |
| Advance dialogue | E, Space or Enter | Tap the dialogue box or the A button |
| Menu | Esc | ☰ button (top right) |

Touch controls appear automatically on touch devices and can be toggled from the pause menu.

## The game

- Talk to **Mayor Rosa** in the town square to start the harvest quest.
- Pick ripe grape bunches in the north or south vineyard (ripe bunches sparkle; picked vines regrow after a while).
- Deliver the grapes to **Otto** at the winery, then carry his first bottle to **Bea** at the café.
- After the festival is saved, keep exploring: sell grapes to Otto for coins, chat with Lu the fisherman, Pip and Biscuit the dog, and sit on benches to relax.
- A full day/night cycle lasts about four minutes; lanterns light up at dusk.
- Progress saves automatically in your browser (localStorage).

## Deploy

The repository ships with a GitHub Actions workflow (`.github/workflows/deploy.yml`) that publishes the site to **GitHub Pages** on every push to `main`.

1. In the repository settings open **Pages** and set **Source** to **GitHub Actions**.
2. Push to `main` (or run the workflow manually from the Actions tab).
3. The game will be live at `https://<your-user>.github.io/chill-town/`.

Because everything is static and paths are relative, the folder can also be dropped onto Netlify, Vercel, Cloudflare Pages, itch.io, or any web server.

## Project layout

```
index.html           page shell, HUD, dialogue box, touch controls, title and pause menus
css/style.css        styling, responsive layout, safe-area handling for phones
js/game.js           world generation, rendering, input (keyboard + touch), NPCs, quest, save/load
.github/workflows/   GitHub Pages deployment
```
