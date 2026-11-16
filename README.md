# Quantum Dungeon Tools

[![CI](https://github.com/bettogamer/QuantumDungeonTools/actions/workflows/ci.yml/badge.svg)](https://github.com/bettogamer/QuantumDungeonTools/actions/workflows/ci.yml)
[![CurseForge](https://img.shields.io/badge/CurseForge-qdt-F16436?logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/qdt)
![Client](https://img.shields.io/badge/WoW%20Forever-1.60%20(Interface%2016001)-1f6feb)
![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)
![Status](https://img.shields.io/badge/status-beta-orange)

**A dungeon toolkit addon for World of Warcraft (WoW Forever client), built for the Quantum guild.**
It tells you where your dungeon run stands: time against your record, bosses left, and what the run
gave you. It also adds a minimap that works inside instances, where the client gives addons no
player position.

> Published on CurseForge as a beta: **[curseforge.com/wow/addons/qdt](https://www.curseforge.com/wow/addons/qdt)**

---

## Modules

### Instance Tracker

A widget at the side of the screen while you run a dungeon:

- **Run timer against your personal record**, per dungeon and difficulty, with a split and a +/- delta
  for every boss, and a time bar marked with the splits of your record.
- **Bosses and rares left**, with the time each one died (rares never block the end of the run).
- **Deaths, XP, gold and reputation** of the run; on mouseover, XP and gold per hour, runs left to
  level up, reputation by faction and your records (also with your current group).
- **Run lifecycle that follows real play:** the clock pauses when you leave and resumes when you come
  back, and a new copy or a reset starts a new run on its own.
- **10 instances per hour limit**: a warning with the time until the next slot.
- **End-of-run card** to share with the group, and a **history of the last 100 runs** filtered by
  dungeon, difficulty and character.

### Minimap Lens

Inside dungeons the client returns no player position (`UnitPosition`, `GetBestMapForUnit` and
`GetPlayerFacing` give `nil`), so a custom map arrow is impossible. The Lens takes the other route:
it **enlarges the real minimap** on demand, with a hotkey, a magnifier button or `/qdt lens`. It puts
everything back exactly as it was, also in combat. It also **coexists with other UI addons**
(ElvUI, EllesmereUI…): if they move the minimap while the lens is on, it repairs only what changed,
and gives way if they keep insisting.

### Main window

`/qdt` or the minimap icon: settings with a **live preview** of the widget, run history and
what's-new notes. Available in English and Spanish.

---

## Engineering highlights

- **Ready for "secret values".** WoW Forever runs on the retail 12.1.5 engine, where many APIs
  return *secret* values that tainted addon code cannot compare or do arithmetic on. Every API
  that can return one is guarded with `issecretvalue` before any truth test, plus a `pcall`. One
  measured case: creature GUIDs inside dungeons are secret, so the copy of the instance is
  identified from the player's own spell `castGUID` instead.
- **Pure core, thin client layer.** Every module is split into `core/` (pure Lua, no WoW APIs,
  fully unit-testable) and `wow/` (events, frames). `.luacheckrc` enforces that `core/` uses no
  WoW globals.
- **CI on the real target runtime.** GitHub Actions runs `luacheck`, `luac -p` and a headless test
  suite on **Lua 5.1**, the version of the WoW sandbox. A custom check guards Lua 5.1's limit of 60
  upvalues per function, a limit the local 5.4 toolchain doesn't catch. The CI also runs
  [taintlint](https://github.com/bettogamer/taintlint), my static analyzer for secret-value
  errors.
- **In-game self-checks.** `/qdt check f1|f2|m2` measures client behaviour live and saves it to
  SavedVariables; scripts in `scripts/` read the results back. That is how facts like "no player
  position inside dungeons" were established, not assumed.
- **Own UI stack.** The UI is built on [Craft](https://github.com/bettogamer/craft), my
  shadcn-style component library for WoW addons, and [Weave](https://github.com/bettogamer/weave)
  for animation and reactivity. Both are vendored read-only at pinned versions (see
  [libs/README.md](QuantumDungeonTools/libs/README.md)).
- **Versioned SavedVariables** with migrations, Keep a Changelog + SemVer releases, and a build
  script for the release zip.

## AI-assisted development

This project was built together with **Claude Code** as a pair. The way of working is part of the repo:

- [`AGENTS.md`](AGENTS.md) is the single source of truth for the agent: architecture, stack and
  invariant rules (MUST / MUST NOT).
- [`.claude/agents/`](.claude/agents/) holds specialised sub-agents: a code scout, a Lua error
  triager, a verifier that runs the lint and test chain, a UI critic that reviews in-game
  screenshots against the design, and doc writers.
- [`docs/`](docs/) has the plans for each milestone, the design reviews and
  [`LECCIONES.md`](docs/LECCIONES.md), a log of the bugs already paid for so they are not repeated.
  The design was drawn on a canvas and approved before any code was written.

*(Internal docs are in Spanish; the addon and this README are in English.)*

---

## Repository layout

```
QuantumDungeonTools/          the addon (what gets installed)
├── core/                     shared pure logic: formatting, tokens, news
├── wow/                      bootstrap, theme, main window, minimap icon
├── modules/
│   ├── InstanceTracker/{core,wow}/
│   └── MinimapLens/{core,wow}/
└── libs/                     vendored, read-only (LibStub, LDB, LibDBIcon, Weave, Craft)
tests/                        headless specs (lua tests/run.lua)
scripts/                      deploy, release build, in-game check readers, data generators
docs/                         milestone plans, design reviews, lessons, CurseForge copy
```

## Development

```bash
lua tests/run.lua                                   # test suite (finds tests/**/*_spec.lua)
luacheck QuantumDungeonTools/<files> --config .luacheckrc
npx taintlint QuantumDungeonTools/ --min-severity warning
powershell -File scripts/deploy-local.ps1           # copy into the local Interface\AddOns
powershell -File scripts/build-dist.ps1             # release zip
```

## License

© 2026 Alberto Gomez. **All rights reserved.** The source is public so you can read and review it,
but it is not open source. See [LICENSE](LICENSE). You are free to download and use the addon to
play.
