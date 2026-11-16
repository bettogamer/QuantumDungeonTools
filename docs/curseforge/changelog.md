# CurseForge — Changelog (per-file)

> Se pega en la caja **Changelog** al subir el archivo. **En inglés.** Se REESCRIBE en cada
> subida: solo el texto de ESTA subida, desde la última versión PUBLICADA (plantilla y reglas:
> AddonTemplate `templates/curseforge/changelog_TEMPLATE.md`). No es `CHANGELOG.md`.

---

## v0.1.0-beta.2 — Minimap Lens

A second module: Minimap Lens, a bigger minimap when you need it.

- Enlarges the real minimap on demand (2.6× by default, one zoom step closer) and puts
  everything back when you turn it off, reload or go through a loading screen, even in combat.
- Turn it on with a keybinding (Options › Keybindings › AddOns › Quantum Dungeon Tools, unbound by
  default), the magnifier button next to the minimap (inside instances) or `/qdt lens`. It closes
  itself when you leave the instance or open Edit Mode.
- Works alongside EllesmereUI, ElvUI and other minimap addons: it re-applies what they change
  without fighting, and warns you once if they keep overriding it.
- A Minimap Lens page in the main window: size and opacity live, extra zoom, hide herbs and ores
  while it is on, lock or move its position, and your keybinding.

## v0.1.0-beta.1 — First beta: Instance Tracker

The first public build of Quantum Dungeon Tools, for WoW Forever. It ships one module, the
Instance Tracker. It is a beta: please report anything odd in the comments.

### Instance Tracker widget

- A run timer against your personal record for that dungeon and difficulty, with a split and a
  delta for every boss.
- Bosses and rares left, deaths, a time bar with your record's splits, XP gained this run, and
  the gold and reputation earned.
- Compact mode: one line, with the boss list on mouseover.
- Mouseover detail: XP and gold per hour, runs to level up, reputation by faction, your records
  and the instances you entered in the last hour.
- Click a live boss in the list to ping it; right-click to put a raid marker on it.

### Runs

- Leaving the dungeon pauses the clock and it picks up when you come back. Entering another copy
  of the dungeon, or resetting it, starts a new run.
- End-of-run card with time, record, deaths, XP, gold and reputation, and a button to share it
  with your group.
- A warning when you reach the 10 instances per hour limit, with the time until the next slot.

### Main window (/qdt)

- Home, the Instance Tracker settings and the run History (last 100 runs, filtered by dungeon,
  difficulty and character) in one window.
- A live preview of the widget in its settings: every option shows on it at once.
- A minimap icon: click opens the window, shift+click the History, right-click a menu.
- English and Spanish.
