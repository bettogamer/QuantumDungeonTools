# CurseForge — Changelog (per-file)

> Se pega en la caja **Changelog** al subir el archivo. **En inglés.** Se REESCRIBE en cada
> subida: solo el texto de ESTA subida, desde la última versión PUBLICADA (plantilla y reglas:
> AddonTemplate `templates/curseforge/changelog_TEMPLATE.md`). No es `CHANGELOG.md`.

---

## v0.1.0-beta.3 — Minimap Lens polish

- The magnifier button: pick its corner in the Minimap Lens settings (bottom left by default, clear
  of EllesmereUI's + / −). With "Magnifier only on hover" (on by default) it shows only when the
  mouse is over the minimap, lens open or not. It now shows outside instances too.
- Underground: at less than 100% opacity the lens now paints caves and the Undercity, when it
  opens, through doors, down levels and after every zoom change.
- After a `/reload` the lens grows and paints in full the first time.
- "Extra zoom" is gone: the lens keeps your zoom (a saved setting is ignored).
