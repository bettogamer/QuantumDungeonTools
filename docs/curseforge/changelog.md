# CurseForge — Changelog (per-file)

> Se pega en la caja **Changelog** al subir el archivo. **En inglés.** Se REESCRIBE en cada
> subida: solo el texto de ESTA subida, desde la última versión PUBLICADA (plantilla y reglas:
> AddonTemplate `templates/curseforge/changelog_TEMPLATE.md`). No es `CHANGELOG.md`.

---

## v0.1.0-beta.4 — Instance Tracker fixes

- Run timer: it now starts with the first fight inside the dungeon (or the first death), not at
  the door, so waiting for the group no longer counts. Records saved before this were timed from
  the entrance, so new runs may beat them without being faster.
- Excavation Site: Wetlands no longer keeps restarting the run and flooding the instances-per-hour
  count (481/10) with constant warnings.
- A `/reload` inside the dungeon keeps the same run and no longer counts another entry.
- Moving between subzones inside the dungeon can no longer restart the run.
- Boss ping now works with a Spanish game client (`/aviso`, "Atacar").
