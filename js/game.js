/* =====================================================================
   Chill Town — a cozy top-down stroll through a vineyard valley.
   Plain HTML5 canvas, no dependencies, no build step.
   ===================================================================== */
(function () {
  'use strict';

  // ------------------------------------------------------------------
  // Constants
  // ------------------------------------------------------------------
  const TILE = 32;
  const MAP_W = 48;
  const MAP_H = 36;
  const SAVE_KEY = 'chill-town-save-v1';
  const DAY_LENGTH = 240;         // seconds of real time per in-game day
  const VINE_REGROW = 75;         // seconds for a harvested vine to ripen again
  const PLAYER_SPEED = 118;       // px / second

  const T = {
    GRASS: 0, PATH: 1, WATER: 2, VINE: 3, TREE: 4, FENCE: 5, WALL: 6, ROOF: 7,
    DOOR: 8, FLOWER: 9, SAND: 10, BENCH: 11, WELL: 12, BARREL: 13, SIGN: 14,
    BRIDGE: 15, STONE: 16, LAMP: 17, CRATE: 18
  };
  const SOLID = new Set([T.WATER, T.VINE, T.TREE, T.FENCE, T.WALL, T.ROOF, T.DOOR,
    T.BENCH, T.WELL, T.BARREL, T.SIGN, T.LAMP, T.CRATE]);

  // ------------------------------------------------------------------
  // Deterministic RNG (so the map is the same every time)
  // ------------------------------------------------------------------
  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      let t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  // ------------------------------------------------------------------
  // World
  // ------------------------------------------------------------------
  const map = new Uint8Array(MAP_W * MAP_H);
  const reserved = new Uint8Array(MAP_W * MAP_H); // keeps trees/flowers off important tiles
  const vines = new Map();      // key "x,y" -> { ripe:bool, timer:number }
  const doors = new Map();      // key "x,y" -> building name
  const signs = new Map();      // key "x,y" -> text
  const decorVariant = new Uint8Array(MAP_W * MAP_H);

  const idx = (x, y) => y * MAP_W + x;
  const inMap = (x, y) => x >= 0 && y >= 0 && x < MAP_W && y < MAP_H;
  const tileAt = (x, y) => (inMap(x, y) ? map[idx(x, y)] : T.WATER);
  const key = (x, y) => x + ',' + y;

  function set(x, y, t, res) {
    if (!inMap(x, y)) return;
    map[idx(x, y)] = t;
    if (res !== false) reserved[idx(x, y)] = 1;
  }
  function rect(x0, y0, x1, y1, t, res) {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set(x, y, t, res);
  }

  function building(x0, y0, x1, y1, doorX, name) {
    // roof rows (top 40%), wall rows, door on the bottom row
    const roofRows = Math.max(2, Math.round((y1 - y0 + 1) * 0.45));
    rect(x0, y0, x1, y0 + roofRows - 1, T.ROOF);
    rect(x0, y0 + roofRows, x1, y1, T.WALL);
    set(doorX, y1, T.DOOR);
    doors.set(key(doorX, y1), name);
    // reserve a margin so trees do not hug the walls
    for (let y = y0 - 1; y <= y1 + 1; y++) for (let x = x0 - 1; x <= x1 + 1; x++) if (inMap(x, y)) reserved[idx(x, y)] = 1;
  }

  function vineyard(x0, y0, x1, y1) {
    for (let y = y0; y <= y1; y += 2) {
      for (let x = x0; x <= x1; x++) {
        set(x, y, T.VINE);
        vines.set(key(x, y), { ripe: true, timer: 0 });
      }
      if (y + 1 <= y1) rect(x0, y + 1, x1, y + 1, T.GRASS); // walking row
    }
    // fence around the block with gaps in the middle of each side
    for (let x = x0 - 1; x <= x1 + 1; x++) {
      if (Math.abs(x - (x0 + x1) / 2) > 1) { set(x, y0 - 1, T.FENCE); set(x, y1 + 1, T.FENCE); }
      else { set(x, y0 - 1, T.GRASS); set(x, y1 + 1, T.GRASS); }
    }
    for (let y = y0 - 1; y <= y1 + 1; y++) {
      if (Math.abs(y - (y0 + y1) / 2) > 1) { set(x0 - 1, y, T.FENCE); set(x1 + 1, y, T.FENCE); }
      else { set(x0 - 1, y, T.GRASS); set(x1 + 1, y, T.GRASS); }
    }
  }

  function buildWorld() {
    const rnd = mulberry32(20240911);
    map.fill(T.GRASS);
    reserved.fill(0);

    // --- river on the east with a beach on the far bank
    rect(38, 0, 40, MAP_H - 1, T.WATER);
    rect(41, 0, 41, MAP_H - 1, T.SAND);
    rect(37, 0, 37, MAP_H - 1, T.SAND);
    // wobble the banks a little
    for (let y = 0; y < MAP_H; y++) {
      if (rnd() < 0.35) set(37, y, T.WATER);
      if (rnd() < 0.35) set(42, y, T.SAND);
    }
    // bridge
    rect(36, 17, 42, 18, T.BRIDGE);

    // --- main roads
    rect(1, 17, 46, 18, T.PATH);   // east-west
    rect(20, 1, 21, 34, T.PATH);   // north-south
    rect(36, 17, 42, 18, T.BRIDGE);

    // --- town square
    rect(15, 13, 26, 21, T.STONE);
    rect(16, 14, 25, 20, T.PATH);
    set(20, 17, T.WELL); set(21, 17, T.WELL); set(20, 18, T.WELL); set(21, 18, T.WELL);
    set(16, 14, T.BENCH); set(25, 14, T.BENCH); set(16, 20, T.BENCH); set(25, 20, T.BENCH);
    set(17, 21, T.LAMP); set(24, 21, T.LAMP); set(17, 13, T.LAMP); set(24, 13, T.LAMP);
    set(23, 20, T.SIGN); signs.set(key(23, 20), 'Town square\n← Café & vineyards   Winery →\nRiver & beach →  Cottages ↓');

    // --- buildings (doors face south; paths connect them to the roads)
    building(27, 6, 34, 12, 30, 'winery');
    rect(30, 13, 30, 16, T.PATH);
    set(35, 12, T.BARREL); set(36, 12, T.BARREL); set(35, 11, T.BARREL); set(26, 12, T.CRATE);

    building(8, 8, 14, 13, 11, 'cafe');
    rect(11, 14, 11, 16, T.PATH);
    set(15, 13, T.BENCH); set(7, 13, T.LAMP);

    building(27, 22, 33, 27, 30, 'townhall');
    rect(22, 28, 30, 28, T.PATH);
    set(29, 28, T.LAMP); set(31, 28, T.LAMP); set(29, 28, T.PATH); set(34, 27, T.LAMP);

    building(9, 23, 13, 27, 11, 'cottage');
    rect(11, 28, 19, 28, T.PATH);
    set(14, 27, T.CRATE);

    building(2, 29, 6, 33, 4, 'shed');
    set(7, 33, T.BARREL);

    // --- vineyards
    vineyard(3, 1, 15, 5);          // north vineyard
    vineyard(24, 30, 35, 34);       // south vineyard
    set(22, 32, T.SIGN); signs.set(key(22, 32), 'South vineyard\nRipe bunches sparkle. Pick them with A / E.');
    set(7, 7, T.SIGN); signs.set(key(7, 7), 'North vineyard\nOtto\u2019s best grapes grow here.');

    // --- fishing spot & beach across the river
    rect(43, 19, 47, 23, T.SAND);
    set(44, 22, T.BENCH); set(46, 20, T.CRATE);
    set(43, 17, T.LAMP);

    // --- little pond in the south-west meadow
    rect(15, 30, 17, 32, T.WATER); set(18, 31, T.SAND); set(14, 31, T.SAND);

    // --- stone edging around the square roads
    for (let x = 14; x <= 27; x++) { if (tileAt(x, 12) === T.GRASS) set(x, 12, T.FLOWER); }

    // --- trees: forest edge on the west and around the map border
    for (let y = 0; y < MAP_H; y++) for (let x = 0; x < MAP_W; x++) {
      if (reserved[idx(x, y)] || map[idx(x, y)] !== T.GRASS) continue;
      const border = x === 0 || y === 0 || y === MAP_H - 1 || x === 36;
      const westWood = x < 3 && y > 8 && y < 28;
      const nearRoad = Math.abs(y - 17.5) < 2 || Math.abs(x - 20.5) < 2;
      let p = 0.045;
      if (border) p = 0.85;
      if (westWood) p = 0.55;
      if (nearRoad) p *= 0.3;
      if (x > 42) p = 0.5;
      if (rnd() < p) { set(x, y, T.TREE, false); decorVariant[idx(x, y)] = (rnd() * 3) | 0; }
      else if (rnd() < 0.06) { set(x, y, T.FLOWER, false); decorVariant[idx(x, y)] = (rnd() * 4) | 0; }
    }
    // never let trees block the roads near spawn or the bridge
    rect(19, 16, 22, 19, T.PATH);
    set(20, 17, T.WELL); set(21, 17, T.WELL); set(20, 18, T.WELL); set(21, 18, T.WELL);
    rect(36, 17, 42, 18, T.BRIDGE);

    // grass variants
    for (let i = 0; i < map.length; i++) if (map[i] === T.GRASS || map[i] === T.PATH || map[i] === T.SAND) decorVariant[i] = (rnd() * 4) | 0;
  }

  // ------------------------------------------------------------------
  // Game state
  // ------------------------------------------------------------------
  const state = {
    quest: 0,             // 0 talk to mayor, 1 harvest, 2 deliver to Otto, 3 bring bottle to Bea, 4 done
    grapes: 0,
    coins: 0,
    hasBottle: false,
    chill: 0,
    time: 8 * 3600 / 24,  // fraction-of-day * DAY_LENGTH; we store seconds into the day
    day: 1,
    px: 20.5 * TILE, py: 20 * TILE,
  };
  state.time = (8 / 24) * DAY_LENGTH;

  const player = {
    x: 0, y: 0, w: 18, h: 12,   // feet hitbox
    dir: 'down', moving: false, anim: 0,
    palette: { skin: '#e8b68f', hair: '#3b2a20', shirt: '#7bd389', pants: '#2f3e5c' },
  };

  const npcs = [];
  function makeNpc(o) {
    const n = Object.assign({
      x: o.tx * TILE + TILE / 2, y: o.ty * TILE + TILE, homeX: o.tx * TILE + TILE / 2, homeY: o.ty * TILE + TILE,
      dir: 'down', anim: 0, moving: false, wait: 1 + Math.random() * 3, tx: 0, ty: 0, targetX: null, targetY: null,
      radius: 0, speed: 40,
    }, o);
    npcs.push(n);
    return n;
  }

  // ------------------------------------------------------------------
  // Dialogue
  // ------------------------------------------------------------------
  const dialog = { open: false, lines: [], i: 0, name: '', onDone: null, typed: 0, full: '' };
  const $ = (id) => document.getElementById(id);

  function say(name, lines, onDone) {
    dialog.open = true; dialog.lines = Array.isArray(lines) ? lines : [lines]; dialog.i = 0; dialog.name = name; dialog.onDone = onDone || null;
    showLine();
  }
  function showLine() {
    dialog.full = dialog.lines[dialog.i];
    dialog.typed = 0;
    $('dialog-name').textContent = dialog.name;
    $('dialog-text').textContent = '';
    $('dialog').hidden = false;
    $('dialog-hint').textContent = (dialog.i < dialog.lines.length - 1) ? 'tap or press E to continue' : 'tap or press E to close';
  }
  function advanceDialog() {
    if (!dialog.open) return;
    if (dialog.typed < dialog.full.length) { dialog.typed = dialog.full.length; $('dialog-text').textContent = dialog.full; return; }
    dialog.i++;
    if (dialog.i >= dialog.lines.length) {
      dialog.open = false; $('dialog').hidden = true;
      const cb = dialog.onDone; dialog.onDone = null; if (cb) cb();
    } else showLine();
  }
  function updateDialog(dt) {
    if (!dialog.open || dialog.typed >= dialog.full.length) return;
    dialog.typed = Math.min(dialog.full.length, dialog.typed + dt * 55);
    $('dialog-text').textContent = dialog.full.slice(0, Math.floor(dialog.typed));
  }

  let toastTimer = 0;
  function toast(msg, secs) {
    const el = $('toast'); el.textContent = msg; el.hidden = false; toastTimer = secs || 3;
  }

  // ------------------------------------------------------------------
  // Quest text
  // ------------------------------------------------------------------
  const GRAPES_NEEDED = 10;
  function objectiveText() {
    switch (state.quest) {
      case 0: return 'Find Mayor Rosa in the town square.';
      case 1: return `Pick ${GRAPES_NEEDED} bunches of grapes (${Math.min(state.grapes, GRAPES_NEEDED)}/${GRAPES_NEEDED}).`;
      case 2: return 'Bring the grapes to Otto at the winery (north-east).';
      case 3: return 'Take Otto’s bottle to Bea at the café (north-west).';
      default: return 'Festival saved! Wander, relax, or sell grapes to Otto.';
    }
  }

  function setupNpcs() {
    npcs.length = 0;
    makeNpc({
      name: 'Mayor Rosa', tx: 23, ty: 16, radius: 40, palette: { skin: '#e8b68f', hair: '#4a2c1c', shirt: '#c94f6d', pants: '#3a2f45' },
      talk() {
        if (state.quest === 0) {
          say('Mayor Rosa', [
            'Oh! A new face. Welcome to Chill Town, traveler.',
            'You picked a good day to arrive: the harvest festival is tonight.',
            'Only... Otto at the winery ran short on grapes, and everyone is too busy hanging lanterns.',
            `Would you pick ${GRAPES_NEEDED} bunches from the vineyards and bring them to him? The north vineyard is just past the café.`,
            'Ripe bunches sparkle a little. Stand next to a vine and press A to pick.'
          ], () => { state.quest = 1; toast('New objective: pick grapes'); save(); });
        } else if (state.quest === 1) {
          say('Mayor Rosa', [`How is the picking going? Otto needs ${GRAPES_NEEDED} bunches. You have ${state.grapes}.`, 'Take your time. Nobody rushes in Chill Town.']);
        } else if (state.quest === 2) {
          say('Mayor Rosa', ['You have the grapes? Wonderful. Otto is outside the winery, north-east of the square.']);
        } else if (state.quest === 3) {
          say('Mayor Rosa', ['Bea will love that bottle. Her café is on the north-west side of the square.']);
        } else {
          say('Mayor Rosa', ['The festival was perfect. Thank you again, friend.', 'Stay as long as you like. There is always a bench with your name on it.']);
        }
      }
    });
    makeNpc({
      name: 'Otto', tx: 31, ty: 14, radius: 30, palette: { skin: '#d9a57c', hair: '#e6e0d3', shirt: '#5a6b8c', pants: '#43332b' },
      talk() {
        if (state.quest < 1) {
          say('Otto', ['Hmm? Oh, hello. Sorry, I am counting barrels.', 'The mayor is in the square if you are looking for someone to talk to.']);
        } else if (state.quest === 1 || state.quest === 2) {
          if (state.grapes >= GRAPES_NEEDED) {
            say('Otto', [
              `${GRAPES_NEEDED} bunches! Look at those. Plump, sweet, perfect.`,
              'Give me a moment... there. The first bottle of the season.',
              'Would you take it to Bea at the café? She always gets the first pour. Tradition.'
            ], () => { state.grapes -= GRAPES_NEEDED; state.hasBottle = true; state.quest = 3; toast('You received a bottle of Chill Town red'); save(); });
          } else {
            say('Otto', [`I need ${GRAPES_NEEDED} bunches for the festival batch. You have ${state.grapes} so far.`, 'The north vineyard is closest. The south one is bigger but a longer walk.']);
          }
        } else if (state.quest === 3) {
          say('Otto', ['Bea is waiting at the café, north-west of the square. Careful with that bottle!']);
        } else {
          if (state.grapes > 0) {
            const pay = state.grapes * 2;
            say('Otto', [`More grapes? I will take them. ${state.grapes} bunches... that is ${pay} coins for you.`, 'Come back whenever the vines are ripe again.'],
              () => { state.coins += pay; state.grapes = 0; toast(`+${pay} coins`); save(); });
          } else {
            say('Otto', ['I pay 2 coins a bunch if you ever feel like picking again.', 'No pressure. The vines are not going anywhere.']);
          }
        }
      }
    });
    makeNpc({
      name: 'Bea', tx: 13, ty: 15, radius: 30, palette: { skin: '#b57a5a', hair: '#1f1a1a', shirt: '#e9c46a', pants: '#2f4858' },
      talk() {
        if (state.quest < 3) {
          say('Bea', ['Welcome to the café! Well, the outside of it. The espresso machine is fixed at last.', 'If you are helping Otto, the north vineyard is right behind me.']);
        } else if (state.quest === 3) {
          say('Bea', [
            'Is that... Otto’s first bottle? For me?',
            'Oh, that is the festival saved, then. Lanterns, music, and a proper glass of red.',
            'You are one of us now. Honorary citizen of Chill Town.',
            'Sit on any bench and just breathe for a while. That is the real tradition here.'
          ], () => { state.hasBottle = false; state.quest = 4; state.coins += 20; toast('Quest complete! +20 coins. Enjoy the town.', 5); save(); });
        } else {
          say('Bea', ['Coffee is on the house for honorary citizens.', `You have relaxed ${state.chill} times. ${state.chill >= 5 ? 'That is the spirit.' : 'Try the bench by the river.'}`]);
        }
      }
    });
    makeNpc({
      name: 'Lu', tx: 45, ty: 21, radius: 0, palette: { skin: '#c48f6a', hair: '#8c8c8c', shirt: '#2a9d8f', pants: '#264653' },
      talk() {
        const lines = [
          ['Shh. The fish can hear you.', '...they never bite anyway. That is not the point.'],
          ['See the light on the water? Best free show in the valley.'],
          ['I have lived here sixty years and never once been in a hurry.'],
          ['On festival nights the lanterns float down the river. Stay and watch, if you can.'],
        ];
        say('Lu', lines[(Math.random() * lines.length) | 0]);
      }
    });
    makeNpc({
      name: 'Pip', tx: 17, ty: 25, radius: 90, speed: 62, small: true, palette: { skin: '#e8b68f', hair: '#d9822b', shirt: '#4cc9f0', pants: '#3a506b' },
      talk() {
        const lines = [
          ['I found a frog by the pond! I named it Mayor Frog.', 'Do not tell Mayor Rosa.'],
          ['Race you to the bridge! ...okay, never mind, I am tired.'],
          state.quest === 1 ? ['The south vineyard has waaay more grapes. It is past the town hall.'] : ['Biscuit the dog lives by the cottage. He is the goodest.'],
          ['Sometimes I sit on the bench and count clouds. My record is fourteen.'],
        ];
        say('Pip', lines[(Math.random() * lines.length) | 0]);
      }
    });
    makeNpc({
      name: 'Biscuit', tx: 13, ty: 28, radius: 70, speed: 70, dog: true,
      talk() {
        say('Biscuit', [['Woof!'], ['*happy tail wagging*'], ['Bork. (He wants a belly rub.)', 'You give him a belly rub. Perfect.'], ['*sniff sniff* ...woof.']][(Math.random() * 4) | 0],
          () => { if (Math.random() < 0.5) { state.chill++; save(); } });
      }
    });
  }

  // ------------------------------------------------------------------
  // Save / load
  // ------------------------------------------------------------------
  function save() {
    try {
      const vineState = [];
      vines.forEach((v, k) => { if (!v.ripe) vineState.push([k, Math.round(v.timer)]); });
      localStorage.setItem(SAVE_KEY, JSON.stringify({
        quest: state.quest, grapes: state.grapes, coins: state.coins, hasBottle: state.hasBottle, chill: state.chill,
        time: state.time, day: state.day, px: player.x, py: player.y, vines: vineState
      }));
    } catch (e) { /* storage may be unavailable; ignore */ }
  }
  function hasSave() { try { return !!localStorage.getItem(SAVE_KEY); } catch (e) { return false; } }
  function load() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return false;
      const d = JSON.parse(raw);
      state.quest = d.quest | 0; state.grapes = d.grapes | 0; state.coins = d.coins | 0; state.hasBottle = !!d.hasBottle; state.chill = d.chill | 0;
      state.time = typeof d.time === 'number' ? d.time : state.time; state.day = d.day || 1;
      if (typeof d.px === 'number' && typeof d.py === 'number') { player.x = d.px; player.y = d.py; }
      vines.forEach(v => { v.ripe = true; v.timer = 0; });
      (d.vines || []).forEach(([k, t]) => { const v = vines.get(k); if (v) { v.ripe = false; v.timer = t; } });
      return true;
    } catch (e) { return false; }
  }
  function resetGame(clearSave) {
    if (clearSave) { try { localStorage.removeItem(SAVE_KEY); } catch (e) { /* ignore */ } }
    state.quest = 0; state.grapes = 0; state.coins = 0; state.hasBottle = false; state.chill = 0; state.day = 1;
    state.time = (8 / 24) * DAY_LENGTH;
    player.x = 20.5 * TILE + TILE / 2; player.y = 20 * TILE + TILE;
    player.dir = 'down';
    vines.forEach(v => { v.ripe = true; v.timer = 0; });
    setupNpcs();
  }

  // ------------------------------------------------------------------
  // Input
  // ------------------------------------------------------------------
  const keys = new Set();
  let actionQueued = false;
  const stick = { active: false, id: null, ox: 0, oy: 0, dx: 0, dy: 0 };
  let touchMode = false;

  window.addEventListener('keydown', (e) => {
    if (e.repeat) return;
    const k = e.key.toLowerCase();
    if (['arrowup', 'arrowdown', 'arrowleft', 'arrowright', ' '].includes(k)) e.preventDefault();
    keys.add(k);
    if (k === 'e' || k === ' ' || k === 'enter') actionQueued = true;
    if (k === 'escape') toggleMenu();
  });
  window.addEventListener('keyup', (e) => keys.delete(e.key.toLowerCase()));
  window.addEventListener('blur', () => keys.clear());

  function keyboardVector() {
    let dx = 0, dy = 0;
    if (keys.has('arrowleft') || keys.has('a')) dx -= 1;
    if (keys.has('arrowright') || keys.has('d')) dx += 1;
    if (keys.has('arrowup') || keys.has('w')) dy -= 1;
    if (keys.has('arrowdown') || keys.has('s')) dy += 1;
    return [dx, dy];
  }

  function setupTouch() {
    const zone = $('stick-zone'), base = $('stick-base'), knob = $('stick-knob'), btnA = $('btn-a');
    const RADIUS = 46;
    const place = (x, y) => { base.style.left = x + 'px'; base.style.top = y + 'px'; };

    zone.addEventListener('pointerdown', (e) => {
      if (stick.active) return;
      stick.active = true; stick.id = e.pointerId;
      const r = zone.getBoundingClientRect();
      stick.ox = e.clientX - r.left; stick.oy = e.clientY - r.top;
      place(stick.ox, stick.oy); base.classList.add('active');
      knob.style.transform = 'translate(0,0)';
      zone.setPointerCapture(e.pointerId);
      e.preventDefault();
    });
    zone.addEventListener('pointermove', (e) => {
      if (!stick.active || e.pointerId !== stick.id) return;
      const r = zone.getBoundingClientRect();
      let dx = (e.clientX - r.left) - stick.ox, dy = (e.clientY - r.top) - stick.oy;
      const len = Math.hypot(dx, dy);
      if (len > RADIUS) { dx = dx / len * RADIUS; dy = dy / len * RADIUS; }
      knob.style.transform = `translate(${dx}px,${dy}px)`;
      const dead = 8;
      if (len < dead) { stick.dx = 0; stick.dy = 0; }
      else { const m = Math.min(1, (len - dead) / (RADIUS - dead)); stick.dx = dx / (len || 1) * m; stick.dy = dy / (len || 1) * m; }
      e.preventDefault();
    });
    const end = (e) => {
      if (!stick.active || e.pointerId !== stick.id) return;
      stick.active = false; stick.dx = 0; stick.dy = 0; base.classList.remove('active');
      knob.style.transform = 'translate(0,0)';
      place(90, zone.clientHeight - 90);
    };
    zone.addEventListener('pointerup', end);
    zone.addEventListener('pointercancel', end);
    zone.addEventListener('lostpointercapture', end);

    btnA.addEventListener('pointerdown', (e) => { btnA.classList.add('active'); actionQueued = true; e.preventDefault(); });
    const up = () => btnA.classList.remove('active');
    btnA.addEventListener('pointerup', up); btnA.addEventListener('pointercancel', up); btnA.addEventListener('pointerleave', up);

    // tapping the dialogue box advances it
    $('dialog').addEventListener('pointerdown', (e) => { e.preventDefault(); advanceDialog(); });

    place(90, zone.clientHeight - 90);
  }

  function setTouchMode(on) {
    touchMode = on;
    $('touch').hidden = !on;
    document.body.classList.toggle('touch-mode', on);
    try { localStorage.setItem('chill-town-touch', on ? '1' : '0'); } catch (e) { /* ignore */ }
    const zone = $('stick-zone');
    if (on) { $('stick-base').style.left = '90px'; $('stick-base').style.top = (zone.clientHeight - 90) + 'px'; }
  }
  function detectTouch() {
    let pref = null;
    try { pref = localStorage.getItem('chill-town-touch'); } catch (e) { /* ignore */ }
    if (pref === '1') return true;
    if (pref === '0') return false;
    return ('ontouchstart' in window) || navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches;
  }

  // ------------------------------------------------------------------
  // Menu / title
  // ------------------------------------------------------------------
  let running = false, paused = false;

  function toggleMenu() {
    if (!running) return;
    paused = !paused;
    $('menu').hidden = !paused;
    if (paused) save();
  }

  function startGame(fresh) {
    if (fresh) resetGame(true);
    $('title').hidden = true; $('hud').hidden = false;
    running = true; paused = false;
    updateHud();
    if (fresh) say('Chill Town', ['A quiet valley. A river. Rows of vines heavy with fruit.', 'You take a breath. Nothing here is urgent.', 'Someone is waving at you from the square.']);
  }

  function setupUi() {
    $('btn-continue').addEventListener('click', () => startGame(false));
    $('btn-new').addEventListener('click', () => startGame(true));
    $('btn-resume').addEventListener('click', toggleMenu);
    $('btn-menu').addEventListener('click', toggleMenu);
    $('btn-touch-toggle').addEventListener('click', () => setTouchMode(!touchMode));
    $('btn-restart').addEventListener('click', () => {
      if (confirm('Restart from the beginning? Your progress will be erased.')) { paused = false; $('menu').hidden = true; startGame(true); }
    });
  }

  // ------------------------------------------------------------------
  // Physics helpers
  // ------------------------------------------------------------------
  function solidAt(px, py) { return SOLID.has(tileAt(Math.floor(px / TILE), Math.floor(py / TILE))); }
  function boxFree(x, y, w, h) {
    // x,y = feet-box center-bottom; box spans [x-w/2, x+w/2] x [y-h, y]
    const x0 = x - w / 2, x1 = x + w / 2 - 0.01, y0 = y - h, y1 = y - 0.01;
    return !solidAt(x0, y0) && !solidAt(x1, y0) && !solidAt(x0, y1) && !solidAt(x1, y1);
  }
  function moveEntity(e, dx, dy) {
    const w = e.w || 18, h = e.h || 12;
    if (dx !== 0) {
      const sx = Math.sign(dx); let rem = Math.abs(dx);
      while (rem > 0) { const st = Math.min(1, rem); if (boxFree(e.x + sx * st, e.y, w, h)) { e.x += sx * st; rem -= st; } else break; }
    }
    if (dy !== 0) {
      const sy = Math.sign(dy); let rem = Math.abs(dy);
      while (rem > 0) { const st = Math.min(1, rem); if (boxFree(e.x, e.y + sy * st, w, h)) { e.y += sy * st; rem -= st; } else break; }
    }
    e.x = Math.max(12, Math.min(MAP_W * TILE - 12, e.x));
    e.y = Math.max(16, Math.min(MAP_H * TILE - 2, e.y));
  }

  // ------------------------------------------------------------------
  // Interaction
  // ------------------------------------------------------------------
  const DIRV = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
  function facingTile() {
    const [fx, fy] = DIRV[player.dir];
    const bx = Math.floor(player.x / TILE), by = Math.floor((player.y - 4) / TILE);
    return [bx + fx, by + fy];
  }

  function interact() {
    // 1) NPC in front of or very near the player
    const [fx, fy] = DIRV[player.dir];
    const lookX = player.x + fx * 26, lookY = (player.y - 6) + fy * 26;
    let best = null, bestD = 1e9;
    for (const n of npcs) {
      const d1 = Math.hypot(n.x - lookX, (n.y - 6) - lookY);
      const d0 = Math.hypot(n.x - player.x, n.y - player.y);
      const d = Math.min(d1, d0 + 10);
      if (d < 34 && d < bestD) { best = n; bestD = d; }
    }
    if (best) {
      // face each other
      const ddx = player.x - best.x, ddy = player.y - best.y;
      best.dir = Math.abs(ddx) > Math.abs(ddy) ? (ddx > 0 ? 'right' : 'left') : (ddy > 0 ? 'down' : 'up');
      best.moving = false; best.wait = 4;
      best.talk();
      return;
    }
    // 2) tile in front of the player
    const [tx, ty] = facingTile();
    const t = tileAt(tx, ty);
    const k = key(tx, ty);
    if (t === T.VINE) {
      const v = vines.get(k);
      if (v && v.ripe) {
        v.ripe = false; v.timer = VINE_REGROW;
        const got = 1 + (Math.random() < 0.25 ? 1 : 0);
        state.grapes += got;
        toast(got > 1 ? 'A double bunch! +2 grapes' : '+1 grapes', 1.4);
        if (state.quest === 1 && state.grapes >= GRAPES_NEEDED) { state.quest = 2; toast('That is enough grapes. Find Otto at the winery.', 4); }
        save();
      } else {
        say('Vine', ['Only leaves here. Give it a little while to ripen again.']);
      }
      return;
    }
    if (t === T.BENCH) {
      const lines = [
        'You sit down. The breeze smells faintly of grapes and river water.',
        'You sit for a while and watch the clouds drift over the hills.',
        'You close your eyes. Somewhere a dog is snoring. Perfect.',
        'You sit. A leaf lands on your knee. You let it stay.',
        'You count the vine rows from here. You lose count. It does not matter.',
      ];
      state.chill++;
      say('Bench', [lines[(Math.random() * lines.length) | 0], `Relaxed ${state.chill} ${state.chill === 1 ? 'time' : 'times'}.`], save);
      return;
    }
    if (t === T.WELL) { say('Well', ['Cool air rises from the well. You splash your face. Refreshing.']); return; }
    if (t === T.SIGN) { say('Sign', signs.get(k) ? signs.get(k).split('\n') : ['The paint has faded.']); return; }
    if (t === T.BARREL) { say('Barrels', ['Oak barrels, stacked and sleeping. They smell like autumn.']); return; }
    if (t === T.CRATE) { say('Crate', ['Empty crates, waiting for the harvest.']); return; }
    if (t === T.LAMP) { say('Lantern', [state.time / DAY_LENGTH > 0.75 || state.time / DAY_LENGTH < 0.25 ? 'The lantern glows warm against the night.' : 'A lantern for the festival. It will be lit at dusk.']); return; }
    if (t === T.WATER) { say('River', ['The water is clear and cold. A fish flicks away.']); return; }
    if (t === T.DOOR) {
      const b = doors.get(k);
      const text = {
        winery: ['The winery smells of oak and grapes. Otto is outside, by the barrels.'],
        cafe: ['The café is warm and smells of coffee. Bea is out front.'],
        townhall: ['The town hall is quiet. Everyone is out preparing the festival.'],
        cottage: ['Somebody’s cottage. You knock politely. Nobody answers, but Biscuit barks somewhere.'],
        shed: ['A garden shed. Rakes, twine, and one very confident spider.'],
      }[b] || ['The door is locked.'];
      say('Door', text);
    }
  }

  // ------------------------------------------------------------------
  // Update
  // ------------------------------------------------------------------
  function update(dt) {
    // time of day
    state.time += dt;
    if (state.time >= DAY_LENGTH) { state.time -= DAY_LENGTH; state.day++; toast(`Day ${state.day}`, 2.5); }

    // vines regrow
    vines.forEach(v => { if (!v.ripe) { v.timer -= dt; if (v.timer <= 0) { v.ripe = true; v.timer = 0; } } });

    if (toastTimer > 0) { toastTimer -= dt; if (toastTimer <= 0) $('toast').hidden = true; }

    updateDialog(dt);

    if (actionQueued) {
      actionQueued = false;
      if (dialog.open) advanceDialog(); else interact();
    }

    // player movement (blocked while a dialogue is open)
    let [dx, dy] = keyboardVector();
    if (stick.active) { dx = stick.dx; dy = stick.dy; }
    const len = Math.hypot(dx, dy);
    if (dialog.open || len < 0.05) { player.moving = false; }
    else {
      if (len > 1) { dx /= len; dy /= len; }
      const speed = PLAYER_SPEED * (stick.active ? Math.min(1, len + 0.25) : 1);
      moveEntity(player, dx * speed * dt, dy * speed * dt);
      player.moving = true;
      player.anim += dt * 9;
      if (Math.abs(dx) > Math.abs(dy)) player.dir = dx > 0 ? 'right' : 'left';
      else player.dir = dy > 0 ? 'down' : 'up';
    }

    // NPC wandering
    for (const n of npcs) {
      if (dialog.open || n.radius === 0) { n.moving = false; continue; }
      if (n.targetX === null) {
        n.wait -= dt;
        if (n.wait <= 0) {
          const a = Math.random() * Math.PI * 2, r = Math.random() * n.radius;
          n.targetX = n.homeX + Math.cos(a) * r; n.targetY = n.homeY + Math.sin(a) * r;
          n.stuck = 0;
        }
        n.moving = false;
      } else {
        const ddx = n.targetX - n.x, ddy = n.targetY - n.y, d = Math.hypot(ddx, ddy);
        if (d < 3) { n.targetX = null; n.wait = 1.5 + Math.random() * 4; n.moving = false; continue; }
        const ox = n.x, oy = n.y;
        moveEntity(n, ddx / d * n.speed * dt, ddy / d * n.speed * dt);
        // keep NPCs off the player
        if (Math.hypot(n.x - player.x, n.y - player.y) < 22) { n.x = ox; n.y = oy; n.stuck += dt; }
        if (Math.hypot(n.x - ox, n.y - oy) < 0.01) n.stuck += dt; else n.stuck = 0;
        if (n.stuck > 0.6) { n.targetX = null; n.wait = 1; }
        n.moving = true; n.anim += dt * 8;
        n.dir = Math.abs(ddx) > Math.abs(ddy) ? (ddx > 0 ? 'right' : 'left') : (ddy > 0 ? 'down' : 'up');
      }
    }

    updateHud();
  }

  let hudCache = '';
  function updateHud() {
    const frac = state.time / DAY_LENGTH;
    const mins = Math.floor(frac * 24 * 60);
    const hh = String(Math.floor(mins / 60)).padStart(2, '0'), mm = String(mins % 60).padStart(2, '0');
    const s = `${state.day}|${hh}:${mm}|${state.grapes}|${state.coins}|${state.quest}|${state.hasBottle}`;
    if (s === hudCache) return;
    hudCache = s;
    $('hud-time').textContent = `Day ${state.day} · ${hh}:${mm}`;
    $('hud-grapes').textContent = `🍇 ${state.grapes}` + (state.hasBottle ? '  🍷' : '');
    $('hud-coins').textContent = `🪙 ${state.coins}`;
    $('hud-objective').textContent = objectiveText();
  }

  // ------------------------------------------------------------------
  // Rendering
  // ------------------------------------------------------------------
  const canvas = $('c');
  const ctx = canvas.getContext('2d');
  let W = 0, H = 0, DPR = 1, ZOOM = 2;
  const cam = { x: 0, y: 0 };

  function resize() {
    DPR = Math.min(2, window.devicePixelRatio || 1);
    W = window.innerWidth; H = window.innerHeight;
    canvas.width = Math.floor(W * DPR); canvas.height = Math.floor(H * DPR);
    canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
    // aim for roughly 11 tiles across on phones, ~20 on desktops
    ZOOM = Math.max(1.4, Math.min(2.2, Math.min(W / (11 * TILE), H / (8 * TILE))));
    if (touchMode) { const zone = $('stick-zone'); $('stick-base').style.top = (zone.clientHeight - 90) + 'px'; }
  }
  window.addEventListener('resize', resize);
  window.addEventListener('orientationchange', () => setTimeout(resize, 200));

  // Palette
  const C = {
    grass: ['#6fae4b', '#68a646', '#74b350', '#6aab48'],
    grassDark: '#5a9a3c',
    path: ['#d9b98a', '#d4b383', '#dcbf92', '#d7b787'],
    sand: ['#e9d8a6', '#e4d29e', '#ecdcae', '#e6d4a1'],
    water: '#4a90c2', waterLight: '#6fb0d8', waterDark: '#3a78a8',
    stone: '#b8b2a7', stoneDark: '#9c968b',
    vine: '#3f7d2f', vineLeaf: '#57a13f', vineStake: '#7a5230',
    grape: '#6a2f90', grapeLight: '#9b59d0',
    trunk: '#6b4a2b', leaf: '#3c8a3a', leafLight: '#55a84c', leafDark: '#2f6f2e',
    fence: '#a97a4d', fenceDark: '#7c5836',
    wall: '#f0e2c8', wallShade: '#dcc9a8', wallLine: '#c9b590',
    roof: '#b5493f', roofDark: '#8f3730', roofLight: '#cf6a5c',
    door: '#5d3b1e', doorDark: '#3e2712',
    bench: '#8a6236', benchDark: '#5f4224',
    well: '#8d8a83', wellDark: '#5e5b55', wellRoof: '#a24a3d',
    barrel: '#8b5a2b', barrelBand: '#4a3a30',
    sign: '#b98a5a', signDark: '#7a5836',
    lamp: '#3b3b46', lampGlow: '#ffd27a',
    crate: '#c39a63', crateDark: '#8a6a40',
    flower: ['#f26d85', '#f7d354', '#ffffff', '#c084fc'],
  };

  function drawTile(x, y, t) {
    const px = x * TILE, py = y * TILE;
    const v = decorVariant[idx(x, y)];
    switch (t) {
      case T.GRASS: case T.TREE: case T.FLOWER:
        ctx.fillStyle = C.grass[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        if (((x * 7 + y * 13) % 5) === 0) { ctx.fillStyle = C.grassDark; ctx.fillRect(px + 6 + (v * 5) % 14, py + 8 + (v * 7) % 14, 3, 5); ctx.fillRect(px + 18, py + 20, 3, 4); }
        if (t === T.FLOWER) {
          ctx.fillStyle = C.flower[v & 3];
          ctx.fillRect(px + 8, py + 10, 4, 4); ctx.fillRect(px + 20, py + 18, 4, 4); ctx.fillRect(px + 14, py + 22, 3, 3);
          ctx.fillStyle = '#fbe58a'; ctx.fillRect(px + 9, py + 11, 2, 2); ctx.fillRect(px + 21, py + 19, 2, 2);
        }
        break;
      case T.PATH:
        ctx.fillStyle = C.path[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = '#c7a878'; ctx.fillRect(px + 4 + (v * 9) % 18, py + 6 + (v * 5) % 20, 4, 3);
        break;
      case T.BRIDGE:
        ctx.fillStyle = '#a5743f'; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = '#8a5f33'; for (let i = 0; i < 4; i++) ctx.fillRect(px + i * 8, py, 1, TILE);
        ctx.fillStyle = '#6f4b27'; ctx.fillRect(px, py, TILE, 3); ctx.fillRect(px, py + TILE - 3, TILE, 3);
        break;
      case T.SAND:
        ctx.fillStyle = C.sand[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = '#d6c28e'; ctx.fillRect(px + (v * 11) % 24, py + (v * 7) % 24, 3, 2);
        break;
      case T.WATER: {
        ctx.fillStyle = C.water; ctx.fillRect(px, py, TILE, TILE);
        const ph = (frame * 0.03 + x * 0.9 + y * 1.7);
        ctx.fillStyle = C.waterLight;
        ctx.fillRect(px + 4 + Math.round(Math.sin(ph) * 4), py + 8, 10, 2);
        ctx.fillRect(px + 16 + Math.round(Math.cos(ph) * 4), py + 22, 8, 2);
        ctx.fillStyle = C.waterDark; ctx.fillRect(px + 10 + Math.round(Math.cos(ph * 0.7) * 3), py + 16, 8, 2);
        break;
      }
      case T.STONE:
        ctx.fillStyle = C.stone; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.stoneDark; ctx.fillRect(px, py + 15, TILE, 1); ctx.fillRect(px + 15 + ((x + y) % 2) * 8, py, 1, 15); ctx.fillRect(px + 8 + ((x + y) % 2) * 12, py + 16, 1, 16);
        break;
      case T.VINE: {
        ctx.fillStyle = C.grass[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = '#7a5a3a'; ctx.fillRect(px, py + 26, TILE, 4); // soil strip
        ctx.fillStyle = C.vineStake; ctx.fillRect(px + 15, py + 4, 3, 26);
        ctx.fillStyle = C.vine; ctx.fillRect(px + 2, py + 8, TILE - 4, 14);
        ctx.fillStyle = C.vineLeaf; ctx.fillRect(px + 4, py + 6, 8, 6); ctx.fillRect(px + 20, py + 9, 8, 6); ctx.fillRect(px + 10, py + 16, 7, 6);
        const vs = vines.get(key(x, y));
        if (vs && vs.ripe) {
          ctx.fillStyle = C.grape;
          ctx.fillRect(px + 5, py + 14, 6, 6); ctx.fillRect(px + 21, py + 16, 6, 6); ctx.fillRect(px + 12, py + 22, 5, 5);
          ctx.fillStyle = C.grapeLight; ctx.fillRect(px + 6, py + 15, 2, 2); ctx.fillRect(px + 22, py + 17, 2, 2);
          if (((frame >> 4) + x + y) % 6 === 0) { ctx.fillStyle = '#fff6c8'; ctx.fillRect(px + 9, py + 12, 2, 2); }
        }
        break;
      }
      case T.FENCE:
        ctx.fillStyle = C.grass[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.fence; ctx.fillRect(px + 4, py + 6, 5, 22); ctx.fillRect(px + 23, py + 6, 5, 22);
        ctx.fillRect(px, py + 11, TILE, 4); ctx.fillRect(px, py + 20, TILE, 4);
        ctx.fillStyle = C.fenceDark; ctx.fillRect(px + 4, py + 26, 5, 2); ctx.fillRect(px + 23, py + 26, 5, 2);
        break;
      case T.WALL:
        ctx.fillStyle = C.wall; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.wallLine; ctx.fillRect(px, py + 15, TILE, 1);
        ctx.fillStyle = C.wallShade; ctx.fillRect(px, py + TILE - 3, TILE, 3);
        if (((x + y) & 1) === 0 && tileAt(x, y - 1) === T.ROOF) { // window
          ctx.fillStyle = '#7fb3d5'; ctx.fillRect(px + 9, py + 6, 14, 12);
          ctx.fillStyle = '#4a4033'; ctx.fillRect(px + 9, py + 11, 14, 1); ctx.fillRect(px + 15, py + 6, 1, 12);
          ctx.fillStyle = '#c94f6d'; ctx.fillRect(px + 7, py + 18, 18, 3); // flower box
        }
        break;
      case T.ROOF:
        ctx.fillStyle = C.roof; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.roofDark; ctx.fillRect(px, py + 8, TILE, 2); ctx.fillRect(px, py + 24, TILE, 2);
        ctx.fillStyle = C.roofLight; ctx.fillRect(px + ((y & 1) ? 0 : 16), py + 2, 12, 4); ctx.fillRect(px + ((y & 1) ? 16 : 0), py + 18, 12, 4);
        if (tileAt(x, y - 1) !== T.ROOF) { ctx.fillStyle = C.roofDark; ctx.fillRect(px, py, TILE, 3); }
        break;
      case T.DOOR:
        ctx.fillStyle = C.wall; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.door; ctx.fillRect(px + 8, py + 6, 16, 26);
        ctx.fillStyle = C.doorDark; ctx.fillRect(px + 8, py + 6, 16, 2); ctx.fillRect(px + 15, py + 8, 2, 24);
        ctx.fillStyle = '#e6c15a'; ctx.fillRect(px + 12, py + 19, 2, 2);
        break;
      case T.BENCH:
        ctx.fillStyle = tileAt(x, y - 1) === T.PATH || tileAt(x, y - 1) === T.STONE ? C.path[0] : (tileAt(x, y - 1) === T.SAND ? C.sand[0] : C.grass[v & 3]); ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.benchDark; ctx.fillRect(px + 4, py + 18, 4, 10); ctx.fillRect(px + 24, py + 18, 4, 10);
        ctx.fillStyle = C.bench; ctx.fillRect(px + 2, py + 14, 28, 5); ctx.fillRect(px + 2, py + 6, 28, 4); ctx.fillRect(px + 4, py + 10, 3, 4); ctx.fillRect(px + 25, py + 10, 3, 4);
        break;
      case T.WELL: {
        ctx.fillStyle = C.path[0]; ctx.fillRect(px, py, TILE, TILE);
        const L = tileAt(x - 1, y) !== T.WELL, R = tileAt(x + 1, y) !== T.WELL, U = tileAt(x, y - 1) !== T.WELL, D = tileAt(x, y + 1) !== T.WELL;
        ctx.fillStyle = C.wellDark; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.well; ctx.fillRect(px + (L ? 3 : 0), py + (U ? 3 : 0), TILE - (L ? 3 : 0) - (R ? 3 : 0), TILE - (U ? 3 : 0) - (D ? 3 : 0));
        ctx.fillStyle = C.waterDark; ctx.fillRect(px + (L ? 9 : 0), py + (U ? 9 : 0), TILE - (L ? 9 : 0) - (R ? 9 : 0), TILE - (U ? 9 : 0) - (D ? 9 : 0));
        if (U) { ctx.fillStyle = C.wellRoof; ctx.fillRect(px, py - 8, TILE, 7); ctx.fillStyle = C.fenceDark; ctx.fillRect(px + (L ? 2 : TILE - 5), py - 2, 3, 12); }
        break;
      }
      case T.BARREL:
        ctx.fillStyle = C.path[0]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.barrel; ctx.fillRect(px + 6, py + 4, 20, 26);
        ctx.fillStyle = C.barrelBand; ctx.fillRect(px + 6, py + 9, 20, 2); ctx.fillRect(px + 6, py + 23, 20, 2);
        ctx.fillStyle = '#a5713a'; ctx.fillRect(px + 10, py + 6, 3, 22);
        break;
      case T.CRATE:
        ctx.fillStyle = C.grass[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.crate; ctx.fillRect(px + 5, py + 8, 22, 22);
        ctx.fillStyle = C.crateDark; ctx.fillRect(px + 5, py + 18, 22, 2); ctx.fillRect(px + 15, py + 8, 2, 22); ctx.fillRect(px + 5, py + 8, 22, 2);
        break;
      case T.SIGN:
        ctx.fillStyle = C.grass[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.signDark; ctx.fillRect(px + 14, py + 14, 4, 16);
        ctx.fillStyle = C.sign; ctx.fillRect(px + 4, py + 4, 24, 12);
        ctx.fillStyle = C.signDark; ctx.fillRect(px + 8, py + 8, 16, 1); ctx.fillRect(px + 8, py + 11, 12, 1);
        break;
      case T.LAMP:
        ctx.fillStyle = tileAt(x, y + 1) === T.PATH ? C.path[0] : C.grass[v & 3]; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = C.lamp; ctx.fillRect(px + 14, py + 6, 4, 26); ctx.fillRect(px + 10, py + 28, 12, 4);
        ctx.fillStyle = isNight() ? C.lampGlow : '#d8d0b8'; ctx.fillRect(px + 10, py + 2, 12, 8);
        break;
      default:
        ctx.fillStyle = '#f0f'; ctx.fillRect(px, py, TILE, TILE);
    }
  }

  function drawTree(x, y) {
    const px = x * TILE, py = y * TILE, v = decorVariant[idx(x, y)];
    ctx.fillStyle = 'rgba(0,0,0,0.18)'; ctx.fillRect(px + 6, py + 24, 22, 6);
    ctx.fillStyle = C.trunk; ctx.fillRect(px + 13, py + 12, 7, 18);
    ctx.fillStyle = C.leafDark; ctx.fillRect(px + 2, py - 6, 28, 22);
    ctx.fillStyle = C.leaf; ctx.fillRect(px + 4, py - 10, 24, 22);
    ctx.fillStyle = C.leafLight; ctx.fillRect(px + 8, py - 8, 8, 6); ctx.fillRect(px + 18 - v * 2, py - 2, 6, 5);
  }

  function drawCharacter(e, isPlayer) {
    const x = Math.round(e.x), y = Math.round(e.y);
    const bob = e.moving ? Math.round(Math.sin(e.anim) * 1.5) : 0;
    const legPhase = e.moving ? Math.sin(e.anim) : 0;
    ctx.fillStyle = 'rgba(0,0,0,0.2)'; ctx.fillRect(x - 8, y - 3, 16, 4);

    if (e.dog) {
      const flip = e.dir === 'left' ? -1 : 1;
      ctx.fillStyle = '#c9925a'; ctx.fillRect(x - 9, y - 11 + bob, 18, 8);          // body
      ctx.fillRect(x + flip * 6 - 4, y - 15 + bob, 8, 7);                            // head
      ctx.fillStyle = '#8f6136'; ctx.fillRect(x + flip * 9 - 3, y - 16 + bob, 3, 4); // ear
      ctx.fillRect(x - flip * 10 - 1, y - 14 + bob - Math.round(legPhase * 2), 3, 5); // tail
      ctx.fillStyle = '#1b1b1b'; ctx.fillRect(x + flip * 8 - 1, y - 13 + bob, 2, 2); // eye
      ctx.fillStyle = '#8f6136'; ctx.fillRect(x - 8, y - 4, 3, 4 + Math.round(legPhase * 1)); ctx.fillRect(x + 5, y - 4, 3, 4 - Math.round(legPhase * 1));
      return;
    }

    const p = e.palette;
    const h = e.small ? 0.8 : 1;
    const top = y - Math.round(30 * h) + bob;
    // legs
    ctx.fillStyle = p.pants;
    ctx.fillRect(x - 6, y - 10, 5, 10 + Math.round(legPhase * 2)); ctx.fillRect(x + 1, y - 10, 5, 10 - Math.round(legPhase * 2));
    // body
    ctx.fillStyle = p.shirt; ctx.fillRect(x - 7, top + 12, 14, Math.round(10 * h) + 1);
    // arms
    ctx.fillStyle = p.skin;
    if (e.dir === 'left') ctx.fillRect(x - 3, top + 14, 4, 8);
    else if (e.dir === 'right') ctx.fillRect(x - 1, top + 14, 4, 8);
    else { ctx.fillRect(x - 10, top + 14 + Math.round(legPhase * 2), 3, 8); ctx.fillRect(x + 7, top + 14 - Math.round(legPhase * 2), 3, 8); }
    // head
    ctx.fillStyle = p.skin; ctx.fillRect(x - 7, top, 14, 13);
    // hair
    ctx.fillStyle = p.hair; ctx.fillRect(x - 8, top - 2, 16, 5);
    if (e.dir === 'up') ctx.fillRect(x - 8, top - 2, 16, 12);
    else if (e.dir === 'left') ctx.fillRect(x + 3, top - 2, 5, 11);
    else if (e.dir === 'right') ctx.fillRect(x - 8, top - 2, 5, 11);
    // face
    if (e.dir !== 'up') {
      ctx.fillStyle = '#2b2b2b';
      if (e.dir === 'down') { ctx.fillRect(x - 4, top + 6, 2, 3); ctx.fillRect(x + 2, top + 6, 2, 3); }
      else if (e.dir === 'left') ctx.fillRect(x - 5, top + 6, 2, 3);
      else ctx.fillRect(x + 3, top + 6, 2, 3);
      ctx.fillStyle = '#e59b8f';
      if (e.dir === 'down') { ctx.fillRect(x - 6, top + 9, 2, 1); ctx.fillRect(x + 4, top + 9, 2, 1); }
    }
    if (isPlayer) { // little scarf so the player stands out
      ctx.fillStyle = '#f2c14e'; ctx.fillRect(x - 7, top + 12, 14, 3);
    }
    // name tag when close to the player
    if (!isPlayer) {
      const d = Math.hypot(e.x - player.x, e.y - player.y);
      if (d < 70) {
        ctx.font = 'bold 9px sans-serif'; ctx.textAlign = 'center';
        const label = e.name;
        const w = ctx.measureText(label).width + 8;
        ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillRect(x - w / 2, top - 16, w, 12);
        ctx.fillStyle = '#fff'; ctx.fillText(label, x, top - 7);
      }
    }
  }

  function isNight() { const f = state.time / DAY_LENGTH; return f < 0.24 || f > 0.8; }

  function nightOverlay() {
    const f = state.time / DAY_LENGTH; // 0 = midnight
    // darkness curve: full at midnight, none from ~7:00 to ~18:00
    let d = 0;
    if (f < 0.27) d = Math.min(1, (0.27 - f) / 0.12);
    else if (f > 0.75) d = Math.min(1, (f - 0.75) / 0.12);
    d = Math.min(d, 0.82);
    if (d > 0) {
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      ctx.fillStyle = `rgba(16, 20, 60, ${d * 0.62})`;
      ctx.fillRect(0, 0, W, H);
    }
    // warm dusk / dawn tint
    let warm = 0;
    if (f > 0.7 && f < 0.82) warm = 1 - Math.abs(f - 0.76) / 0.06;
    if (f > 0.22 && f < 0.32) warm = 1 - Math.abs(f - 0.27) / 0.05;
    if (warm > 0) { ctx.setTransform(DPR, 0, 0, DPR, 0, 0); ctx.fillStyle = `rgba(255, 140, 60, ${warm * 0.16})`; ctx.fillRect(0, 0, W, H); }
    return d;
  }

  let frame = 0;
  function render() {
    frame++;
    // camera
    const viewW = W / ZOOM, viewH = H / ZOOM;
    cam.x = Math.round(Math.max(0, Math.min(MAP_W * TILE - viewW, player.x - viewW / 2)));
    cam.y = Math.round(Math.max(0, Math.min(MAP_H * TILE - viewH, player.y - 8 - viewH / 2)));
    if (MAP_W * TILE < viewW) cam.x = (MAP_W * TILE - viewW) / 2;
    if (MAP_H * TILE < viewH) cam.y = (MAP_H * TILE - viewH) / 2;

    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.fillStyle = '#2e5a2a'; ctx.fillRect(0, 0, W, H);
    ctx.imageSmoothingEnabled = false;
    ctx.setTransform(DPR * ZOOM, 0, 0, DPR * ZOOM, -cam.x * DPR * ZOOM, -cam.y * DPR * ZOOM);

    const x0 = Math.max(0, Math.floor(cam.x / TILE)), y0 = Math.max(0, Math.floor(cam.y / TILE));
    const x1 = Math.min(MAP_W - 1, Math.ceil((cam.x + viewW) / TILE)), y1 = Math.min(MAP_H - 1, Math.ceil((cam.y + viewH) / TILE) + 1);

    // ground pass
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) drawTile(x, y, map[idx(x, y)]);

    // y-sorted pass: trees + characters
    const drawables = [];
    for (let y = y0 - 1; y <= y1; y++) for (let x = x0; x <= x1; x++) if (tileAt(x, y) === T.TREE) drawables.push({ y: y * TILE + 30, f: () => drawTree(x, y) });
    for (const n of npcs) drawables.push({ y: n.y, f: () => drawCharacter(n, false) });
    drawables.push({ y: player.y, f: () => drawCharacter(player, true) });
    drawables.sort((a, b) => a.y - b.y);
    for (const d of drawables) d.f();

    // interaction hint: highlight the tile in front of the player
    if (!dialog.open) {
      const [tx, ty] = facingTile();
      const t = tileAt(tx, ty);
      const vs = vines.get(key(tx, ty));
      if ((t === T.VINE && vs && vs.ripe) || t === T.BENCH || t === T.SIGN || t === T.DOOR) {
        ctx.strokeStyle = 'rgba(255,255,255,' + (0.45 + 0.3 * Math.sin(frame * 0.15)) + ')';
        ctx.lineWidth = 2; ctx.strokeRect(tx * TILE + 2, ty * TILE + 2, TILE - 4, TILE - 4);
      }
    }

    const dark = nightOverlay();

    // lantern glow at night
    if (dark > 0.05) {
      ctx.setTransform(DPR * ZOOM, 0, 0, DPR * ZOOM, -cam.x * DPR * ZOOM, -cam.y * DPR * ZOOM);
      ctx.globalCompositeOperation = 'lighter';
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (map[idx(x, y)] === T.LAMP) {
        const g = ctx.createRadialGradient(x * TILE + 16, y * TILE + 6, 4, x * TILE + 16, y * TILE + 6, 70);
        g.addColorStop(0, `rgba(255, 200, 110, ${0.45 * dark})`); g.addColorStop(1, 'rgba(255,200,110,0)');
        ctx.fillStyle = g; ctx.fillRect(x * TILE - 60, y * TILE - 70, 152, 152);
      }
      ctx.globalCompositeOperation = 'source-over';
    }
  }

  // ------------------------------------------------------------------
  // Main loop
  // ------------------------------------------------------------------
  let last = performance.now(), saveTick = 0;
  function loop(now) {
    let dt = (now - last) / 1000; last = now;
    if (dt > 0.1) dt = 0.1;
    if (running && !paused) {
      update(dt);
      saveTick += dt; if (saveTick > 10) { saveTick = 0; save(); }
    }
    render();
    requestAnimationFrame(loop);
  }
  document.addEventListener('visibilitychange', () => { if (document.hidden) { keys.clear(); save(); } last = performance.now(); });
  window.addEventListener('pagehide', save);

  // ------------------------------------------------------------------
  // Boot
  // ------------------------------------------------------------------
  function boot() {
    buildWorld();
    resetGame();
    const loaded = load();
    setupNpcs();
    $('btn-continue').hidden = !loaded;
    setupUi();
    setupTouch();
    setTouchMode(detectTouch());
    resize();
    updateHud();
    requestAnimationFrame(loop);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();

  // expose a tiny debug handle
  window.ChillTown = { state, player, npcs, map, TILE, MAP_W, MAP_H, say, toast, save, load, resetGame, startGame };
})();
